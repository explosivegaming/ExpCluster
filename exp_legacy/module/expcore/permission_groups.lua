--[[-- Core Module - Permission Groups
- Permission group making for factorio so you never have to make one by hand again
@core Groups
@alias Permissions_Groups

@usage--- Example Group (Allow All)
-- here we will create an admin group however we do not want them to use the map editor or mess with the permission groups
Permission_Groups.new_group('Admin') -- this defines a new group called "Admin"
:allow_all() -- this makes the default to allow any input action unless set other wise
:disallow{ -- here we disallow the input action we don't want them to use
    'add_permission_group',
    'delete_permission_group',
    'import_permissions_string',
    'map_editor_action',
    'toggle_map_editor'
}

@usage--- Example Group (Disallow All)
-- here we will create a group that cant do anything but talk in chat
Permission_Groups.new_group('Restricted') -- this defines a new group called "Restricted"
:disallow_all() -- this makes the default to disallow any input action unless set other wise
:allow('write_to_console') -- here we allow them to chat, {} can be used here if we had more than one action

]]

local Event = require("modules/exp_legacy/utils/event")
local Async = require("modules/exp_util/async")

local PermissionsGroups = {
    groups = {}, -- store for the different groups that are created
    _prototype = {}, -- stores functions that are used on group instances
}

-- Async function to add players to permission groups
local add_to_permission_group_async =
    Async.register(function(permission_group, player)
        permission_group.add_player(player)
    end)
PermissionsGroups.add_to_permission_group_async = add_to_permission_group_async

-- Async function to remove players from permission groups
local remove_from_permission_group_async =
    Async.register(function(permission_group, player)
        permission_group.remove_player(player)
    end)
PermissionsGroups.remove_from_permission_group_async = remove_from_permission_group_async

--- Getters.
-- Functions that get permission groups
-- @section getters

--[[-- Defines a new permission group that can have it actions set in the config
@tparam string name the name of the new group
@treturn Permissions_Groups._prototype the new group made with function to allow and disallow actions

@usage-- Defining a new permission group
Groups.new_group('Admin')

]]
function PermissionsGroups.new_group(name)
    local group = setmetatable({
        name = name,
        actions = {},
        allow_all_actions = true,
    }, {
        __index = PermissionsGroups._prototype,
    })
    PermissionsGroups.groups[name] = group
    return group
end

--[[-- Returns the group with the given name, case sensitive
@tparam string name the name of the group to get
@treturn ?Permissions_Groups._prototype|nil the group with that name or nil if non found

@usage-- Getting a permision group
local admin_group = Groups.get_group_by_name('Admin')

]]
function PermissionsGroups.get_group_by_name(name)
    return PermissionsGroups.groups[name]
end

--[[-- Returns the group that a player is in
@tparam LuaPlayer player the player to get the group of can be name index etc
@treturn ?Permissions_Groups._prototype|nil the group with that player or nil if non found

@usage-- Get your permission group
local group = Groups.get_group_from_player(game.player)

]]
function PermissionsGroups.get_group_from_player(player)
    local group = player.permission_group
    if group then
        return PermissionsGroups.groups[group.name]
    end
end

--- Setters.
-- Functions that control all groups
-- @section players

--[[-- Reloads/creates all permission groups and sets them to they configured state

@usage-- Reload the permission groups, used internally
Groups.reload_permissions()

]]
function PermissionsGroups.reload_permissions()
    for _, group in pairs(PermissionsGroups.groups) do
        group:create()
    end
end

--[[-- Sets a player's group to the one given, a player can only have one group at a time
@tparam LuaPlayer player the player to effect can be name index etc
@tparam string group the name of the group to give to the player
@treturn boolean true if the player was added successfully, false other wise

@usage-- Set your permission group
Groups.set_player_group(game.player, 'Admin')

]]
function PermissionsGroups.set_player_group(player, group)
    group = PermissionsGroups.get_group_by_name(group)
    if not group or not player then return false end
    group:add_player(player)
    return true
end

--- Actions.
-- Functions that control group actions
-- @section actions

--[[-- Sets the allow state of an action for this group, used internally but is safe to use else where
@tparam ?string|defines.input_action action the action that you want to set the state of
@tparam boolean state the state that you want to set it to, true = allow, false = disallow
@treturn Permissions_Groups._prototype returns self so function can be chained

@usage-- Set an action to be disallowed
group:set_action('toggle_map_editor', false)

]]
function PermissionsGroups._prototype:set_action(action, state)
    local input_action = defines.input_action[action] --[[ @as defines.input_action? ]]
    if input_action == nil then input_action = action end
    assert(type(input_action) == "number", tostring(action) .. " is not a valid input action")
    self.actions[input_action] = state
    return self
end

--[[-- Sets an action or actions to be allowed for this group even with disallow_all triggered, Do not use in runtime
@tparam string|Array<string> actions the action or actions that you want to allow for this group
@treturn Permissions_Groups._prototype returns self so function can be chained

@usage-- Allow some actions
group:allow{
    'write_to_console'
}

]]
function PermissionsGroups._prototype:allow(actions)
    if type(actions) ~= "table" then
        actions = { actions }
    end
    for _, action in pairs(actions) do
        self:set_action(action, true)
    end

    return self
end

--[[-- Sets an action or actions to be disallowed for this group even with allow_all triggered, Do not use in runtime
@tparam string|Array<string> actions the action or actions that you want to disallow for this group
@treturn Permissions_Groups._prototype returns self so function can be chained

@usage-- Disalow some actions
group:disallow{
    'add_permission_group',
    'delete_permission_group',
    'import_permissions_string',
    'map_editor_action',
    'toggle_map_editor'
}

]]
function PermissionsGroups._prototype:disallow(actions)
    if type(actions) ~= "table" then
        actions = { actions }
    end
    for _, action in pairs(actions) do
        self:set_action(action, false)
    end

    return self
end

--[[-- Sets the default state for any actions not given to be allowed, useful with :disallow
@treturn Permissions_Groups._prototype returns self so function can be chained

@usage-- Allow all actions unless given by disallow
group:allow_all()

]]
function PermissionsGroups._prototype:allow_all()
    self.allow_all_actions = true
    return self
end

--[[-- Sets the default state for any action not given to be disallowed, useful with :allow
@treturn Permissions_Groups._prototype returns self so function can be chained

@usage-- Disallow all actions unless given by allow
group:disallow_all()

]]
function PermissionsGroups._prototype:disallow_all()
    self.allow_all_actions = false
    return self
end

--[[-- Returns if an input action is allowed for this group
@tparam ?string|defines.input_action action the action that you want to test for
@treturn boolean true if the group is allowed the action, false other wise

@usage-- Test if a group is allowed an action
local allowed = group:is_allowed('write_to_console')

]]
function PermissionsGroups._prototype:is_allowed(action)
    if type(action) == "string" then
        action = defines.input_action[action]
    end
    local state = self.actions[action]
    if state == nil then
        state = self.allow_all_actions
    end
    return state
end

--- Players.
-- Functions that control group players
-- @section players

--[[-- Creates or updates the permission group with the configured actions, used internally
@treturn LuaPermissionGroup the permission group that was created

@usage-- Create the permission group so players can be added, used internally
group:create()

]]
function PermissionsGroups._prototype:create()
    local group = self:get_raw()
    if not group then
        group = game.permissions.create_group(self.name) --[[@as LuaPermissionGroup]]
    end
    for _, action in pairs(defines.input_action) do
        group.set_allows_action(action, self:is_allowed(action))
    end

    return group
end

--[[-- Returns the LuaPermissionGroup that was created with this group object, used internally
@treturn LuaPermissionGroup the raw lua permission group

@usage-- Get the factorio api permision group, used internally
local permission_group = group:get_raw()

]]
function PermissionsGroups._prototype:get_raw()
    return game.permissions.get_group(self.name)
end

--[[-- Adds a player to this group
@tparam LuaPlayer player LuaPlayer the player you want to add to this group can be name or index etc
@treturn boolean true if the player was added successfully, false other wise

@usage-- Add a player to this permission group
group:add_player(game.player)

]]
function PermissionsGroups._prototype:add_player(player)
    local group = self:get_raw()
    if not group or not player then return false end
    add_to_permission_group_async(group, player)
    return true
end

--[[-- Removes a player from this group
@tparam LuaPlayer player LuaPlayer the player you want to remove from this group can be name or index etc
@treturn boolean true if the player was removed successfully, false other wise

@usage-- Remove a player from this permission group
group:remove_player(game.player)

]]
function PermissionsGroups._prototype:remove_player(player)
    local group = self:get_raw()
    if not group or not player then return false end
    remove_from_permission_group_async(group, player)
    return true
end

--[[-- Returns all player that are in this group with the option to filter to online/offline only
@tparam[opt] boolean online if nil returns all players, if true online players only, if false returns online players only
@treturn table a table of players that are in this group; filtered if online param is given

@usage-- Get all players in this group
local online_players = group:get_players()

@usage-- Get all online players in this group
local online_players = group:get_players(true)

]]
function PermissionsGroups._prototype:get_players(online)
    local players = {}
    local group = self:get_raw()
    if group then
        if online == nil then
            return group.players
        else
            for _, player in pairs(group.players) do
                if player.connected == online then
                    table.insert(player, player)
                end
            end
        end
    end
    return players
end

--[[-- Prints a message to every player in this group
@tparam string message the message that you want to send to the players
@treturn number the number of players that received the message

@usage-- Print a message to all players in thie group
group:print('Hello, World!')

]]
function PermissionsGroups._prototype:print(message)
    local players = self:get_players(true)
    for _, player in pairs(players) do
        player.print(message)
    end

    return #players
end

-- when the game starts it will make the permission groups
Event.on_init(function()
    PermissionsGroups.reload_permissions()
end)

return PermissionsGroups
