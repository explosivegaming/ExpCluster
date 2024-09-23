--- Disable new players from having certain items in their inventory, most commonly nukes
-- @addon Nukeprotect

local Event = require 'utils.event'          --- @dep utils.event
local Roles = require 'expcore.roles'        --- @dep expcore.roles
local config = require 'config.nukeprotect'  --- @dep config.nukeprotect
local move_items_stack = _C.move_items_stack --- @dep expcore.common


local function check_items(player, type)
	-- if the player has perms to be ignored, then they should be
	if config.ignore_permisison and Roles.player_allowed(player, config.ignore_permisison) then return end
	-- if the players
	if config.ignore_admins and player.admin then return end

	local inventory = player.get_inventory(type)
	for i = 1, #inventory do
		local item = inventory[i]
		if item.valid and item.valid_for_read and config[tostring(type)][item.name] then
			player.print({ "nukeprotect.found", { "item-name." .. item.name } })
			-- insert the items into the table so all items are transferred at once
			move_items_stack({ item })
		end
	end
end

for _, inventory in ipairs(config.inventories) do
	if #inventory.items > 0 then
		Event.add(inventory.event, function(event)
			local player = game.get_player(event.player_index)
			if player and player.valid then
				check_items(player, inventory.inventory)
			end
		end)
	end
end


if config.disable_nuke_research then
	Event.add(defines.events.on_research_started, function(event)
		local name = event.research.name
		if config.disable_nuke_research_names[name] then
			event.research.force.cancel_current_research()
		end
	end)
end
