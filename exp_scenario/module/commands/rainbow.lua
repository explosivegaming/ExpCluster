--[[-- Commands - Rainbow
Adds a command that prints your message in rainbow font
]]

local Commands = require("modules/exp_commands")
local format_player_name = Commands.format_player_name_locale
local format_text = Commands.format_rich_text_color

--- Wraps one component into the next
--- @param c1 number
--- @param c2 number
--- @return number, number
local function step_component(c1, c2)
    if c1 < 0 then
        return 0, c2 + c1
    elseif c1 > 1 then
        return 1, c2 - c1 + 1
    else
        return c1, c2
    end
end

--- Wraps all components of a colour ensuring it remains valid
--- @param color Color
--- @return Color
local function step_color(color)
    color.r, color.g = step_component(color.r, color.g)
    color.g, color.b = step_component(color.g, color.b)
    color.b, color.r = step_component(color.b, color.r)
    color.r = step_component(color.r, 0)
    return color
end

--- Get the next colour in the rainbow by the given step
--- @param color Color
--- @param step number
--- @return Color
local function next_color(color, step)
    step = step or 0.1
    local new_color = { r = 0, g = 0, b = 0 }
    if color.b == 0 and color.r ~= 0 then
        new_color.r = color.r - step
        new_color.g = color.g + step
    elseif color.r == 0 and color.g ~= 0 then
        new_color.g = color.g - step
        new_color.b = color.b + step
    elseif color.g == 0 and color.b ~= 0 then
        new_color.b = color.b - step
        new_color.r = color.r + step
    end
    return step_color(new_color)
end

--- Sends an rainbow message in the chat
Commands.new("rainbow", { "exp-commands_rainbow" })
    :argument("message", { "exp-commands_rainbow.arg-message" }, Commands.types.string)
    :enable_auto_concatenation()
    :register(function(player, message)
        local color_step = 3 / message:len()
        if color_step > 1 then color_step = 1 end
        local current_color = { r = 1, g = 0, b = 0 }

        game.print{
            "exp-commands_rainbow.response",
            format_player_name(player),
            message:gsub("%S", function(letter)
                local rtn = format_text(letter, current_color)
                current_color = next_color(current_color, color_step)
                return rtn
            end)
        }
    end)
