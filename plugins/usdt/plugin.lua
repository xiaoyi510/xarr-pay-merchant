-- 载入插件

local currentPath = debug.getinfo(1, "S").source:sub(2)
local projectDir = currentPath:match("(.*/)")
package.path = package.path .. ";." .. projectDir .. "../common/?.lua"

local funcs = require("funcs")
local http = require("http")
local json = require("json")
local helper = require("helper")
local orderHelper = require("orderHelper")
local orderPayHelper = require("orderPayHelper")

PAY_USDT = "usdt"

--- 插件信息
plugin = {
    info = {
        name = 'usdt',
        title = 'Usdt',
        author = '包子',
        description = "Usdt (Trc20网络)",
        link = 'https://github.com/xiaoyi510/xarr-pay-mechant',
        version = "1.0.0",
        -- 最小支持主程序版本号
        min_main_version = "1.3.3",
        -- 支持支付类型
        channels = {
            usdt = {
                {
                    label = 'Usdt-Trc20',
                    value = 'usdt',
                    options = {
                        -- 使用递增金额
                        use_add_amount = 1,
                    }
                },
            },
        },
        options = {
            -- 启动账单定时查询
            detection_interval = 3,
            detection_type = "cron", --- order 单订单检查 cron 定时执行任务

            -- 定时任务
            crontab_list = {
                { crontab = "*/50 * * * * *", fun = "usdt_cny_rate", name = "同步USDT Cny 汇率" },
                { crontab = "*/50 * * * * *", fun = "usdt_trx_rate", name = "同步USDT Trx 汇率" },
            },
            -- 配置项
            options = {
                {
                    title = "OKX 地址", key = "okx_host", default = "https://www.okx.com"
                },
                {
                    title = "TronScan Api地址", key = "tronscan_api", default = "https://apilist.tronscan.org"
                },
                {
                    title = "CNY 汇率", key = "cny_rate", default = "6.97"
                },
                {
                    title = "TRX 汇率", key = "trx_rate", default = "0.15521"
                },
            }
        },

    }
}

function plugin.pluginInfo()
    return json.encode(plugin.info)
end


-- 获取form表单
function plugin.formItems(payType, payChannel)
    return json.encode({
        inputs = {
            {
                name = 'address',
                label = '收款地址',
                type = 'input',
                default = "",
                placeholder = "请输入收款地址 ",
                options = {
                    tip = '如: Txxx',
                },
                rules = {
                    {
                        required = true,
                        trigger = { "input", "blur" },
                        message = "请输入"
                    }
                }
            },
            {
                name = 'up_rate',
                label = '上浮费率',
                type = 'input',
                default = "",
                placeholder = "为空不上浮",
                options = {
                    tip = '如: 0.15',
                },
                rules = {

                }
            }
        },
    })
end

function plugin.create(pOrderInfo, pluginOptions, ...)
    local args = { ... }
    local orderInfo = json.decode(pOrderInfo)
    local options = json.decode(pluginOptions)

    local address = options['address']
    local up_rate = options['up_rate']

    local calcRate = tonumber(helper.get_plugin_option(plugin.info.name, "cny_rate"))
    if calcRate <= 0 then
        return json.encode({
            err_code = 500,
            err_message = "获取汇率失败"
        })
    end

    -- 判断是否使用上浮
    if up_rate ~= "" then
        calcRate = calcRate + tonumber(up_rate)
    end


    -- 计算交易金额
    local amount = string.format("%0.2f", (orderInfo.trade_amount / calcRate) / 100)

    -- 重置临时金额
    local res, newAmount = orderHelper.reset_order_tmp_amount(orderInfo.order_id, amount * 100)
    if res ==false then
        return json.encode({
            err_code = 500,
            err_message = "重置临时金额失败"
        })
    end
    return json.encode({
        type = "qrcode",
        qrcode = address,
        actual_amount =  string.format("%0.2f",newAmount / 100), -- 外部实际需要支付金额
        actual_account_type = "USDT-TRC20", -- 外部支付收款账号类型
        actual_account = address, -- 外部支付账号显示到页面
        err_code = 200,
        err_message = ""
    })
end

-- 同步汇率 USDT 出售的汇率
function plugin.usdt_cny_rate()
    print("[插件] 开始同步 Cny 汇率")
    local apiHost = helper.get_plugin_option(plugin.info.name, "okx_host", "https://www.okx.com")
    local t = helper.time_now_timestamp()
    local apiUri = string.format("%s/v4/c2c/express/price?crypto=USDT&fiat=CNY&side=sell&t=", apiHost) .. t
    local params = {
        timeout = "60s",
        headers = {
            ["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36",
        }
    }

    local response, error_message = http.request("GET", apiUri, params)
    if error_message ~= nil then
        return json.encode({
            err_code = 500,
            err_message = string.format('请求响应错误 返回消息:%v 错误信息: %v', response, error_message)
        })
    end
    local returnInfo = json.decode(response.body)
    if returnInfo.code == nil then
        return json.encode({
            err_code = 500,
            err_message = string.format('请求响应错误 返回消息:%v  ', response.body)
        })
    end

    if tonumber(returnInfo["code"]) == 0 then
        if helper.set_plugin_option(plugin.info.name, "cny_rate", returnInfo["data"]["price"]) then
            return json.encode({
                data = returnInfo["data"]["price"],
                err_code = 200,
                err_message = "同步USDT Cny 汇率成功"
            })
        end
        return json.encode({
            err_code = 500,
            err_message = "设置配置失败"
        })
    end
    return json.encode({
        err_code = 500,
        err_message = "获取数据失败"
    })
end

function plugin.usdt_trx_rate()
    print("[插件] 开始同步 Trx 汇率")
    local t = helper.time_now_timestamp()
    local apiHost = helper.get_plugin_option(plugin.info.name, "okx_host", "https://www.okx.com")
    local apiUri = string.format("%s/priapi/v5/market/candles?instId=TRX-USDT&before=1727143156000&bar=4H&limit=1&t=", apiHost) .. t
    local params = {
        timeout = "60s",
        headers = {
            ["referer"] = "https://www.okx.com/zh-hans/trade-spot/trx-usdt",
            ["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36",
        }
    }

    local response, error_message = http.request("GET", apiUri, params)
    if error_message ~= nil then
        return json.encode({
            err_code = 500,
            err_message = string.format('请求响应错误 返回消息:%v 错误信息: %v', response, error_message)

        })
    end

    local returnInfo = json.decode(response.body)

    if returnInfo.code == nil then
        return json.encode({
            err_code = 500,
            err_message = string.format('请求响应错误 返回消息:%v  ', response.body)
        })
    end

    if tonumber(returnInfo.code) == 0 and returnInfo["data"] and funcs.count(returnInfo["data"]) > 0 and returnInfo["data"][1] and funcs.count(returnInfo["data"][1]) > 1 then
        if helper.set_plugin_option(plugin.info.name, "trx_rate", returnInfo["data"][1][2]) then
            return json.encode({
                data = returnInfo["data"][1][2],
                err_code = 200,
                err_message = "同步USDT TRX 汇率成功"
            })
        end
        return json.encode({
            err_code = 500,
            err_message = "设置配置失败"
        })
    end

    return json.encode({
        err_code = 500,
        err_message = "获取数据失败:" .. response.body
    })
end


-- 定时任务
function plugin.cron(pAccountInfo, pPluginOptions)
    local accountInfo = json.decode(pAccountInfo)
    local options = json.decode(pPluginOptions)
    local apiHost = helper.get_plugin_option(plugin.info.name,"tronscan_api")
    local uri = string.format('%s/api/token_trc20/transfers?limit=300&start=0&direction=in&relatedAddress=%s',apiHost, options.address)
    local params = {
        timeout = "30s",
        headers = {
            ["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36",
        }
    }

    local response, error_message = http.request("GET", uri, params)
    if error_message ~= nil then
        return json.encode({
            err_code = 500,
            err_message = string.format('请求响应错误 返回消息:%v 错误信息: %v', response, error_message)

        })
    end
    local returnInfo = json.decode(response.body)

    if returnInfo.token_transfers == nil then
        return json.encode({
            err_code = 500,
            err_message = string.format('未能获取到订单数据 返回数据:%v', response.body)

        })
    end

    for _, v in ipairs(returnInfo.token_transfers) do
        -- 判断是否是同一个人
        if v.to_address == options.address then
            -- 判断风险
            if v.riskTransaction == false then
                -- 判断订单状态
                if v.finalResult == "SUCCESS" and v.contractRet == "SUCCESS" then
                    -- 单位分
                    local quant = tonumber(v.quant) / 1000000

                    -- 判断第三方订单是否存在
                    local exist = orderPayHelper.third_order_exist({
                        pay_type = PAY_USDT,
                        channel_code = PAY_USDT,
                        uid = accountInfo.uid,
                        account_id = accountInfo.id,
                        third_account = options.address,
                        third_order_id = v.transaction_id
                    })
                    if exist then
                        goto continue
                    end

                    print("识别外部订单号,准备插入", v.transaction_id, quant)

                    -- 录入数据
                    local insertId = orderPayHelper.third_order_insert({
                        pay_type = PAY_USDT,
                        channel_code = PAY_USDT,
                        uid = accountInfo.uid,
                        account_id = accountInfo.id,

                        ["buyer_id"] = v.from_address,
                        ["buyer_name"] = v.from_address,
                        third_order_id = v.transaction_id,
                        third_account = options.address,
                        ["amount"] = quant,
                        ["remark"] = "",
                        ["trans_time"] = math.ceil(v.block_ts / 1000),
                        ["type"] = v.event_type,
                        ["out_order_id"] = "",
                    })


                    -- 录入失败
                    if insertId <= 0 then
                        print("外部订单插入失败", v.transaction_id)
                        goto continue
                    end

                    -- 录入成功
                    local err_code, err_message = orderPayHelper.third_order_report(insertId)
                    if err_code == 200 then
                        print("订单上报成功:" .. err_message, v.transaction_id, quant)
                    else
                        print("订单上报失败:" .. err_message, v.transaction_id, quant)
                    end

                end
            end
        end


        -- 尾部
        :: continue ::
    end

    return json.encode({
        err_code = 200,
        err_message = "ff"
    })
end