--[[-- Commands - Lawnmower
Adds a command that clean up biter corpse and nuclear hole
]]

local AABB = require("modules/exp_util/aabb")
local Commands = require("modules/exp_commands")
local Selection = require("modules/exp_util/selection")
local SelectArea = Selection.connect("ExpCommand_Lawnmower")
local config = require("modules.exp_legacy.config.lawnmower")

--- @class ExpCommand_Lawnmower.commands
local commands = {}

--- Toggle player selection mode for lawnmower
--- @class ExpCommands_Lawnmower.commands.lawnmower: ExpCommand
--- @overload fun(player: LuaPlayer)
commands.lawnmower = Commands.new("lawnmower", { "exp-commands_lawnmower.description" })
    :register(function(player)
        if SelectArea:stop(player) then
            return Commands.status.success{ "exp-commands_lawnmower.exit" }
        end

        SelectArea:start(player)
        return Commands.status.success{ "exp-commands_lawnmower.enter" }
    end) --[[ @as any ]]

--- When an area is selected to be handled
SelectArea:on_selection(function(event)
    local player = assert(game.get_player(event.player_index))
    local area = AABB.expand(event.area)
    local area_size = AABB.size(area)
    local surface = event.surface

    if area_size > 1000 then
        player.print({ "exp-commands_lawnmower.area-too-large", 1000, area_size }, Commands.print_settings.error)
        return
    end

    local entities = surface.find_entities_filtered{ area = area, type = "corpse" }
    for _, entity in pairs(entities) do
        if (entity.name ~= "transport-caution-corpse" and entity.name ~= "invisible-transport-caution-corpse") then
            entity.destroy()
        end
    end

    local replace_tiles = {}
    local tiles = surface.find_tiles_filtered{ area = area, name = { "nuclear-ground" } }
    for i, tile in pairs(tiles) do
        replace_tiles[i] = { name = "grass-1", position = tile.position }
    end

    surface.set_tiles(replace_tiles)
    surface.destroy_decoratives{ area = area }

    player.print({ "exp-commands_lawnmower.complete", #replace_tiles }, Commands.print_settings.default)
end)

--- @param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.script_raised_built | EventData.script_raised_revive
local function destroy_decoratives(event)
    local entity = event.entity
    if entity.type ~= "entity-ghost" and entity.type ~= "tile-ghost" and entity.prototype.selectable_in_game then
        entity.surface.destroy_decoratives{ area = entity.selection_box }
    end
end

local e = defines.events
local events = {}

if config.destroy_decoratives then
    events[e.on_built_entity] = destroy_decoratives
    events[e.on_robot_built_entity] = destroy_decoratives
    events[e.script_raised_built] = destroy_decoratives
    events[e.script_raised_revive] = destroy_decoratives
end

return {
    events = events,
    commands = commands,
}
