--[[-- Commands - Clear Inventory
Adds a command that allows admins to clear people's inventory
]]

local ExpUtil = require("modules/exp_util")
local transfer_inventory = ExpUtil.transfer_inventory_to_surface

local Commands = require("modules/exp_commands")

--- Clears a players inventory
Commands.new("clear-inventory", { "exp-commands_clear-inventory.description" })
    :argument("player", { "exp-commands_clear-inventory.arg-player" }, Commands.types.lower_role_player)
    :add_flags{ "admin_only" }
    :register(function(player, other_player)
        local inventory = other_player.get_main_inventory()
        if not inventory then
            return Commands.status.error{ "expcore-commands.reject-player-alive" }
        end

        transfer_inventory{
            inventory = inventory,
            surface = game.planets.nauvis.surface,
            name = "iron-chest",
            allow_creation = true,
        }
    end)
