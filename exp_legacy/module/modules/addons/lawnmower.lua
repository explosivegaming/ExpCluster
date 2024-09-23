--[[-- Addon Lawnmower
    - Adds a command that clean up biter corpse and nuclear hole
    @addon Lawnmower
]]

local Commands = require 'expcore.commands' --- @dep expcore.commands
local Event = require 'utils.event' --- @dep utils.event
local config = require 'config.lawnmower' --- @dep config.lawnmower
require 'config.expcore.command_general_parse'

Commands.new_command('lawnmower', {'expcom-lawnmower.description'}, 'Clean up biter corpse, decoratives and nuclear hole')
:add_param('range', false, 'integer-range', 1, 200)
:register(function(player, range)
	local tile_to_do = {}

    player.surface.destroy_decoratives({position=player.position, radius=range})

	local entities = player.surface.find_entities_filtered{position=player.position, radius=range, type='corpse'}

	for _, entity in pairs(entities) do
		if (entity.name ~= 'transport-caution-corpse' and entity.name ~= 'invisible-transport-caution-corpse') then
			entity.destroy()
		end
	end

	local tiles = player.surface.find_tiles_filtered{position=player.position, radius=range, name={'nuclear-ground'}}

	for _, tile in pairs(tiles) do
		table.insert(tile_to_do, {name='grass-1', position=tile.position})
	end

	player.surface.set_tiles(tile_to_do)

    return Commands.success
end)

local function destroy_decoratives(entity)
    if entity.type ~= 'entity-ghost' and entity.type ~= 'tile-ghost' and entity.prototype.selectable_in_game then
        entity.surface.destroy_decoratives{area=entity.selection_box}
    end
end

if config.destroy_decoratives then
	Event.add(defines.events.on_built_entity, function(event)
		destroy_decoratives(event.created_entity)
	end)

	Event.add(defines.events.on_robot_built_entity, function(event)
		destroy_decoratives(event.created_entity)
	end)

	Event.add(defines.events.script_raised_built, function(event)
		destroy_decoratives(event.entity)
	end)

	Event.add(defines.events.script_raised_revive, function(event)
		destroy_decoratives(event.entity)
	end)
end
