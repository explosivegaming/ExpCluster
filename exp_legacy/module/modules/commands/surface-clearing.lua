--[[-- Commands Module - Clear Item On Ground
    - Adds a command that clear item on ground so blueprint can deploy safely
    @commands Clear Item On Ground
]]

local ExpUtil = require("modules/exp_util")
local Commands = require("modules.exp_legacy.expcore.commands") --- @dep expcore.commands
require("modules.exp_legacy.config.expcore.command_general_parse")

Commands.new_command("clear-item-on-ground", { "expcom-surface-clearing.description-ci" }, "Clear Item On Ground")
    :add_param("range", false, "integer-range", 1, 1000)
    :register(function(player, range)
        local items = {} --- @type LuaItemStack[]
        -- Intentionally left as player.position to allow use in remote view
        local entities = player.surface.find_entities_filtered{ position = player.position, radius = range, name = "item-on-ground" }
        for _, e in pairs(entities) do
            if e.stack then
                items[#items + 1] = e.stack
            end
        end

        ExpUtil.move_items_to_surface{
            items = items,
            surface = player.surface,
            allow_creation = true,
            name = "iron-chest",
        }

        return Commands.success
    end)

Commands.new_command("clear-blueprint", { "expcom-surface-clearing.description-cb" }, "Clear Blueprint")
    :add_param("range", false, "integer-range", 1, 1000)
    :register(function(player, range)
        -- Intentionally left as player.position to allow use in remote view
        for _, e in pairs(player.surface.find_entities_filtered{ position = player.position, radius = range, type = "entity-ghost" }) do
            e.destroy()
        end

        return Commands.success
    end)
