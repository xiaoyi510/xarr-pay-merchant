-- 载入插件

local currentPath = debug.getinfo(1, "S").source:sub(2)
local projectDir = currentPath:match("(.*/)")
package.path = package.path .. ";." .. projectDir .. "../common/?.lua"

local funcs = require("funcs")
local http = require("http")
local json = require("json")

-- 定义常量
PAY_QQPAY_APP = "qq_pc_qrcode"

--- 插件信息
plugin = {
    info = {
        name = 'jk_qqpay',
        title = '监控插件 - QQ个人码',
        author = '包子',
        description = "监控插件",
        link = 'https://auth.xarr.cn',
        version = "1.0",
        -- 支持支付类型
        channels = {
            qqpay = {
                {
                    label = 'QQ个人码-监控端',
                    value = PAY_QQPAY_APP,
                    -- 支持上报
                    report = 1,
                    -- 无上报SMS信息
                    parse_msg = 0,
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
                    name = 'type',
                    label = '收款码类型',
                    type = 'select',
                    default = "qrcode",
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
