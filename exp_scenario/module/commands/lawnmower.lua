--[[-- Commands - Lawnmower
Adds a command that clean up biter corpse and nuclear hole
]]

local Commands = require("modules/exp_commands")
local config = require("modules.exp_legacy.config.lawnmower") --- @dep config.lawnmower

Commands.new("lawnmower", { "exp-commands_lawnmower.description" })
    :argument("range", { "exp-commands_lawnmower.arg-range" }, Commands.types.integer_range(1, 200))
    :register(function(player, range)
        --- @cast range number
        local surface = player.surface
        
        -- Intentionally left as player.position to allow use in remote view
        local entities = surface.find_entities_filtered{ position = player.position, radius = range, type = "corpse" }
        for _, entity in pairs(entities) do
            if (entity.name ~= "transport-caution-corpse" and entity.name ~= "invisible-transport-caution-corpse") then
                entity.destroy()
            end
        end
        
        local replace_tiles = {}
        local tiles = surface.find_tiles_filtered{ position = player.position, radius = range, name = { "nuclear-ground" } }
        for i, tile in pairs(tiles) do
            replace_tiles[i] = { name = "grass-1", position = tile.position }
        end

        surface.set_tiles(replace_tiles)
        surface.destroy_decoratives{ position = player.position, radius = range }
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
    events = events
}
