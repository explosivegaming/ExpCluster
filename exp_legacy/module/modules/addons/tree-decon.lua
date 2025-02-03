--- Makes trees which are marked for decon "decay" quickly to allow faster building
-- @addon Tree-Decon

local Storage = require("modules/exp_util/storage")
local Gui = require("modules/exp_gui")

local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event
local Roles = require("modules.exp_legacy.expcore.roles") --- @dep expcore.roles
local PlayerData = require("modules.exp_legacy.expcore.player_data") --- @dep expcore.player_data

-- Storage queue used to store trees that need to be removed, also cache for player roles
local cache = {}
local tree_queue = { _head = 0 }
Storage.register({ tree_queue, cache }, function(tbl)
    tree_queue = tbl[1]
    cache = tbl[2]
end)

local function get_permission(player_index)
    if cache[player_index] == nil then
        local player = game.players[player_index]
        if Roles.player_allowed(player, "fast-tree-decon") then
            cache[player_index] = "fast"
        elseif Roles.player_allowed(player, "standard-decon") then
            cache[player_index] = "standard"
        else
            cache[player_index] = player.force
        end
    end

    return cache[player_index]
end

-- Left menu button to toggle between fast decon and normal decon marking
local HasEnabledDecon = PlayerData.Settings:combine("HasEnabledDecon")
HasEnabledDecon:set_default(false)

Gui.toolbar.create_button{
    name = "toggle-tree-decon",
    sprite = "entity/tree-01",
    tooltip = { "tree-decon.main-tooltip" },
    auto_toggle = true,
    visible = function(player, _)
        return Roles.player_allowed(player, "fast-tree-decon")
    end
}:on_click(function(def, player, element)
    local state = Gui.toolbar.get_button_toggled_state(def, player)
    HasEnabledDecon:set(player, state)
    player.print{ "tree-decon.toggle-msg", state and { "tree-decon.enabled" } or { "tree-decon.disabled" } }
end)

-- Add trees to queue when marked, only allows simple entities and for players with role permission
Event.add(defines.events.on_marked_for_deconstruction, function(event)
    -- Check which type of decon a player is allowed
    local index = event.player_index
    if not index then return end

    -- Check what should happen to this entity
    local entity = event.entity
    if not entity or not entity.valid then return end

    -- Not allowed to decon this entity
    local last_user = entity.last_user
    local allow = get_permission(index)
    if last_user and allow ~= "standard" and allow ~= "fast" then
        entity.cancel_deconstruction(allow)
        return
    end

    -- Allowed to decon this entity, but not fast
    if allow ~= "fast" then return end

    local player = game.get_player(index)
    if not HasEnabledDecon:get(player) then return end

    -- Allowed fast decon on this entity, just trees
    local head = tree_queue._head + 1
    if not last_user and entity.type ~= "cliff" then
        tree_queue[head] = entity
        tree_queue._head = head
    end
end)

-- Remove trees at random till the queue is empty
Event.add(defines.events.on_tick, function()
    local head = tree_queue._head
    if head == 0 then return end

    local max_remove = math.floor(head / 100) + 1
    local remove_count = math.random(0, max_remove)
    while remove_count > 0 and head > 0 do
        local remove_index = math.random(1, head)
        local entity = tree_queue[remove_index]
        tree_queue[remove_index] = tree_queue[head]
        head = head - 1
        if entity and entity.valid then
            remove_count = remove_count - 1
            entity.destroy()
        end
    end

    tree_queue._head = head
end)

-- Clear the cache
Event.on_nth_tick(300, function()
    for key, _ in pairs(cache) do
        cache[key] = nil
    end
end)

-- Clear trees when hit with a car
--- @param event EventData.on_entity_damaged
Event.add(defines.events.on_entity_damaged, function(event)
    if not (event.damage_type.name == "impact" and event.force) then
        return
    end

    if not (event.entity.type == "tree" or event.entity.type == "simple-entity") then
        return
    end

    if (not event.cause) or (event.cause.type ~= "car") then
        return
    end

    local driver = event.cause.get_driver()
    if not driver then return end
    if driver.object_name ~= "LuaPlayer" then
        driver = driver.player
        if not driver then return end
    end

    local allow = get_permission(driver.index)
    if allow == "fast" and HasEnabledDecon:get(driver) then
        event.entity.destroy()
    else
        event.entity.order_deconstruction(event.force, driver)
    end
end)
