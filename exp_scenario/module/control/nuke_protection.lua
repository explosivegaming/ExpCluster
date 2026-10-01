--[[-- Control - Nuke Protection
Disable new players from having certain items in their inventory, most commonly nukes
]]

local ExpUtil = require("modules/exp_util")
local Feature = require("modules/exp_scenario/features")
local Roles = require("modules/exp_roles")

local feature = Feature.register("nuke_protection", {
    ignore_admins = true, --- @setting ignore_admins Admins can hold banned items
    banned_items = Feature.set{ "atomic-bomb" }, --- @setting banned_items Items which are removed from the inventory of players without the bypass permission
})
local config = feature.config

--- The inventories which are checked and the events which trigger the check
local inventories = {
    [defines.events.on_player_ammo_inventory_changed] = defines.inventory.character_ammo,
    [defines.events.on_player_armor_inventory_changed] = defines.inventory.character_armor,
    [defines.events.on_player_gun_inventory_changed] = defines.inventory.character_guns,
    [defines.events.on_player_main_inventory_changed] = defines.inventory.character_main,
}

--- Check all items in the given inventory
--- @param player LuaPlayer
--- @param type defines.inventory
local function check_items(player, type)
    -- If the player has perms to be ignored, then they should be
    if Roles.player_has_permission(player, "exp_scenario.bypass.nuke_protection") then return end
    if config.ignore_admins and player.admin then return end

    local banned_items = config.banned_items
    local items = {} --- @type LuaItemStack[]
    local inventory = assert(player.get_inventory(type))
    -- Check what items the player has
    for i = 1, #inventory do
        local item = inventory[i --[[@as uint]]]
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
for event_id, inventory in pairs(inventories) do
    --- @param event { player_index: number }
    events[event_id] = function(event)
        local player = assert(game.get_player(event.player_index))
        if player.valid then
            check_items(player, inventory)
        end
    end
end

return feature:guard{
    events = events,
}
