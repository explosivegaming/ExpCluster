--[[-- Commands - Enemy
Adds a commands of handling the enemy force, such as killing all or disabling them
]]

local Commands = require("modules/exp_commands")

--- Kill all enemies
Commands.new("kill-enemies", { "exp-commands_enemy.description-kill" })
    :add_aliases{ "kill-biters" }
    :add_flags{ "admin_only" }
    :register(function(player)
        game.forces["enemy"].kill_all_units()
        game.print{ "exp-commands_enemy.kill", player.name }
    end)

--- Remove all enemies on a surface
Commands.new("remove-enemies", { "exp-commands_enemy.description-remove" })
    :optional("surface", { "exp-commands_enemy.arg-surface" }, Commands.types.surface)
    :add_aliases{ "remove-biters" }
    :add_flags{ "admin_only" }
    :defaults{
        surface = function(player) return player.surface end
    }
    :register(function(player, surface)
        for _, entity in pairs(surface.find_entities_filtered{ force = "enemy" }) do
            entity.destroy()
        end
        -- surface.map_gen_settings.autoplace_controls["enemy-base"].size = "none" -- TODO make this work for SA
        game.print{ "exp-commands_enemy.remove", player.name }
    end)
