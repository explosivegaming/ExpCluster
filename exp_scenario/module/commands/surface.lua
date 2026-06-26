--[[-- Commands - Clear Item On Ground
Adds a command that clear item on ground so blueprint can deploy safely
]]

local AABB = require("modules/exp_util/aabb")
local Commands = require("modules/exp_commands")
local ExpUtil = require("modules/exp_util")
local move_items = ExpUtil.move_items_to_surface
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

--- Clear all item on the ground on a single surface
commands.clear_ground_item = Commands.new("clear-ground-item", { "exp-commands_surface.description-item" })
    :register(function(player)
        move_items{
            surface = player.surface,
            items = get_ground_items(player.surface),
            allow_creation = true,
            name = "iron-chest",
        }
        game.print{ "exp-commands_surface.item" }
    end)

--- Clear all blueprint in a single surface
commands.clear_blueprint_surface = Commands.new("clear-blueprint-surface", { "exp-commands_surface.description-blueprint" })
    :register(function(player)
        local entities = player.surface.find_entities_filtered{ type = "entity-ghost" }
        for _, entity in ipairs(entities) do
            entity.destroy()
        end
        game.print{ "exp-commands_surface.blueprint" }
    end)

--- Clear all blueprint in the area, selected by toggle player selection mode
--- @class ExpCommands_ClearBlueprint.commands.clear_blueprint: ExpCommand
--- @overload fun(player: LuaPlayer)
commands.clear_blueprint = Commands.new("clear-blueprint", { "exp-commands_surface.description-blueprint" })
    :register(function(player)
        if SelectArea:stop(player) then
            return Commands.status.success{ "exp-commands_surface.exit" }
        end
        SelectArea:start(player)
        return Commands.status.success{ "exp-commands_surface.enter" }
    end) --[[ @as any ]]

--- When an area is selected
SelectArea:on_selection(function(event)
    local area = AABB.expand(event.area)
    local player = game.players[event.player_index]
    local surface = event.surface
    local area_size = (area.right_bottom.x - area.left_top.x) * (area.right_bottom.y - area.left_top.y)

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
