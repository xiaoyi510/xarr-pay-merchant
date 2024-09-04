-- 载入插件

local currentPath = debug.getinfo(1, "S").source:sub(2)
local projectDir = currentPath:match("(.*/)")
package.path = package.path .. ";." .. projectDir .. "../common/?.lua"

local funcs = require("funcs")
local http = require("http")
local json = require("json")
local helper = require("helper")

-- 定义常量
PAY_JK_JDSYT = "jk_jdyst"

--- 插件信息
plugin = {
    info = {
        name = 'jk_jdsyt',
        title = '监控插件 - 京东收银台',
        author = '包子',
        description = "监控插件",
        link = 'https://auth.xarr.cn',
        version = "1.0",
        -- 支持支付类型
        channels = {
            ebank = {
                {
                    label = '京东收银台-监控端',
                    value = PAY_JK_JDSYT,
                    -- 绑定支付方式
                    bind_pay_type = { "alipay", "wxpay", "ebank" },

                    -- 支持上报
                    report = 1,
                    parse_msg = 1,

                    options = {
                        use_add_amount = 1,
                    }
                },
            },
        },
        options = {
            _ = ""
        },

    }
}

function plugin.pluginInfo()
    return json.encode(plugin.info)
end

-- 获取form表单
function plugin.formItems(payType, payChannel)
    if payChannel == PAY_JK_JDSYT then
        return json.encode({
            inputs = {
                {
                    name = 'number',
                    label = '设备ID',
                    type = 'input',
                    default = "",
                    placeholder = "请填写京东收银台设备ID",
                    options = {
                        append_deqrocde = 1, -- 增加解析二维码功能
                        tip = '',
                    },
                    rules = {
                        {
                            required = true,
                            trigger = { "input", "blur" },
                            message = "请输入",
                        }
                    }
                },
            },
        })
    end

    return "{}"

end

function plugin.create(orderInfo, pluginOptions, ...)
    local args = { ... }
    orderInfo = json.decode(orderInfo)
    local options = json.decode(pluginOptions)

    return json.encode({
        type = "qrcode",
        qrcode = string.format("https://order.duolabao.com/active/c?state=%s%%7C%s%%7C%.2f%%7C%%7CAPI", orderInfo["order_id"], options['number'], orderInfo['trade_amount'] / 100),
        url = "",
        content = "",
        out_trade_no = '',
        err_code = 200,
        err_message = ""
    })

end

-- 支付回调
function plugin.notify(request, orderInfo, params, pluginOptions)
    -- 判断请求方式
    return json.encode({
        error_code = 500,
        error_message = "暂不支持",
        response = "",
    })

end


-- 解析上报数据
function plugin.parseMsg(msg)
    msg = json.decode(msg)
    local reportApps = {
        ["com.duolabao.customer"] = {
            {
                TitleReg = "京东收银商户",
                ContentReg = "，收款(?<amount>[\\d\\.]+)元，订单尾号",
                Code = PAY_JK_JDSYT
            },
        }
    }

    -- 获取包名
    local packageName = msg.package_name

    if reportApps[packageName] then
        -- 循环规则
        for i, v in ipairs(reportApps[packageName]) do
            -- 判断渠道是否一样的
            if v.Code == msg['channel_code'] then
                -- 匹配标题
                local titleMatched =  helper.regexp_match(msg.title, v.TitleReg)
                if titleMatched then
                    -- 调用正则
                    local matched, matchGroups =  helper.regexp_match_group(msg.content, v.ContentReg)

                    -- 判断匹配是否成功
                    if matched == true then

                        -- 解析正则中的价格
                        matchGroups = json.decode(matchGroups)

                        -- 判断是否解析成功
                        if matchGroups['amount'] and #matchGroups['amount'] > 0 then
                            -- 匹配到金额
                            return json.encode({
                                err_code = 200,
                                amount = matchGroups['amount'][1],
                            })
                        end
                    end

                end
            end


        end


    end
    -- 匹配到金额
    return json.encode({
        err_code = 500,
        err_message = "未能匹配"
    })

end