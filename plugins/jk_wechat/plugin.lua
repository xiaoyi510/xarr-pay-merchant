-- 载入插件

local currentPath = debug.getinfo(1, "S").source:sub(2)
local projectDir = currentPath:match("(.*/)")
package.path = package.path .. ";." .. projectDir .. "../common/?.lua"

local funcs = require("funcs")
local http = require("http")
local json = require("json")

-- 定义常量
PAY_WXPAY_APP = "wxpay_app"
PAY_WXPAY_COMMERCE = "wxpay_commerce"
PAY_WXPAY_SDK = "wxpay_skd"
PAY_WXPAY_CLOUDZSM = "wxpay_cloudzs"
PAY_WXPAY_DIANYUAN = "wxpay_dianyuan"

--- 插件信息
plugin = {
    info = {
        name = 'jk_wechat',
        title = '监控插件 - 微信',
        author = '包子',
        description = "监控插件",
        link = 'https://auth.xarr.cn',
        version = "1.0",
        -- 支持支付类型
        channels = {
            wxpay = {
                {
                    label = '微信个人码-监控端',
                    value = PAY_WXPAY_APP,
                    -- 支持上报
                    report = 1,
                    parse_msg = 1,
                    options = {
                        use_add_amount = 1,
                    }
                },
                {
                    label = '赞赏码-监控端',
                    value = PAY_WXPAY_CLOUDZSM,
                    -- 支持上报
                    report = 1,
                    parse_msg = 1,
                    options = {
                        use_add_amount = 1,
                    }
                },
                {
                    label = '微信店员-监控端',
                    value = PAY_WXPAY_DIANYUAN,
                    -- 支持上报
                    report = 1,
                    parse_msg = 1,
                    options = {
                        use_add_amount = 1,
                    }
                },
                {
                    label = '微信经营码-监控端',
                    value = PAY_WXPAY_COMMERCE,
                    -- 支持上报
                    report = 1,
                    parse_msg = 1,
                    options = {
                        use_add_amount = 1,
                    }
                },
                {
                    label = '微信收款单-监控端',
                    value = PAY_WXPAY_SDK,
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
    if payChannel == PAY_WXPAY_APP or payChannel == PAY_WXPAY_DIANYUAN or payChannel == PAY_WXPAY_SDK or payChannel == PAY_WXPAY_COMMERCE then
        return json.encode({
            inputs = {
                {
                    name = 'qrcode',
                    label = '收款码地址',
                    type = 'input',
                    default = "",
                    placeholder = "请输入收款码地址",
                    when = "this.formModel.options.type == 'url'",
                    options = {
                        append_deqrocde = 1, -- 增加解析二维码功能
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
                            message = "请输入"
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
                            label = "地址",
                            value = "url"
                        },
                        {
                            label = "图片",
                            value = "image"
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
    elseif payChannel == PAY_WXPAY_CLOUDZSM then
        return json.encode({
            inputs = {
                {
                    name = 'qrcode',
                    label = '收款码地址',
                    type = 'input',
                    default = "",

                    placeholder = "请输入收款码地址",
                    options = {
                        append_uploads = 1, -- 增加上传图片功能
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
                {
                    name = 'type',
                    hidden = 1,
                    default = 'image',
                }
            },
        })


    end
    return "{}"
end

function plugin.create(orderInfo, pluginOptions, ...)
    local args = { ... }

    orderInfo = json.decode(orderInfo)
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
        ["com.tencent.mm"] = {
            {
                TitleReg = "微信收款助手",
                ContentReg = "^(?:\\[\\d+条\\]微信收款助手: )?微信支付收款(?<amount>[\\d\\.]+)元(\\(([新老]顾客)?(朋友)?到店\\))?",
                Code = PAY_WXPAY_APP
            },
            {
                TitleReg = "微信支付",
                ContentReg = "微信支付：微信支付收款(?<amount>[\\d\\.]+)元",
                Code = PAY_WXPAY_APP
            },
            {
                TitleReg = "微信支付",
                ContentReg = "个人收款码到账¥(?<amount>[\\d\\.]+)",
                Code = PAY_WXPAY_APP
            },


            {
                TitleReg = "微信收款助手",
                ContentReg = "\\[店员消息\\]收款到账(?<amount>[\\d\\.]+)元",
                Code = PAY_WXPAY_DIANYUAN
            },
            {
                TitleReg = "微信支付",
                ContentReg = "二维码赞赏到账(?<amount>[\\d\\.]+)元",
                Code = PAY_WXPAY_CLOUDZSM
            },

            -- 经营码
            {
                TitleReg = "微信收款商业版",
                ContentReg = "收款(?<amount>[\\d\\.]+)元",
                Code = PAY_WXPAY_COMMERCE
            },
            {
                TitleReg = "收款通知",
                ContentReg = "微信收款商业版: 收款(?<amount>[\\d\\.]+)元",
                Code = PAY_WXPAY_COMMERCE
            },


            {
                TitleReg = "微信收款助手",
                ContentReg = "收款单到账(?<amount>[\\d\\.]+)元",
                Code = PAY_WXPAY_SDK
            },


        }
    }

    -- 获取包名
    local packageName = msg.package_name

    if msg['pay_type'] == 'wxpay' then
        if reportApps[packageName] then
            -- 循环规则
            for i, v in ipairs(reportApps[packageName]) do
                -- 判断渠道是否一样的
                if v.Code == msg['channel_code'] then
                    -- 匹配标题
                    local titleMatched = regexp_match(msg.title, v.TitleReg)
                    if titleMatched then
                        -- 调用正则
                        local matched, matchGroups = regexp_match_group(msg.content, v.ContentReg)

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
    end
    -- 匹配到金额
    return json.encode({
        err_code = 500,
        err_message = "未能匹配"
    })

end
