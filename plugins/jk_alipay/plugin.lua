-- 载入插件

local currentPath = debug.getinfo(1, "S").source:sub(2)
local projectDir = currentPath:match("(.*/)")
package.path = package.path .. ";." .. projectDir .. "../common/?.lua"

local funcs = require("funcs")
local http = require("http")
local json = require("json")
local helper = require("helper")
local orderPayHelper = require("orderPayHelper")

-- 定义常量
PAY_ALIPAY_APP = "alipay_app"
PAY_ALIPAY_Dianyuan = "alipay_dianyuan"

--- 插件信息
plugin = {
    info = {
        name = 'jk_alipay',
        title = '监控插件 - 支付宝',
        author = '包子',
        description = "监控插件",
        link = 'https://auth.xarr.cn',
        version = "1.0",
        -- 支持支付类型
        channels = {
            alipay = {
                {
                    label = '支付宝个人码-监控端',
                    value = PAY_ALIPAY_APP,
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
    if payChannel == PAY_ALIPAY_APP then
        return json.encode({
            inputs = {
                {
                    name = 'qrcode',
                    label = '收款码地址',
                    type = 'input',
                    default = "",
                    options = {
                        tip = '',
                    },
                    placeholder = "请输入收款码地址",
                    when = "this.formModel.options.type == 'qrcode'",
                    options = {
                        append_deqrocde = 1, -- 增加解析二维码功能
                    },
                    rules = {
                        {
                            required = true,
                            trigger = { "input", "blur" },
                            message = "请输入",
                        }
                    }
                },
                {
                    name = 'qrcode_file',
                    label = '收款码图片',
                    type = 'image',
                    default = "",
                    options = {
                        tip = '',
                    },
                    placeholder = "请上传收款码图片",
                    when = "this.formModel.options.type == 'image'",
                    rules = {
                        {
                            required = true,
                            trigger = { "input", "blur" },
                            message = "请输入",
                        }
                    }
                },
                {
                    name = 'pid',
                    label = 'PID',
                    type = 'input',
                    default = "",
                    options = {
                        tip = '',
                    },
                    placeholder = "请输入PID",
                    when = "this.formModel.options.type == 'pid'",
                    rules = {
                        {
                            required = true,
                            trigger = { "input", "blur" },
                            message = "请输入",
                        }
                    }
                },
                {
                    name = 'qrcode_mod',
                    label = '二维码模式',
                    type = 'select',
                    default = "9",
                    options = {
                        tip = '',
                    },
                    placeholder = "请选择二维码模式",
                    when = "this.formModel.options.type == 'pid'",
                    values = {
                        {
                            label = "模式9",
                            value = "9"
                        },
                        {
                            label = "模式10",
                            value = "10"
                        },
                        {
                            label = "模式11",
                            value = "11"
                        },
                    },
                    rules = {
                        {
                            required = true,
                            trigger = { "input", "blur" },
                            message = "请输入",
                        }
                    }
                },
                {
                    name = 'type',
                    label = '收款码类型',
                    type = 'select',
                    default = "url",
                    options = {
                        tip = '',
                    },
                    placeholder = "请选择收款码类型",
                    values = {
                        {
                            label = "二维码",
                            value = "qrcode"
                        },
                        {
                            label = "图片",
                            value = "image"
                        },
                        {
                            label = "PID",
                            value = "pid"
                        },
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

    local orderInfoDe = json.decode(orderInfo)
    local options = json.decode(pluginOptions)

    if options['type'] == 'image' then
        return json.encode({
            type = "qrcode",
            qrcode_file = options['qrcode_file'],
            url = "",
            content = "",
            out_trade_no = '',
            err_code = 200,
            err_message = ""
        })

    elseif options['type'] == 'pid' then
        if options['qrcode_mod'] == '9' then
            return json.encode({
                type = "qrcode",
                qrcode = "https://ds.alipay.com/?from=pc&appId=20000116&actionType=toAccount&goBack=NO&amount=" .. orderInfoDe.trade_amount_str .. "&userId=" .. options['pid'] .. "&memo=" .. orderInfoDe.order_id,
                url = "",
                content = "",
                out_trade_no = '',
                err_code = 200,
                err_message = ""
            })
        elseif options['qrcode_mod'] == '10' then
            return json.encode({
                type = "qrcode",
                qrcode_use_short_url = 1,
                qrcode = "alipayqr://platformapi/startapp?saId=20000032&url=alipays%3A%2F%2Fplatformapi%2Fstartapp%3FappId%3D20000123%26actionType%3Dscan%26biz_data%3D%257B%2522s%2522%253A%2522money%2522%252C%2522u%2522%253A%2522" .. options['pid'] .. "%2522%252C%2522a%2522%253A%2522" .. orderInfoDe.trade_amount_str .. "%2522%252C%2522m%2522%253A%2522" .. orderInfoDe.order_id .. "%2522%257D",
                url = "",
                content = "",
                scheme = "alipayqr://platformapi/startapp?saId=20000032&url=alipays%3A%2F%2Fplatformapi%2Fstartapp%3FappId%3D20000123%26actionType%3Dscan%26biz_data%3D%257B%2522s%2522%253A%2522money%2522%252C%2522u%2522%253A%2522" .. options['pid'] .. "%2522%252C%2522a%2522%253A%2522" .. orderInfoDe.trade_amount_str .. "%2522%252C%2522m%2522%253A%2522" .. orderInfoDe.order_id .. "%2522%257D",
                out_trade_no = '',
                err_code = 200,
                err_message = ""
            })
        elseif options['qrcode_mod'] == '11' then
            return json.encode({
                type = "html",
                qrcode_use_short_url = 1,
                url = "",
                content = plugin.buildMod11Html(options['pid'], orderInfoDe.trade_amount_str, orderInfoDe.order_id),
                scheme = "alipays://platformapi/startapp?appId=20000067&url="..helper.url_encode("https://render.alipay.com/p/s/i?scheme="..helper.url_encode("alipays://platformapi/startapp?appId=20000180&url="..helper.url_encode(orderPayHelper.get_toapp_url(orderInfoDe.order_id,orderInfoDe.host)))),
                out_trade_no = '',
                err_code = 200,
                err_message = ""
            })
        end

    end

    return json.encode({
        type = "qrcode",
        qrcode = options['qrcode'],
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
        ["com.eg.android.AlipayGphone"] = {
            {
                TitleReg = "微信支付",
                ContentReg = "通过扫码向你付款(?<amount>[\\d\\.]+)元",
                Code = PAY_ALIPAY_APP
            },
            {
                TitleReg = "收钱码",
                ContentReg = "通过扫码向你付款(?<amount>[\\d\\.]+)元",
                Code = PAY_ALIPAY_APP
            },

            {
                TitleReg = "已转入余额( 立即查看余额)?",
                ContentReg = "你已成功收款(?<amount>[\\d\\.]+)元",
                Code = PAY_ALIPAY_APP
            },

            {
                TitleReg = "店员通",
                ContentReg = "你已成功收款(?<amount>[\\d\\.]+)元",
                Code = PAY_ALIPAY_Dianyuan
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


function plugin.buildMod11Html (pid ,money,order_id)
    return [[<!DOCTYPE html>
<html lang="zh">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="ie=edge">
    <title>收银台</title>
    <script src="//gw.alipayobjects.com/as/g/h5-lib/alipayjsapi/3.1.1/alipayjsapi.min.js"></script>
</head>
<body>
<script>
    var userId = "]].. pid ..[[";
    var money = "]].. money ..[[";
    var remark = "]].. order_id ..[[";

    function returnApp() {
        AlipayJSBridge.call("exitApp")
    }

    function ready(a) {
        window.AlipayJSBridge ? a && a() : document.addEventListener("AlipayJSBridgeReady", a, !1)
    }

    ready(function () {
        try {
            var a = {
                actionType: "scan",
                u: userId,
                a: money,
                m: remark,
                biz_data: {
                    s: "money",
                    u: userId,
                    a: money,
                    m: remark
                }
            }
        } catch (b) {
            returnApp()
        }
        AlipayJSBridge.call("startApp", {
            appId: "20000123",
            param: a
        }, function (a) { })
    });
    document.addEventListener("resume", function (a) {
        returnApp()
    });
</script>
</body>
</html>]]
end
