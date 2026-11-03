--[[-- Gui - Calculator
Add a calculator to do quick calculation.
]]

local Gui = require("modules/exp_gui")
local Roles = require("modules/exp_roles")
local format_number = require("util").format_number

--- @class ExpGui_Calculator.elements
local Elements = {}

local calc_function = setmetatable({
    ln = math.log,
    log = function(x, b) return math.log(x, b or 10) end,
    round = function(x) return x >= 0 and math.floor(x + 0.5) or math.ceil(x - 0.5) end,
    trunc = function(x) return (math.modf(x)) end,
    sign = function(x) return x > 0 and 1 or (x < 0 and -1 or 0) end,
    pi = function(_) return math.pi end,
}, {
    __index = math
})

local calc_function_operation = {
    ["+"] = {1, function(a, b) return a + b end},
    ["-"] = {1, function(a, b) return a - b end},
    ["*"] = {2, function(a, b) return a * b end},
    ["/"] = {2, function(a, b) if b == 0 then error({"", {"exp-gui_calculator.error"}, {"exp-gui_calculator.div_zero"}}, 0) end return a / b end},
    ["%"] = {2, function(a, b) if b == 0 then error({"", {"exp-gui_calculator.error"}, {"exp-gui_calculator.mod_zero"}}, 0) end return a % b end},
}

local calc_si_suffix = {
    k = 1e3,
    m = 1e6,
    g = 1e9,
    t = 1e12,
    p = 1e15
}

local calc_number_base = {
    x = {value = 16, digits = "%x"},
    b = {value = 2, digits = "[01]"},
    o = {value = 8, digits = "[0-7]"},
}

--- Function label
Elements.calculator_function_label = Gui.define("calculator/function_label")
    :draw{
        type = "label",
        caption = {"exp-gui_calculator.tooltip"},
        style = "heading_2_label",
    }
    :style{
        horizontal_align = "right"
    }

--- Input textfield
Elements.calculator_input_textfield = Gui.define("calculator/input_textfield")
    :draw{
        type = "textfield",
        style = "console_input_textfield",
    }
    :style{
        width = 480,
    }

--- Output label
Elements.calculator_result_label = Gui.define("calculator/result_label")
    :draw{
        type = "label",
        caption = "",
        style = "heading_2_label",
    }
    :style{
        horizontal_align = "right"
    }

--- Empty new line label
Elements.calculator_label_1 = Gui.define("calculator/label_1")
    :draw{
        type = "label",
        caption = "",
        style = "heading_2_label",
    }

--- Container added to the screen
Elements.container = Gui.define("exp-gui_calculatorulator/container")
    :draw(function(def, parent)
        local screen_frame = Gui.elements.screen_frame(parent, nil, true)

        Elements.calculator_function_label(screen_frame)
        Elements.calculator_input_textfield(screen_frame)
        Elements.calculator_result_label(screen_frame)
        Elements.calculator_label_1(screen_frame)

        return Gui.elements.screen_frame.get_root_element(screen_frame)
    end)

--- Add a button to create the container
Gui.toolbar.create_button{
    name = "open_calculator",
    sprite = "entity/arithmetic-combinator",
    tooltip = { "exp-gui_calculator.tooltip" },
    visible = function(player, element)
        return Roles.player_has_permission(player, "exp-gui_calculator")
    end
}:on_click(function(def, player, element, event)
    Elements.container(player.gui.screen)
end)

--- Parse Value
function Elements.parse(expression)
    local cursor = 1

    local function skip_space()
        while expression:sub(cursor, cursor) == " " do
            cursor = cursor + 1
        end
    end

    local function factorial(n)
        if n < 0 then
            return error({"", {"exp-gui_calculator.error"}, {"exp-gui_calculator.factorial_neg", n}}, 0)

        elseif n > 170 then
            return error({"", {"exp-gui_calculator.error"}, {"exp-gui_calculator.factorial_large", n}}, 0)
        end

        if n ~= math.floor(n) then
            return error({"", {"exp-gui_calculator.error"}, {"exp-gui_calculator.factorial_int", n}}, 0)
        end

        local result = 1

        for i = 2, n do
            result = result * i
        end

        return result
    end

    local parse_expr

    local function parse_atom()
        skip_space()
        local character = expression:sub(cursor, cursor)

        if character == "|" then
            cursor = cursor + 1
            ---@diagnostic disable-next-line: need-check-nil
            local value = parse_expr(1)
            skip_space()

            if expression:sub(cursor, cursor) ~= "|" then
                return error({"", {"exp-gui_calculator.error"}, {"exp-gui_calculator.expected_bar"}}, 0)
            end

            cursor = cursor + 1
            return math.abs(value)

        elseif character == "(" then
            cursor = cursor + 1
            ---@diagnostic disable-next-line: need-check-nil
            local value = parse_expr(1)
            skip_space()

            if expression:sub(cursor, cursor) ~= ")" then
                return error({"", {"exp-gui_calculator.error"}, {"exp-gui_calculator.expected_paren"}}, 0)
            end

            cursor = cursor + 1
            return value

        elseif character == "" then
            return error({"", {"exp-gui_calculator.error"}, {"exp-gui_calculator.unexpected_end"}}, 0)

        elseif character:match("%a") then
            skip_space()
            local start = cursor

            while expression:sub(cursor, cursor):match("%w") do
                cursor = cursor + 1
            end

            local name = expression:sub(start, cursor - 1)
            local fn = calc_function[name]
            skip_space()

            if expression:sub(cursor, cursor) == "(" then
                if not fn then
                    return error({"", {"exp-gui_calculator.error"}, {"exp-gui_calculator.unknown_fn"}}, 0)
                end

                cursor = cursor + 1
                ---@diagnostic disable-next-line: need-check-nil
                local argument = parse_expr(1)
                skip_space()

                if expression:sub(cursor, cursor) ~= ")" then
                    return error({"", {"exp-gui_calculator.error"}, {"exp-gui_calculator.expected_paren"}}, 0)
                end

                cursor = cursor + 1
                return fn(argument)
            end

            if fn then
                return error({"", {"exp-gui_calculator.error"}, {"exp-gui_calculator.expected_open", name}}, 0)
            end

            return error({"", {"exp-gui_calculator.error"}, {"exp-gui_calculator.unknown_id", name}}, 0)

        else
            skip_space()

            if expression:sub(cursor, cursor) == "0" then
                local base = calc_number_base[expression:sub(cursor + 1, cursor + 1):lower()]
                if base then
                    local literal_start = cursor
                    cursor = cursor + 2
                    local digit_start = cursor

                    while expression:sub(cursor, cursor):match(base.digits) do
                        cursor = cursor + 1
                    end

                    if cursor == digit_start or expression:sub(cursor, cursor):match("%w") then
                        while expression:sub(cursor, cursor):match("%w") do
                            cursor = cursor + 1
                        end

                        return error({"", {"exp-gui_calculator.error"}, {"exp-gui_calculator.invalid_num", expression:sub(literal_start, cursor - 1)}}, 0)
                    end

                    return tonumber(expression:sub(digit_start, cursor - 1), base.value)
                end
            end

            local literal = expression:match("^(%d+%.?%d*[eE][%+%-]?%d+)", cursor) or expression:match("^(%d+%.?%d*)", cursor)

            if not literal then
                return error({"", {"exp-gui_calculator.error"}, {"exp-gui_calculator.expected_num"}}, 0)
            end

            cursor = cursor + literal:len()
            local num = tonumber(literal)

            if not num then
                return error({"", {"exp-gui_calculator.error"}, {"exp-gui_calculator.invalid_num", literal}}, 0)
            end

            return num
        end
    end

    local function parse_factor()
        skip_space()

        if expression:sub(cursor, cursor) == "-" then
            cursor = cursor + 1
            return -parse_factor()

        elseif expression:sub(cursor, cursor) == "+" then
            cursor = cursor + 1
            return parse_factor()
        end

        local base = parse_atom()
        skip_space()
        local suffix = calc_si_suffix[expression:sub(cursor, cursor)]

        if suffix then
            cursor = cursor + 1
            base = base * suffix
        end

        skip_space()

        if expression:sub(cursor, cursor) == "!" then
            cursor = cursor + 1
            base = factorial(base)
        end

        skip_space()

        if expression:sub(cursor, cursor + 1) == "**" then
            cursor = cursor + 2
            return base ^ parse_factor()

        elseif expression:sub(cursor, cursor) == "^" then
            cursor = cursor + 1
            return base ^ parse_factor()
        end

        return base
    end

    parse_expr = function(min_prec)
        local lhs = parse_factor()

        while true do
            skip_space()
            local entry = calc_function_operation[expression:sub(cursor, cursor)]

            if not entry or entry[1] < min_prec then
                break
            end

            cursor = cursor + 1
            ---@diagnostic disable-next-line: need-check-nil
            lhs = entry[2](lhs, parse_expr(entry[1] + 1))
        end

        return lhs
    end

    local ok, result = pcall(function()
        local value = parse_expr(1)
        skip_space()

        if cursor <= #expression then
            error({"", {"exp-gui_calculator.error"}, {"exp-gui_calculator.trailing", expression:sub(cursor, expression:len())}}, 0)
        end

        return value
    end)

    return ok and format_number(result, false) or (type(result) == "table" and result or {"exp-gui_calculator.error", tostring(result)})
end

--- Value change
function Elements.change(event)
    event.element.parent.calculator_result_label.caption = event.text == "" and "" or Elements.parse(event.text:lower())
end

local e = defines.events

return {
    elements = Elements,
    events = {
        [e.on_gui_text_changed] = Elements.change,
    },
}
