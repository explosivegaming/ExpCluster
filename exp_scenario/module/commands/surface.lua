--[[-- Commands - Clear Item On Ground
Adds a command that clear item on ground so blueprint can deploy safely
]]

local ExpUtil = require("modules/exp_util")
local move_items = ExpUtil.move_items_to_surface

local Commands = require("modules/exp_commands")
local format_player_name = Commands.format_player_name_locale

--- @param surface LuaSurface
--- @return LuaItemStack[]
local function get_ground_items(surface)
    local items = {} --- @type LuaItemStack[]
    local entities = surface.find_entities_filtered{ name = "item-on-ground" }
    for index, entity in ipairs(entities) do
        items[index] = entity.stack
    end
    return items
end

--- Clear all items on the ground, optional to select a single surface
Commands.new("clear-ground-items", { "exp-commands_surface.description-items" })
    :optional("surface", { "exp-commands_surface.arg-surface" }, Commands.types.surface)
    :register(function(player, surface)
        --- @cast surface LuaSurface?
        local player_name = format_player_name(player)
        if surface then
            move_items{
                surface = surface,
                items = get_ground_items(surface),
                allow_creation = true,
                name = "iron-chest",
            }
            game.print{ "exp-commands_surface.items-surface", player_name, surface.localised_name }
        else
            for _, surface in pairs(game.surfaces) do
                move_items{
                    surface = surface,
                    items = get_ground_items(surface),
                    allow_creation = true,
                    name = "iron-chest",
                }
            end
            game.print{ "exp-commands_surface.items-all", player_name }
        end
    end)

--- Clear all blueprints, optional to select a single surface
Commands.new("clear-blueprints", { "exp-commands_surface.description-blueprints" })
    :optional("surface", { "exp-commands_surface.arg-surface" }, Commands.types.surface)
    :register(function(player, surface)
        --- @cast surface LuaSurface?
        local player_name = format_player_name(player)
        if surface then
            local entities = surface.find_entities_filtered{ type = "entity-ghost" }
            for _, entity in ipairs(entities) do
                entity.destroy()
            end
            game.print{ "exp-commands_surface.blueprint-surface", player_name, surface.localised_name }
        else
            for _, surface in pairs(game.surfaces) do
                local entities = surface.find_entities_filtered{ type = "entity-ghost" }
                for _, entity in ipairs(entities) do
                    entity.destroy()
                end
            end
            game.print{ "exp-commands_surface.blueprint-all", player_name }
        end
    end)

--- Clear all blueprints in a radius around you
Commands.new("clear-blueprints-radius", { "exp-commands_surface.description-radius" })
    :argument("radius", { "exp-commands_surface.arg-radius" }, Commands.types.number_range(1, 100))
    :register(function(player, radius)
        --- @cast radius number
        local player_name = format_player_name(player)
        local entities = player.surface.find_entities_filtered{
            type = "entity-ghost",
            position = player.position,
            radius = radius,
        }

        for _, entity in ipairs(entities) do
            entity.destroy()
        end

        game.print{ "exp-commands_surface.blueprint-radius", player_name, radius, player.surface.localised_name }
    end)
