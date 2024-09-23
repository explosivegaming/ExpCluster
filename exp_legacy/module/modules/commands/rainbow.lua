--[[-- Commands Module - Rainbow
    - Adds a command that prints your message in rainbow font
    @commands Rainbow
]]

local Commands = require 'expcore.commands' --- @dep expcore.commands
local format_chat_colour = _C.format_chat_colour --- @dep expcore.common

local function step_component(c1, c2)
    if c1 < 0 then
        return 0, c2+c1
    elseif c1 > 1 then
        return 1, c2-c1+1
    else
        return c1, c2
    end
end

local function step_color(color)
    color.r, color.g = step_component(color.r, color.g)
    color.g, color.b = step_component(color.g, color.b)
    color.b, color.r = step_component(color.b, color.r)
    color.r = step_component(color.r, 0)
    return color
end

local function next_color(color, step)
    step = step  or 0.1
    local new_color = {r=0, g=0, b=0}
    if color.b == 0 and color.r ~= 0 then
        new_color.r = color.r-step
        new_color.g = color.g+step
    elseif color.r == 0 and color.g ~= 0 then
        new_color.g = color.g-step
        new_color.b = color.b+step
    elseif color.g == 0 and color.b ~= 0 then
        new_color.b = color.b-step
        new_color.r = color.r+step
    end
    return step_color(new_color)
end

--- Sends an rainbow message in the chat
-- @command rainbow
-- @tparam string message the message that will be printed in chat
Commands.new_command('rainbow', {'expcom-rainbow.description'}, 'Sends an rainbow message in the chat')
:add_param('message', false)
:enable_auto_concat()
:register(function(player, message)
    local player_name = player and player.name or '<Server>'
    local player_color = player and player.color or nil
    local color_step = 3/message:len()
    if color_step > 1 then color_step = 1 end
    local current_color = {r=1, g=0, b=0}
    local output = format_chat_colour(player_name..': ', player_color)
    output = output..message:gsub('%S', function(letter)
        local rtn = format_chat_colour(letter, current_color)
        current_color = next_color(current_color, color_step)
        return rtn
    end)
    game.print(output)
end)
