local Async = require("modules/exp_util/async")

local table_to_json = helpers.table_to_json
local json_to_table = helpers.json_to_table

--- Top level module table, contains event handlers and public methods
local Groups = {}

--- @class ExpGroup
--- @field group LuaPermissionGroup The permission group for this group proxy
Groups._prototype = {}

Groups._metatable = {
    __index = setmetatable(Groups._prototype, {
        __index = function(self, key)
            return self.group[key]
        end,
    }),
    __class = "ExpGroup",
}

local action_to_name = {}
for name, action in pairs(defines.input_action) do
    action_to_name[action] = name
end

--- Async Functions
-- These are required to allow bypassing edit_permission_group

--- Add a player to a permission group, requires edit_permission_group
--- @param player LuaPlayer Player to add to the group
--- @param group LuaPermissionGroup Group to add the player to
local function add_player_to_group(player, group)
    return group.add_player(player)
end

--- Add a players to a permission group, requires edit_permission_group
--- @param players LuaPlayer[] Players to add to the group
--- @param group LuaPermissionGroup Group to add the players to
local function add_players_to_group(players, group)
    local add_player = group.add_player
    if not add_player(players[1]) then
        return false
    end
    for i = 2, #players do
        add_player(players[i])
    end

    return true
end

-- Async will bypass edit_permission_group but takes at least one tick
local add_player_to_group_async = Async.register(add_player_to_group)
local add_players_to_group_async = Async.register(add_players_to_group)

--- Static methods for gettings, creating and removing permission groups

--- Gets the permission group proxy with the given name or group ID.
--- @param group_name string|uint32 The name or id of the permission group
function Groups.get_group(group_name)
    local group = game.permissions.get_group(group_name)
    if group == nil then return nil end
    return setmetatable({
        group = group,
    }, Groups._metatable)
end

--- Gets the permission group proxy for a players group
--- @param player LuaPlayer The player to get the group of
function Groups.get_player_group(player)
    local group = player.permission_group
    if group == nil then return nil end
    return setmetatable({
        group = group,
    }, Groups._metatable)
end

--- Creates a new permission group, requires add_permission_group
--- @param group_name string Name of the group to create
function Groups.new_group(group_name)
    local group = game.permissions.get_group(group_name)
    assert(group == nil, "Group already exists with name: " .. group_name)
    group = game.permissions.create_group(group_name)
    assert(group ~= nil, "Requires permission add_permission_group")
    return setmetatable({
        group = group,
    }, Groups._metatable)
end

--- Get or create a permisison group, must use the group name not the group id
--- @param group_name string Name of the group to create
function Groups.get_or_create(group_name)
    local group = game.permissions.get_group(group_name)
    if group then
        return setmetatable({
            group = group,
        }, Groups._metatable)
    else
        group = game.permissions.create_group(group_name)
        assert(group ~= nil, "Requires permission add_permission_group")
        return setmetatable({
            group = group,
        }, Groups._metatable)
    end
end

--- Destory a permission group, moves all players to default group
--- @param group_name  string|uint32 The name or id of the permission group to destroy
--- @param move_to_name  string|uint32? The name or id of the permission group to move players to
function Groups.destroy_group(group_name, move_to_name)
    local group = game.permissions.get_group(group_name)
    if group == nil then return nil end

    local players = group.players
    if #players > 0 then
        local move_to = game.permissions.get_group(move_to_name or "Default")
        for _, player in ipairs(players) do
            player.permission_group = move_to
        end
    end

    local success = group.destroy()
    assert(success, "Requires permission delete_permission_group")
end

--- Prototype methods for modifying and working with permission groups

--- Add a player to the permission group
--- @param player LuaPlayer The player to add to the group
function Groups._prototype:add_player(player)
    return add_player_to_group(player, self.group) or add_player_to_group_async(player, self.group)
end

--- Add players to the permission group
--- @param players LuaPlayer[] The player to add to the group
function Groups._prototype:add_players(players)
    return add_players_to_group(players, self.group) or add_players_to_group_async(players, self.group)
end

--- Move all players to another group
--- @param other_group ExpGroup The group to move players to, default is the Default group
function Groups._prototype:move_players(other_group)
    return add_players_to_group(self.group.players, other_group.group) or add_players_to_group_async(self.group.players, other_group.group)
end

--- Allow a set of actions for this group
--- @param actions defines.input_action[] Actions to allow
function Groups._prototype:allow_actions(actions)
    local set_allow = self.group.set_allows_action
    for _, action in ipairs(actions) do
        set_allow(action, true)
    end

    return self
end

--- Disallow a set of actions for this group
--- @param actions defines.input_action[] Actions to disallow
function Groups._prototype:disallow_actions(actions)
    local set_allow = self.group.set_allows_action
    for _, action in ipairs(actions) do
        set_allow(action, false)
    end

    return self
end

--- Reset the allowed state of all actions
--- @param allowed boolean? default true for allow all actions, false to disallow all actions
function Groups._prototype:reset(allowed)
    local set_allow = self.group.set_allows_action
    if allowed == nil then allowed = true end
    for _, action in pairs(defines.input_action) do
        set_allow(action, allowed)
    end

    return self
end

--- Returns if the group is allowed a given action
--- @param action string|defines.input_action Actions to test
function Groups._prototype:allows(action)
    if type(action) == "string" then
        return self.group.allows_action(defines.input_action[action])
    end
    return self.group.allows_action(action)
end

--- Print a message to all players in the group
function Groups._prototype:print(...)
    for _, player in ipairs(self.group.players) do
        player.print(...)
    end
end

--- Static and Prototype methods for use with IPC

--- Convert an array of strings into an array of action names
--- @param actions_names string[] An array of action names
local function names_to_actions(actions_names)
    local actions, invalid, invalid_i = {}, {}, 1
    for i, action_name in ipairs(actions_names) do
        local action = defines.input_action[action_name]
        if action then
            actions[i] = action
        else
            invalid[invalid_i] = i
            invalid_i = invalid_i + 1
        end
    end

    local last = #actions
    for _, i in ipairs(invalid) do
        actions[i] = actions[last]
        last = last - 1
    end

    return actions
end

--- Get the action names from the action numbers
function Groups.actions_to_names(actions)
    local names = {}
    for i, action in ipairs(actions) do
        names[i] = action_to_name[action]
    end

    return names
end

--- Get all input actions that are defined
function Groups.get_actions_json()
    local rtn, rtn_i = {}, 1
    for name in pairs(defines.input_action) do
        rtn[rtn_i] = name
        rtn_i = rtn_i + 1
    end

    return table_to_json(rtn)
end

--- Convert a json string array into an array of input actions
--- @param json string A json string representing a string array of actions
function Groups.json_to_actions(json)
    local tbl = json_to_table(json)
    assert(tbl, "Invalid Json String")
    --- @cast tbl string[]
    return names_to_actions(tbl)
end

--- Returns the shortest defination of the allowed actions
-- The first value of the return can be passed to :reset
function Groups._prototype:to_json(raw)
    local allow, disallow = {}, {}
    local allow_i, disallow_i = 1, 1
    local allows = self.group.allows_action
    for name, action in pairs(defines.input_action) do
        if allows(action) then
            allow[allow_i] = name
            allow_i = allow_i + 1
        else
            disallow[disallow_i] = name
            disallow_i = disallow_i + 1
        end
    end

    if allow_i >= disallow_i then
        return raw and { true, disallow } or table_to_json{ true, disallow }
    end
    return raw and { false, allow } or table_to_json{ false, allow }
end

--- Restores this group to the state given in a json string
--- @param json string The json string to restore from
function Groups._prototype:from_json(json)
    local tbl = json_to_table(json)
    assert(tbl and type(tbl[1]) == "boolean" and type(tbl[2]) == "table", "Invalid Json String")

    if tbl[1] then
        return self:reset(true):disallow_actions(names_to_actions(tbl[2]))
    end
    return self:reset(false):allow_actions(names_to_actions(tbl[2]))
end

return Groups
