--[[-- Commands - Set Automatic Train
Adds a command that set all train back to automatic
]]

local Commands = require("modules/exp_commands")
local format_player_name = Commands.format_player_name_locale
local format_number = require("util").format_number

--- @class Command.Trains
local module = {}

function module.manual(player, surface, force)
    local trains = game.train_manager.get_trains{
        stock = "locomotive",
        has_passenger = false,
        is_manual = true,
        is_moving = false,
        surface = surface,
        force = force,
    }

    for _, train in ipairs(trains) do
        train.manual_mode = false
    end

    game.print{ "exp-commands_trains.response", format_player_name(player), format_number(#trains, false) }
end

--- Set all trains to automatic
Commands.new("set-trains-to-automatic", { "exp-commands_trains.description" })
    :optional("surface", { "exp-commands_trains.arg-surface" }, Commands.types.surface)
    :optional("force", { "exp-commands_trains.arg-force" }, Commands.types.force)
    :register(function(player, surface, force)
        --- @cast surface LuaSurface?
        --- @cast force LuaForce?
        module.manual(player, surface, force)
    end)

return module
