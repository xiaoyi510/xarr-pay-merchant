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
        name = 'epay',
        title = '易支付',
        author = '包子',
        description = "易支付通用SDK",
        link = 'https://auth.xarr.cn',
        version = "1.0",
        -- 支持支付类型
        channels = {
            alipay = {
                {
                    label = '易支付',
                    value = 'alipay_epay'
                },
            },
            wxpay = {
                {
                    label = '易支付',
                    value = 'wxpay_epay'
                },
            },
            qqpay = {
                {
                    label = '易支付',
                    value = 'qqpay_epay'
                },

            },
            bank = {
                {
                    label = '易支付',
                    value = 'bank_epay'
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
                    tip = '如: https://xxx.com/xpay/epay',
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
                name = 'pid',
                label = '商户ID',
                type = 'input',
                default = "",
                placeholder = "请输入商户ID",
                options = {
                    tip = '如: 10000',
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
            {
                name = 'method',
                label = '请求方式',
                type = 'select',
                default = "POST",
                options = {
                    tip = '',
                },
                placeholder = "请选择请求方式",
                values = {
                    {
                        label = "GET",
                        value = "GET"
                    },
                    {
                        label = "POST",
                        value = "POST"
                    },
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
                name = 'type',
                label = '接口类型',
                type = 'select',
                default = "mapi",
                options = {
                    tip = '',
                },
                placeholder = "请选择接口类型",
                values = {
                    {
                        label = "mapi.php",
                        value = "mapi"
                    },
                    {
                        label = "submit.php",
                        value = "submit"
                    },
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

function plugin.create(orderInfo, pluginOptions, ...)
    local args = { ... }

    orderInfo = json.decode(orderInfo)
    local options = json.decode(pluginOptions)

    local host = options['host']
    local pid = options['pid']
    local key = options['key']
    -- 提交方式
    local method = options['method']
    -- 提交类型
    local submitType = options['type']

    -- 组装提交请求
    local req = {
        pid = pid,
        type = orderInfo['pay_type'],
        notify_url = orderInfo['notify_url'],
        return_url = orderInfo['return_url'],
        out_trade_no = orderInfo['order_id'],
        name = orderInfo['subject'],
        money = orderInfo['trade_amount'] / 100,
        clientip = orderInfo['client_ip'],
        device = orderInfo['device'],

    }
    local sendData = {}
    local res = ""
    local err = nil
    local error_message = nil
    local response = {}

    req = plugin._buildRequestParams(req, key)


    -- 判断提交方式
    if submitType == 'mapi'
    then
        -- mapi
        local uri = host .. "/mapi.php"

        print("[插件] 请求内容" .. funcs.table_http_query(req))

        if method == "POST" then
            params = {
                query = "",
                body = funcs.table_http_query(req),
                form = "",
                timeout = "30s",
                headers = {
                    ["content-type"] = "application/x-www-form-urlencoded"
                }
            }

            response, error_message = http.request("POST", uri, params)
            if response and response.body then
                res = response.body
            end
        else
            response, error_message = http.request(method, uri, {
                query = funcs.table_http_query(req),
                timeout = "30s",
                headers = {
                }
            })
            if response and response.body then
                res = response.body
            end
        end

        print("[插件] 返回内容" .. res)
        local returnInfo = json.decode(res)

        if returnInfo == nil then
            return json.encode({
                type = 'error',
                err_code = 500,
                err_message = '请求响应错误 返回内容:' .. res
            })
        end

        if returnInfo['code'] ~= 1 then
            return json.encode({
                type = 'error',
                err_code = 500,
                err_message = returnInfo['msg'] or returnInfo['message']
            })
        end

        if returnInfo['payurl'] then
            return json.encode({
                type = "jump",
                qrcode = '',
                url = returnInfo["payurl"],
                content = "",
                out_trade_no = returnInfo['trade_no'],
                err_code = 200,
                err_message = ""
            })
        end

        return json.encode({
            type = "qrcode",
            qrcode = returnInfo['qrcode'],
            url = returnInfo["payurl"],
            content = "",
            out_trade_no = returnInfo['trade_no'],
            err_code = 200,
            err_message = ""
        })
    else
        -- submit 此方式为提交到外部也就按
        local uri = host .. "/submit.php"
        -- 处理发送内容
        if method == "POST" then
            req = plugin._pagePay(req, uri, "正在跳转中,未跳转点击我")

            return json.encode({
                type = "html",
                qrcode = "",
                url = "",
                content = req,
                err_code = 200,
                err_message = ""
            })
        end

        return json.encode({
            type = "jump",
            qrcode = "",
            url = uri .. "?" .. funcs.table_http_query(req),
            content = "",
            err_code = 200,
            err_message = ""
        })
    end

    return ""

end

-- 支付回调
function plugin.notify(request, orderInfo, params, pluginOptions)
    request = json.decode(request)
    params = json.decode(params)
    orderInfo = json.decode(orderInfo)
    local options = json.decode(pluginOptions)

    -- 判断请求方式
    local reqData = ""
    if request['method'] == 'POST' then
        reqData = (request['body'])
    else
        reqData = (request['query'])
    end

    -- 获取签名内容
    local sign = plugin._getSign(reqData, options['key'])
    if sign == reqData['sign'] then
        -- 签名校验成功
        if reqData['pid'] ~= options['pid'] then
            return json.encode({
                error_code = 500,
                error_message = "交易商户号异常"
            })
        end

        if reqData['trade_status'] ~= "TRADE_SUCCESS" then
            return json.encode({
                error_code = 500,
                error_message = "交易未完成"
            })
        end

        -- 商户订单号
        local out_trade_no = reqData['out_trade_no']
        -- 外部系统订单号
        local trade_no = reqData['trade_no']
        -- 避免精度有问题
        local money = math.floor((reqData['money'] + 0.000005) * 100)

        -- 通知订单处理完成
        local err_code, err_message, response = orderHelper.notify_process(json.encode({
            out_trade_no = trade_no,
            trade_no = out_trade_no,
            amount = money,
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

-- 绑定参数
function plugin._buildRequestParams(params, key)
    params['sign'] = plugin._getSign(params, key)
    params['sign_type'] = 'MD5'
    return params
end


-- 发起支付（页面跳转）
function plugin._pagePay(param, submit_url, button)
    local html = '<form id="dopay" action="' .. submit_url .. '" method="post">'

    for k, v in pairs(param) do
        html = html .. '<input type="hidden" name="' .. k .. '" value="' .. v .. '"/>'
    end

    html = html .. '<input type="submit" value="' .. button .. '"></form><script>document.getElementById("dopay").submit();</script>'

    return html
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
        if k ~= "sign" and k ~= "sign_type" and v ~= '' then
            signstr = signstr .. k .. '=' .. v .. '&'
        end
    end

    signstr = string.sub(signstr, 1, -2)
    signstr = signstr .. key
    local sign = helper.md5(signstr)
    return sign
end
