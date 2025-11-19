--[[-- Control - Fast Deconstruction
Makes trees which are marked for decon "decay" quickly to allow faster building
]]

local Gui = require("modules/exp_gui")
local Async = require("modules/exp_util/async")
local Roles = require("modules.exp_legacy.expcore.roles")

local PlayerData = require("modules.exp_legacy.expcore.player_data")
local HasEnabledDecon = PlayerData.Settings:combine("HasEnabledDecon")
HasEnabledDecon:set_default(false)

local random = math.random
local floor = math.floor
local min = math.min

--- @class TreeDeconCache
--- @field tick number The tick this cache is valid
--- @field player_index number
--- @field player LuaPlayer
--- @field force LuaForce
--- @field trees LuaEntity[]
--- @field tree_count number
--- @field permission "fast" | "allow" | "disallow"
--- @field task Async.AsyncReturn

local cache --- @type TreeDeconCache?

local remove_trees_async =
    Async.register(function(task_data)
        --- @cast task_data TreeDeconCache
        if task_data.tree_count == 0 then
            return Async.status.complete()
        end

        local head = task_data.tree_count
        local trees = task_data.trees

        local max_remove = floor(head / 100) + 1
        local remove_count = min(random(0, max_remove), head)
        for i = 1, remove_count do
            local index = random(1, head)
            local entity = trees[index]
            trees[index] = trees[head]
            head = head - 1

            if entity and entity.valid then
                entity.destroy()
            end
        end

        task_data.tree_count = head
        return Async.status.continue(task_data)
    end)

--- Check the permission the player has
--- @param player LuaPlayer
--- @return "fast" | "allow" | "disallow"
local function get_permission(player)
    if Roles.player_allowed(player, "fast-tree-decon") then
        return HasEnabledDecon:get(player) and "fast" or "allow"
    elseif Roles.player_allowed(player, "standard-decon") then
        return "allow"
    else
        return "disallow"
    end
end

--- Return or build the cache for a player
--- @param player_index number
--- @return TreeDeconCache
local function get_player_cache(player_index)
    -- Return the current cache if it is valid
    if cache and cache.tick == game.tick and cache.player_index == player_index then
        return cache
    end

    -- Create a new cache if the previous on is in use
    if not cache or cache.task and not cache.task.completed then
        cache = {} --[[@as any]]
    end

    local player = assert(game.get_player(player_index))
    cache.tick = game.tick
    cache.player_index = player_index
    cache.player = player
    cache.force = player.force --[[ @as LuaForce ]]
    cache.tree_count = 0
    cache.trees = {}
    cache.permission = get_permission(player)
    cache.task = remove_trees_async:start_soon(cache)

    return cache
end

-- Left menu button to toggle between fast decon and normal decon marking
Gui.toolbar.create_button{
    name = "toggle-tree-decon",
    sprite = "entity/tree-01",
    tooltip = { "exp_fast-decon.tooltip-main" },
    auto_toggle = true,
    visible = function(player, _)
        return Roles.player_allowed(player, "fast-tree-decon")
    end
}:on_click(function(def, player, element)
    local state = Gui.toolbar.get_button_toggled_state(def, player)
    HasEnabledDecon:set(player, state)
    player.print{ "exp_fast-decon.chat-toggle", state and { "exp_fast-decon.chat-enabled" } or { "exp_fast-decon.chat-disabled" } }
end)

-- Add trees to queue when marked, only allows simple entities and for players with role permission
--- @param event EventData.on_marked_for_deconstruction
local function on_marked_for_deconstruction(event)
    -- Check player and entity are valid
    local entity = event.entity
    local player_index = event.player_index
    if not player_index or not entity.valid then
        return
    end

    -- If it has a last user then either do nothing or cancel decon
    local last_user = entity.last_user
    local player_cache = get_player_cache(player_index)
    if last_user then
        if player_cache.permission == "disallow" then
            entity.cancel_deconstruction(player_cache.force)
        end
        return
    end

    -- Allow fast decon on no last user and not cliff
    if player_cache.permission == "fast" and entity.type ~= "cliff" then
        local head = player_cache.tree_count + 1
        player_cache.tree_count = head
        player_cache.trees[head] = entity
    end
end

--- Clear trees when hit with a car
--- @param event EventData.on_entity_damaged
local function on_entity_damaged(event)
    -- Check it was an impact from a force
    if not (event.damage_type.name == "impact" and event.force) then
        return
    end

    -- Check the entity hit was a tree or rock
    if not (event.entity.type == "tree" or event.entity.type == "simple-entity") then
        return
    end

    -- Check the case was a car
    if (not event.cause) or (event.cause.type ~= "car") then
        return
    end

    -- Get a valid player as the driver
    local driver = event.cause.get_driver()
    if not driver then return end
    if driver.object_name ~= "LuaPlayer" then
        driver = driver.player
        if not driver then return end
    end

    -- Mark the entity to be removed
    local allow = get_player_cache(driver.index)
    if allow == "fast" and HasEnabledDecon:get(driver) then
        event.entity.destroy()
    else
        event.entity.order_deconstruction(event.force, driver)
    end
end

local e = defines.events

return {
    events = {
        [e.on_entity_damaged] = on_entity_damaged,
        [e.on_marked_for_deconstruction] = on_marked_for_deconstruction,
    }
}
