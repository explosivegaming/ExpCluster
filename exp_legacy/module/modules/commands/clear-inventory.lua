--[[-- Commands Module - Clear Inventory
    - Adds a command that allows admins to clear people's inventorys
    @commands Clear-Inventory
]]

local ExpUtil = require("modules/exp_util")
local Commands = require("modules.exp_legacy.expcore.commands") --- @dep expcore.commands
require("modules.exp_legacy.config.expcore.command_role_parse")

--- Clears a players inventory
-- @command clear-inventory
-- @tparam LuaPlayer player the player to clear the inventory of
Commands.new_command("clear-inventory", { "expcom-clr-inv.description" }, "Clears a players inventory")
    :add_param("player", false, "player-role")
    :add_alias("clear-inv", "move-inventory", "move-inv")
    :register(function(_, player)
        local inventory = player.get_main_inventory()
        if not inventory then
            return Commands.error{ "expcore-commands.reject-player-alive" }
        end

        ExpUtil.transfer_inventory_to_surface{
            inventory = inventory,
            surface = game.planets.nauvis.surface,
            name = "iron-chest",
            allow_creation = true,
        }
    end)
