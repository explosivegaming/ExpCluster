--[[-- ExpGroups
Adds permission group syncing to clusterio
]]

local clusterio_api = require("modules/clusterio/api")
local compat = require("modules/clusterio/compat")

--- Top level module table, contains event handlers and public methods
--- @class ExpGroups
local ExpGroups = {}

--- @class ExpPermissionGroups.GroupPermissions
--- @field is_blacklist boolean
--- @field permissions string[]

--- @class ExpPermissionGroups.GroupRecord
--- @field id number
--- @field name string
--- @field permissions ExpPermissionGroups.GroupPermissions?
--- @field is_deleted boolean

--- @class ExpPermissionGroups.AssignmentRecord
--- @field name string
--- @field groupId number
--- @field isDeleted boolean

--- @class ExpPermissionGroups.ScriptData
--- @field factorio_to_clusterio_id table<number, number?>
--- @field clusterio_id_to_group table<number, LuaPermissionGroup?>
--- @field dirty_groups table<number, LuaPermissionGroup>
--- @field dirty_players table<string, LuaPlayer>
--- @field emit_updates boolean
local script_data = {}

local function setup_script_data()
    if compat.script_data["exp_groups"] == nil then
        --- @type ExpPermissionGroups.ScriptData
        compat.script_data["exp_groups"] = {
            factorio_to_clusterio_id = {},
            clusterio_id_to_group = {},
            dirty_groups = {},
            dirty_players = {},
            emit_updates = false,
        }
    end

    ExpGroups.on_load()
end

--[[
    Helper methods
]]

--- Get the default factorio permission group
--- @return LuaPermissionGroup
local function get_default_group()
    return assert(game.permissions.get_group("Default"))
end

--- Move all players from one group to another
--- @param group_src LuaPermissionGroup
--- @param group_dst LuaPermissionGroup
local function move_players(group_src, group_dst)
    local add_player = group_dst.add_player
    for _, player in pairs(group_src.players) do
        add_player(player)
    end
end

--- Apply an encoded permission definition to a group
--- @param group LuaPermissionGroup
--- @param permissions ExpPermissionGroups.GroupPermissions
local function decode_group_permissions(group, permissions)
    -- Construct a hash map for faster lookup
    local action_map = {}
    for _, input_action_name in pairs(permissions.permissions) do
        action_map[input_action_name] = true
    end

    -- Apply the whitelist / backlist to the group
    local is_blacklist = permissions.is_blacklist
    local action_allowed = not is_blacklist
    for input_action_name, input_action in pairs(defines.input_action) do
        if action_map[input_action_name] then
            group.set_allows_action(input_action, action_allowed)
        else
            group.set_allows_action(input_action, is_blacklist)
        end
    end
end

--- Encode the permissions of a group in a shorthand format
--- @param group LuaPermissionGroup
--- @return ExpPermissionGroups.GroupPermissions
local function encode_group_permissions(group)
    local whitelist = {} --- @type string[]
    local blacklist = {} --- @type string[]
    local whitelist_index = 0
    local blacklist_index = 0

    -- Construct the whitelist and blacklist
    local allows_action = group.allows_action
    for input_action_name, input_action in pairs(defines.input_action) do
        if allows_action(input_action) then
            whitelist[whitelist_index] = input_action_name
            whitelist_index = whitelist_index + 1
        else
            blacklist[blacklist_index] = input_action_name
            blacklist_index = blacklist_index + 1
        end
    end

    -- Return the whitelist if it is smaller
    if blacklist_index > whitelist_index then
        return { is_blacklist = false, permissions = whitelist }
    end

    -- Otherwise return the blacklist as it is smaller
    return { is_blacklist = true, permissions = blacklist }
end

--[[
    State handlers
]]

--- Update the factorio permission group
--- @param group_record ExpPermissionGroups.GroupRecord
local function update_group(group_record)
    assert(not group_record.is_deleted)

    -- Try find the group by id and then then name
    local group = script_data.clusterio_id_to_group[group_record.id]
    if not group then
        group = game.permissions.get_group(group_record.name)
    end

    -- Create a new group or update the found group
    if not group or not group.valid then
        group = assert(game.permissions.create_group(group_record.name))
    else
        group.name = group_record.name
    end

    -- Update the permissions for the group
    if group_record.permissions then
        decode_group_permissions(group, group_record.permissions)
    end

    -- Update the script data
    script_data.factorio_to_clusterio_id[group.group_id] = group_record.id
    script_data.clusterio_id_to_group[group_record.id] = group
end

--- Delete the factorio permission group
--- @param group_record ExpPermissionGroups.GroupRecord
local function delete_group(group_record)
    assert(group_record.is_deleted)

    local default_group = get_default_group()
    local group = script_data.clusterio_id_to_group[group_record.id]
    if group then
        move_players(group, default_group)
        group.destroy()
    end
end

--- Update an assignment by moving the player to their new group
--- @param assignment_record ExpPermissionGroups.AssignmentRecord
local function update_assignment(assignment_record)
    assert(not assignment_record.isDeleted)

    local group = script_data.clusterio_id_to_group[assignment_record.groupId]
    local player = assert(game.get_player(assignment_record.name))
    if group then
        group.add_player(player)
    end
end

--- Clear an assignment by moving the player to the default group
--- @param assignment_record ExpPermissionGroups.AssignmentRecord
local function delete_assignment(assignment_record)
    assert(assignment_record.isDeleted)

    local default_group = get_default_group()
    local player = assert(game.get_player(assignment_record.name))
    default_group.add_player(player)
end

--[[
    Public methods
]]

--- Restore local references to persistent script data after load
function ExpGroups.on_load()
    script_data = compat.script_data["exp_groups"]
end

--- Enable or disable emitting lua changes back to the instance plugin
--- @param enabled boolean?
function ExpGroups.set_emit_events(enabled)
    script_data.emit_updates = enabled ~= false
end

--- Replace local state with expected controller state on startup
--- @param group_records ExpPermissionGroups.GroupRecord[]
function ExpGroups.initialise_groups(group_records)
    local _emit_events = script_data.emit_updates
    script_data.emit_updates = false

    -- Update all the received groups
    local seen_clusterio_ids = {} --- @type table<number, boolean>
    for _, group_record in pairs(group_records) do
        update_group(group_record)
        seen_clusterio_ids[group_record.id] = true
    end

    -- Cleanup the script data, removing stale group ids
    local factorio_to_clusterio_id = script_data.factorio_to_clusterio_id
    local clusterio_id_to_group = script_data.clusterio_id_to_group
    for factorio_id, clusterio_id in pairs(factorio_to_clusterio_id) do
        if not seen_clusterio_ids[clusterio_id] then
            factorio_to_clusterio_id[factorio_id] = nil
            clusterio_id_to_group[clusterio_id] = nil
        end
    end

    -- Remove all other groups
    local default_group = get_default_group()
    local default_group_id = default_group.group_id
    for _, group in pairs(game.permissions.groups) do
        if not factorio_to_clusterio_id[group.group_id] and group.group_id ~= default_group_id then
            move_players(group, default_group)
            group.destroy()
        end
    end

    script_data.emit_updates = _emit_events
end

--- Receive an updated version of a group record
--- @param group_record ExpPermissionGroups.GroupRecord
function ExpGroups.receive_group_update(group_record)
    local _emit_events = script_data.emit_updates
    script_data.emit_updates = false

    if group_record.is_deleted then
        delete_group(group_record)
    else
        update_group(group_record)
    end

    script_data.emit_updates = _emit_events
end

--- Receive an updated version of a assignment record
--- @param assignment_record ExpPermissionGroups.AssignmentRecord
function ExpGroups.receive_assignment_update(assignment_record)
    local _emit_events = script_data.emit_updates
    script_data.emit_updates = false

    if assignment_record.isDeleted then
        delete_assignment(assignment_record)
    else
        update_assignment(assignment_record)
    end

    script_data.emit_updates = _emit_events
end

--- Get the current script data for debugging purposes
--- @package
function ExpGroups._script_data()
    return script_data
end

--[[
    IPC events
]]

--- Emit a group update to the instance plugin
--- @param group LuaPermissionGroup
local function emit_group_update(group)
    clusterio_api.send_json("exp_group:group_updated", {
        group_name = group.name,
        group_id = script_data.factorio_to_clusterio_id[group.group_id],
        permissions = encode_group_permissions(group),
    })
end

--- Emit a group deletion to the instance plugin
--- @param group_id number
--- @param group_name string
local function emit_group_delete(group_id, group_name)
    clusterio_api.send_json("exp_group:group_deleted", {
        group_name = group_name,
        group_id = script_data.factorio_to_clusterio_id[group_id],
    })
end

--- Emit a player assignment to the instance plugin
--- @param assignments table<string, number>
local function emit_player_assignments(assignments)
    clusterio_api.send_json("exp_group:player_assignments", {
        assignments = assignments
    })
end

--[[
    IPC event queuing
]]

--- Mark a group as changed
--- @param group LuaPermissionGroup
local function mark_group_dirty(group)
    script_data.dirty_groups[group.group_id] = group
end

--- Mark a player as changed
--- @param player LuaPlayer
local function mark_player_dirty(player)
    script_data.dirty_players[player.name] = player
end

--- Flush queued group updates to the instance plugin
local function flush_group_updates()
    -- Check if updates should be updated
    if not script_data.emit_updates then
        script_data.dirty_groups = {}
        return
    end

    -- Get all the groups and emit their updates
    for _, group in pairs(script_data.dirty_groups) do
        if group.valid then
            emit_group_update(group)
        end
    end

    script_data.dirty_groups = {}
end

--- Flush queued player updates to the instance plugin
local function flush_player_updates()
    -- Check if updates should be updated
    if not script_data.emit_updates then
        script_data.dirty_players = {}
        return
    end

    -- Construct the update payload
    local assignments = {} --- @type table<string, number>
    for player_name, player in pairs(script_data.dirty_players) do
        local group = player.valid and player.permission_group
        if group then
            assignments[player_name] = script_data.factorio_to_clusterio_id[group.group_id]
        end
    end

    emit_player_assignments(assignments)

    script_data.dirty_players = {}
end

--[[
    Factorio events
]]

--- Handle clusterio server startup
local function on_server_startup()
    setup_script_data()
end

--- Handle creation of permission groups
--- @param event EventData.on_permission_group_added
local function on_permission_group_added(event)
    -- Check if updates should be updated
    if not script_data.emit_updates then
        return
    end

    emit_group_update(event.group)
end

--- Handle deletion of permission groups
--- @param event EventData.on_permission_group_deleted
local function on_permission_group_deleted(event)
    -- Check if updates should be updated
    if not script_data.emit_updates then
        return
    end

    emit_group_delete(event.id, event.group_name)
end

--- Handle edits make to permission groups
--- @param event EventData.on_permission_group_edited
local function on_permission_group_edited(event)
    -- Check if updates should be updated
    if not script_data.emit_updates then
        return
    end

    -- Check if this is a player or group event
    if event.type == "add-player" or event.type == "remove-player" then
        local player = assert(game.get_player(event.other_player_index))
        mark_player_dirty(player)
    else
        mark_group_dirty(event.group)
    end
end

--- Periodically flush queued changes
local function on_nth_tick_flush()
    flush_group_updates()
    flush_player_updates()
end

local e = defines.events

local events = {
    [clusterio_api.events.on_server_startup] = on_server_startup,
    [e.on_permission_group_added] = on_permission_group_added,
    [e.on_permission_group_deleted] = on_permission_group_deleted,
    [e.on_permission_group_edited] = on_permission_group_edited,
}

local on_nth_tick = {
    [300] = on_nth_tick_flush,
}

ExpGroups.events = events --- @package
ExpGroups.on_nth_tick = on_nth_tick --- @package
return ExpGroups
