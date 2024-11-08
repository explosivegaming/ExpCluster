--[[-- Commands - Kill
Adds a command that allows players to kill themselves and others
]]

local Commands = require("modules/exp_commands")

local Roles = require("modules.exp_legacy.expcore.roles") --- @dep expcore.roles
local highest_role = Roles.get_player_highest_role

--- Kills yourself or another player.
Commands.new("kill", { "exp-commands_kill.description" })
    :optional("player", { "exp-commands_kill.arg-player" }, Commands.types.lower_role_player_alive)
    :defaults{
        player = function(player)
            return player.character and player.character.health > 0 and player or nil
        end
    }
    :register(function(player, other_player)
        --- @cast other_player LuaPlayer?
        if other_player == nil then
            -- Can only be nil if the target is the player and they are already dead
            return Commands.status.error{ "exp-commands_kill.already-dead" }
        elseif other_player == player then
            -- You can always kill yourself
            other_player.character.die()
        elseif highest_role(other_player).index < highest_role(player).index then
            -- Can kill lower role players
            other_player.character.die()
        else
            return Commands.status.unauthorised{ "exp-commands_kill.lower-role" }
        end
    end)
