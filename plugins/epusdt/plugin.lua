-- 载入插件

local currentPath = debug.getinfo(1, "S").source:sub(2)
local projectDir = currentPath:match("(.*/)")
package.path = package.path .. ";." .. projectDir .. "../common/?.lua"

local funcs = require("funcs")
local http = require("http")
local json = require("json")
local helper = require("helper")
local orderHelper = require("orderHelper")

--- 插件信息
plugin = {
    info = {
        name = 'epusdt',
        title = 'Easy Payment Usdt',
        author = '包子',
        description = "Epusdt（全称：Easy Payment Usdt）是一个由Go语言编写的私有化部署Usdt支付中间件(Trc20网络)",
        link = 'https://github.com/assimon/epusdt',
        version = "1.0.1",
        -- 支持支付类型
        channels = {
            usdt = {
                {
                    label = 'Easy Payment Usdt',
                    value = 'epusdt'
                },
            },
        },
        options = {
            callback = 1,
            detection_interval = 0,
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
                name = 'host',
                label = '通讯地址',
                type = 'input',
                default = "",
                placeholder = "请输入通讯地址",
                options = {
                    tip = '如: https://xxx.com/',
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
                name = 'key',
                label = '通讯密钥',
                type = 'password',
                default = "",
                placeholder = "请输入通讯密钥",
                options = {
                    tip = '',
                },
                rules = {
                    {
                        required = true,
                        trigger = { "input", "blur" },
                        message = "请输入"
                    }
                }
            },

        },
    })
end

function plugin.create(pOrderInfo, pluginOptions, ...)
    local args = { ... }

    local orderInfo = json.decode(pOrderInfo)
    local options = json.decode(pluginOptions)

    local uri = options['host'] .. "api/v1/order/create-transaction"
    local key = options['key']

    -- 组装提交请求
    local req = {
        order_id = orderInfo['order_id'],
        amount = tonumber(orderInfo['trade_amount_str']),
        notify_url = orderInfo['notify_url'],
        redirect_url = orderInfo['return_url'],
    }
    req["signature"] = plugin._getSign(req, key)


    -- 处理发送内容
    local params = {
        query = "",
        body = json.encode(req),
        form = "",
        timeout = "30s",
        headers = {
            ["content-type"] = "application/json; charset=UTF-8"
        }
    }

    local response, error_message = http.request("POST", uri, params)
    if response and response.body then
        local res = response.body
        print("[插件] 返回内容" .. res)
        local returnInfo = json.decode(res)

        if returnInfo == nil then
            return json.encode({
                type = 'error',
                err_code = 500,
                err_message = '请求响应错误 返回内容:' .. res
            })
        end

        if returnInfo['status_code'] ~= 200 then
            return json.encode({
                type = 'error',
                err_code = 500,
                err_message = returnInfo['message']
            })
        end

        -- 跳转地址
        return json.encode({
            type = "jump",
            qrcode = '',
            url = returnInfo['data']['payment_url'],
            content = returnInfo['data']['token'],
            out_trade_no = returnInfo['data']['trade_id'],
            err_code = 200,
            err_message = ""
        })


        --return json.encode({
        --    type = "qrcode",
        --    qrcode = returnInfo['data']['token'],
        --    url = returnInfo["data"]["payment_url"],
        --    content = "",
        --    out_trade_no = returnInfo['data']['trade_id'],
        --    actual_amount = returnInfo['data']['actual_amount'], -- 外部实际需要支付金额
        --    err_code = 200,
        --    err_message = ""
        --})

    end

    return json.encode({
        type = "html",
        qrcode = "",
        url = "",
        content = content,
        err_code = 200,
        err_message = ""
    })


end

-- 支付回调
function plugin.notify(pRequest, pOrderInfo, pParams, pPluginOptions)
    local request = json.decode(pRequest)
    local params = json.decode(pParams)
    local orderInfo = json.decode(pOrderInfo)
    local options = json.decode(pPluginOptions)

    -- 判断请求方式
    local reqData = ""
    if request['method'] == 'POST' then
        reqData = (request['body'])
    else
        reqData = (request['query'])
    end


    -- 获取签名内容
    local sign = plugin._getSign(reqData, options['key'])
    if sign == reqData['signature'] then
        if tonumber(reqData['status']) ~= 2 then
            return json.encode({
                error_code = 500,
                error_message = "支付未成功"
            })
        end

        -- 商户订单号
        local out_trade_no = reqData['trade_id']

        -- 避免精度有问题
        local price = math.floor((reqData['amount'] + 0.000005) * 100)

        -- 通知订单处理完成
        local err_code, err_message, response = orderHelper.notify_process(json.encode({
            out_trade_no =  out_trade_no,
            trade_no =reqData['order_id'],
            amount = price,
        }), json.encode(params), json.encode(options))

        return json.encode({
            error_code = err_code,
            error_message = err_message,
            response = response,
        })


    else
        return json.encode({
            error_code = 500,
            error_message = "签名校验失败"
        })

    end
end




-- 签名
function plugin._getSign(param, key)
    local signstr = ''
    local keys = {}

    for k, _ in pairs(param) do
        table.insert(keys, k)
    end
    table.sort(keys)

    for _, k in ipairs(keys) do
        local v = param[k]
        if k ~= "signature" and v ~= '' then
            signstr = signstr .. k .. '=' .. v .. '&'
        end
    end

    signstr = string.sub(signstr, 1, -2)
    signstr = signstr .. key
    local sign = helper.md5(signstr)
    return sign
end
