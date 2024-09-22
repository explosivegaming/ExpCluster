
local Color = require("modules/exp_util/include/color")
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

return Game