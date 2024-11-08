--[[-- Commands - Spectate
Adds commands relating to spectate and follow
]]

local Commands = require("modules/exp_commands")
local Spectate = require("modules.exp_legacy.modules.control.spectate") --- @dep modules.control.spectate

--- Toggles spectator mode for the caller
Commands.new("spectate", { "exp-commands_spectate.description-spectate" })
    :register(function(player)
        if Spectate.is_spectating(player) then
            Spectate.stop_spectate(player)
        else
            Spectate.start_spectate(player)
        end
    end)

--- Enters follow mode for the caller, following the given player.
Commands.new("follow", { "exp-commands_spectate.description-follow" })
    :argument("player", { "exp-command_spectate.arg-player" }, Commands.types.player_online)
    :add_aliases{ "f" }
    :register(function(player, other_player)
        --- @cast other_player LuaPlayer
        if player == other_player then
            return Commands.status.invalid_input{ "exp-command_spectate.follow-self" }
        else
            Spectate.start_follow(player, other_player)
        end
    end)
