--[[-- Commands - Clear Item On Ground
Adds a command that clear item on ground so blueprint can deploy safely
]]

local AABB = require("modules/exp_util/aabb")
local Commands = require("modules/exp_commands")
local ExpUtil = require("modules/exp_util")
local move_items = ExpUtil.move_items_to_surface
local format_player_name = Commands.format_player_name_locale
local Selection = require("modules/exp_util/selection")
local SelectArea = Selection.connect("ExpCommand_ClearBlueprint")

--- @class ExpCommand_ClearBlueprint.commands
local commands = {}

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
commands.clear_ground_items = Commands.new("clear-ground-items", { "exp-commands_surface.description-items" })
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
commands.clear_blueprints_surface = Commands.new("clear-blueprints-surface", { "exp-commands_surface.description-blueprints" })
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
--- Toggle player selection mode
--- @class ExpCommands_ClearBlueprint.commands.clear_blueprints: ExpCommand
--- @overload fun(player: LuaPlayer)
commands.clear_blueprints = Commands.new("clear-blueprints", { "exp-commands_surface.description-blueprints" })
    :register(function(player)
        if SelectArea:stop(player) then
            return Commands.status.success{ "exp-commands_waterfill.exit" }
        end
        SelectArea:start(player)
        return Commands.status.success{ "exp-commands_waterfill.enter" }
    end) --[[ @as any ]]

--- When an area is selected to be converted
SelectArea:on_selection(function(event)
    local area = AABB.expand(event.area)
    local player = game.players[event.player_index]
    local player_name = format_player_name(player)
    local surface = event.surface

    local area_size = (area.right_bottom.x - area.left_top.x) * (area.right_bottom.y - area.left_top.y)

    if area_size > 1000 then
        player.print({ "exp-commands_waterfill.area-too-large", 1000, area_size }, Commands.print_settings.error)
        return
    end

    local entities = surface.find_entities_filtered{ type = "entity-ghost", area = area }

    for _, entity in ipairs(entities) do
        entity.destroy()
    end

    player.print({ "exp-commands_waterfill.complete", #entities }, Commands.print_settings.default)
end)

return {
    commands = commands,
}
