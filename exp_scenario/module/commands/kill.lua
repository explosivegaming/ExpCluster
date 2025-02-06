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
        elseif (other_player == player) or (highest_role(other_player).index >= highest_role(player).index) then
            -- You can always kill yourself or can kill lower role players
            if script.active_mods["space-age"] then
                other_player.surface.create_entity{ name = "lightning", position = { other_player.position.x, other_player.position.y - 16 }, target = other_player.character }
            end
            other_player.character.die()
        else
            return Commands.status.unauthorised{ "exp-commands_kill.lower-role" }
        end
    end)
