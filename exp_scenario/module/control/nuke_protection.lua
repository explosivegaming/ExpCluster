--[[-- Control - Nuke Protection
Disable new players from having certain items in their inventory, most commonly nukes
]]

local ExpUtil = require("modules/exp_util")
local Roles = require("modules.exp_legacy.expcore.roles")
local config = require("modules.exp_legacy.config.nukeprotect")

--- Check all items in the given inventory
--- @param player LuaPlayer
--- @param type defines.inventory
--- @param banned_items string[]
local function check_items(player, type, banned_items)
    -- If the player has perms to be ignored, then they should be
    if config.ignore_permission and Roles.player_allowed(player, config.ignore_permission) then return end
    if config.ignore_admins and player.admin then return end

    local items = {} --- @type LuaItemStack[]
    local inventory = assert(player.get_inventory(type))
    -- Check what items the player has
    for i = 1, #inventory do
        local item = inventory[i]
        if item.valid_for_read and banned_items[item.name] then
            player.print{ "exp_nuke-protection.chat-found", item.prototype.localised_name }
            items[#items + 1] = item
        end
    end

    -- Move any items they aren't allowed
    ExpUtil.move_items_to_surface{
        items = items,
        surface = game.planets.nauvis.surface,
        allow_creation = true,
        name = "iron-chest",
    }
end

--- Add event handlers for the different inventories
local events = {}
for index, inventory in ipairs(config.inventories) do
    if next(inventory.items) then
        local assert_msg = "invalid event, no player index, index: " .. index
        --- @param event { player_index: number }
        events[inventory.event] = function(event)
            local player_index = assert(event.player_index, assert_msg)
            local player = assert(game.get_player(player_index))
            if player and player.valid then
                check_items(player, inventory.inventory, inventory.items)
            end
        end
    end
end

return {
    events = events,
}
