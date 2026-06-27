--[[-- Commands - Clear Item On Ground
Adds a command that clear item on ground so blueprint can deploy safely
]]

local AABB = require("modules/exp_util/aabb")
local Commands = require("modules/exp_commands")
local ExpUtil = require("modules/exp_util")
local move_items = ExpUtil.move_items_to_surface
local Selection = require("modules/exp_util/selection")
local SelectArea = Selection.connect("ExpCommand_ClearBlueprint")
local format_player_name = Commands.format_player_name_locale

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

--- Clear all items on the ground on a surface
commands.clear_ground_items = Commands.new("clear-ground-items", { "exp-commands_surface.description-items" })
    :optional("surface", { "exp-commands_surface.arg-surface" }, Commands.types.surface)
    :defaults{
        surface = function(player) return player.surface end
    }
    :register(function(player, surface)
        --- @cast surface LuaSurface
        move_items{
            surface = surface,
            items = get_ground_items(surface),
            allow_creation = true,
            name = "iron-chest",
        }
        local player_name = format_player_name(player)
        game.print{ "exp-commands_surface.items", player_name, surface.localised_name }
    end)

--- Clear all blueprints on a surface
commands.clear_blueprints_surface = Commands.new("clear-blueprints-surface", { "exp-commands_surface.description-blueprints-surface" })
    :optional("surface", { "exp-commands_surface.arg-surface" }, Commands.types.surface)
    :defaults{
        surface = function(player) return player.surface end
    }
    :register(function(player, surface)
        --- @cast surface LuaSurface
        local entities = surface.find_entities_filtered{ type = "entity-ghost" }
        for _, entity in ipairs(entities) do
            entity.destroy()
        end
        local player_name = format_player_name(player)
        game.print{ "exp-commands_surface.blueprints", player_name, surface.localised_name }
    end)

--- Clear all blueprint in the area, selected by toggle player selection mode
--- @class ExpCommands_ClearBlueprint.commands.clear_blueprint: ExpCommand
--- @overload fun(player: LuaPlayer)
commands.clear_blueprints = Commands.new("clear-blueprints", { "exp-commands_surface.description-blueprints" })
    :register(function(player)
        if SelectArea:stop(player) then
            return Commands.status.success{ "exp-commands_surface.exit" }
        end

        SelectArea:start(player)
        return Commands.status.success{ "exp-commands_surface.enter" }
    end) --[[ @as any ]]

--- When an area is selected
SelectArea:on_selection(function(event)
    local player = assert(game.get_player(event.player_index))
    local area = AABB.expand(event.area)
    local area_size = AABB.size(area)
    local surface = event.surface

    if area_size > 1000 then
        player.print({ "exp-commands_surface.area-too-large", 1000, area_size }, Commands.print_settings.error)
        return
    end

    local entities = surface.find_entities_filtered{ type = "entity-ghost", area = area }
    for _, entity in ipairs(entities) do
        entity.destroy()
    end

    game.print({ "exp-commands_surface.complete", #entities }, Commands.print_settings.default)
end)

return {
    commands = commands,
}
