--- Disable new players from having certain items in their inventory, most commonly nukes
-- @addon Nukeprotect

local ExpUtil = require("modules/exp_util")
local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event
local Roles = require("modules.exp_legacy.expcore.roles") --- @dep expcore.roles
local config = require("modules.exp_legacy.config.nukeprotect") --- @dep config.nukeprotect

--- Check all items in the given inventory
---@param player LuaPlayer
---@param type defines.inventory
local function check_items(player, type)
    -- if the player has perms to be ignored, then they should be
    if config.ignore_permisison and Roles.player_allowed(player, config.ignore_permisison) then return end
    -- if the players
    if config.ignore_admins and player.admin then return end

    local items = {} --- @type LuaItemStack[]
    local inventory = assert(player.get_inventory(type))
    for i = 1, #inventory do
        local item = inventory[i]
        if item.valid and item.valid_for_read and config[tostring(type)][item.name] then
            player.print{ "nukeprotect.found", { "item-name." .. item.name } }
            items[#items + 1] = item
        end
    end

    ExpUtil.move_items_to_surface{
        items = items,
        surface = game.planets.nauvis.surface,
        allow_creation = true,
        name = "iron-chest",
    }
end

for _, inventory in ipairs(config.inventories) do
    if #inventory.items > 0 then
        Event.add(inventory.event, function(event)
            local player = game.players[event.player_index]
            if player and player.valid then
                check_items(player, inventory.inventory)
            end
        end)
    end
end
