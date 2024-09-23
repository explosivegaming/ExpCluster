
local Color = require 'utils.color_presets' --- @dep utils.color_presets
local Game = {}

--[[ Note to readers
Game.get_player_from_name was removed because game.players[name] works without any edge cases
always true: game.players[name].name == name

Game.get_player_by_index was added originally as a workaround for the following edge case:
player with index of 5 and name of "Cooldude2606"
player with index of 10 and name of "5"
game.players[5].name == "5"

Discovered the following logic:
all keys are first converted to string and search against player names
if this fails it attempts to convert it to a number and search against player indexes
sometimes fails: game.players[index].index == index

Game.get_player_by_index was removed after the above logic was corrected to the following:
when a key is a number it is searched against player indexes, and only their indexes
when a key is a string it is searched against player names, and then against their indexes
always true: game.players[name].name == name; game.players[index].index == index

]]

--- Returns a valid LuaPlayer if given a number, string, or LuaPlayer. Returns nil otherwise.
-- obj <number|string|LuaPlayer>
function Game.get_player_from_any(obj)
    local o_type, p = type(obj)
    if o_type == 'table' then
        p = obj
    elseif o_type == 'string' or o_type == 'number' then
        p = game.players[obj]
    end

    if p and p.valid and p.is_player() then
        return p
    end
end

--- Prints to player or console.
-- @param str <string|table> table if locale is used
-- @param color <table> defaults to white
function Game.player_print(str, color)
    color = color or Color.white
    if game.player then
        game.player.print(str, color)
    else
        print(str)
    end
end

--[[
    Creates a floating text entity at a location with the specified color.
    Example: "+10 iron" or "-10 coins"

    @param surface LuaSurface
    @param position String to display at
    @param text String to display
    @param color table in {r = 0~1, g = 0~1, b = 0~1}, defaults to white.

    @return the created entity
]]
function Game.print_floating_text(surface, position, text, color)
    color = color or Color.white

    return surface.create_entity {
        name = 'tutorial-flying-text',
        color = color,
        text = text,
        position = position
    }
end

--[[
    Creates a floating text entity at the player location with the specified color and offset.
    Example: "+10 iron" or "-10 coins"

    @param text String to display
    @param color table in {r = 0~1, g = 0~1, b = 0~1}, defaults to white.
    @param x_offset number the x offset for the floating text
    @param y_offset number the y offset for the floating text

    @return the created entity
]]
function Game.print_player_floating_text_position(player, text, color, x_offset, y_offset)
    player = Game.get_player_from_any(player)
    if not player or not player.valid then
        return
    end

    local position = player.position
    return Game.print_floating_text(player.surface, {x = position.x + x_offset, y = position.y + y_offset}, text, color)
end

--[[
    Creates a floating text entity at the player location with the specified color in {r, g, b} format.
    Example: "+10 iron" or "-10 coins"

    @param text String to display
    @param color table in {r = 0~1, g = 0~1, b = 0~1}, defaults to white.

    @return the created entity
]]
function Game.print_player_floating_text(player, text, color)
    Game.print_player_floating_text_position(player, text, color, 0, -1.5)
end

return Game