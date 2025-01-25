--[[-- Core Module - Roles
- Factorio role system to manage custom permissions.
@core Roles
@alias Roles

@usage--- Using Role System (assignment):
--When a map first starts you will want to define on mass all the players you expect to join and the roles to give them:
Roles.override_player_roles{
    Cooldude2606 = {'Owner', 'Admin', 'Member'},
    NotCooldude2606 = {'Member'}
}

--Once the game is running you still want to be able to give role and remove them which is when you would use:
Roles.assign_player(player, 'Admin', by_player_name) -- this will give the "Admin" role to the player
Roles.unassign_player(player, {'Admin', 'Moderator'}, by_player_name) -- this will remove "Admin" and "Moderator" role in one go

@usage--- Using Role System (role testing):
--To comparer two players you can comparer the index of they highest roles, can be used when you want to allow a "write" down type system:
Roles.get_player_highest_role(playerOne).index < Roles.get_player_highest_role(playerTwo).index -- remember that less means a higher role

--Listing all of a players roles can also be useful which is when you would want to use:
Roles.get_player_roles(player) -- the return is an array that can be looped over however this is not in particular order

--Finally you may want to test if a player has a certain role, flag or action allowed which is when you would use:
Roles.player_has_role(player, 'Admin') -- you can provide a role name if you only want a name based system
Roles.player_has_flag(player, 'is_donator') -- your roles can be grouped together with flags such as is_donator
Roles.player_allowed(player, 'game modifiers') -- or you can have an action based system where each action is something the player can do

@usage--- Example Flag Define:
--Flags can be used to group multiple roles and actions under one catch all, for example if you want a piece of code to only
--be active for your donators then you would add a "is_donator" flag to all your donator roles and then in the code test if
--a player has that tag present:

-- give you donators a speed boost when they join; these functions aren't required but can be useful
Roles.define_flag_trigger('is_donator', function(player, state)
    if state then
        player.character_running_speed_modifier = 1.5
    else
        player.character_running_speed_modifier = 1
    end
end)

-- then on all your donator roles you would add
Roles.new_role('Donator')
:set_flag('is_donator')

-- and in your code you would test for
if Roles.player_has_flag(player, 'is_donator') then
    -- some donator only code
end

@usage--- Example Role Define:
--You can't use a role system without any roles so first you must define your roles; each role has a minimum of a name with
--the option for a shorthand:
Roles.new_role('Administrator', 'Admin')

--Next you will want to add any extras you want to have, such as a tag, colour, permission group or any custom flags:
Roles.new_role('Administrator', 'Admin')
:set_custom_tag('[Admin]')
:set_custom_color('red') -- this can be {r=0, g=0, b=0} or a predefined value
:set_permission_group('Staff') -- a second argument can be added if you have not used the custom permission group config
:set_flag('is_admin')

--You will then want to decide if you want to allow all actions, this should of course be used sparely:
Roles.new_role('Administrator', 'Admin')
...extras...
:set_allow_all()

--If you don't do this want this as i would advise you do then you will want to define what the role can do; this comes with
--an optional inheritance system if you like those sort of things in which case disallow may also be of some use to you:
Roles.new_role('Administrator', 'Admin')
...extras...
:set_parent('Moderator') -- the admin can do anything that a moderator can do
:allow{ -- these actions can be anything just try to keep them without conflicts
    'command/kill',
    'gui/game settings'
}

--Here is what the finished admin role would look like:
Roles.new_role('Administrator', 'Admin')
:set_custom_tag('[Admin]')
:set_custom_color('red')
:set_permission_group('Staff')
:set_flag('is_admin')
:set_parent('Moderator')
:allow{
    'command/kill',
    'gui/game settings'
}

@usage--- Example System Define:
--Once all roles are defined these steps must be done to ensure the system is ready to use, this includes setting a default
--role, assigning a root (all permission) role that the server/system will use and the linear order that the roles fall into:

Roles.set_default('Guest')
Roles.set_root('System')

Roles.define_role_order{
    'System',
    'Administrator',
    'Moderator',
    'Donator',
    'Guest'
}

--Just remember that in this example all these roles have not been defined; so make sure all your roles that are used are defined
--before hand; a config file on load is useful for this to ensure that its loaded before the first player even joins.

]]

local ExpUtil = require("modules/exp_util")
local Async = require("modules/exp_util/async")
local Storage = require("modules/exp_util/storage")
local Event = require("modules/exp_legacy/utils/event")
local Groups = require("modules.exp_legacy.expcore.permission_groups")

local Colours = ExpUtil.color
local write_json = ExpUtil.write_json

local Roles = {
    _prototype = {},
    config = {
        order = {}, -- Contains the order of the roles, lower index is better
        roles = {}, -- Contains the raw info for the roles, indexed by role name
        flags = {}, -- Contains functions that run when a flag is added/removed from a player
        internal = {}, -- Contains all internally accessed roles, such as root, default
        players = {}, -- Contains the roles that players have
        auto_assign = {}, -- Contains references to all roles which have auto assign conditions
        deferred_roles = {}, -- Contains the roles that are to be assigned to players when they are unjailed
    },
    events = {
        on_role_assigned = script.generate_event_name(),
        on_role_unassigned = script.generate_event_name(),
    },
}

--- When global is loaded it will have the metatable re-assigned to the roles
Storage.register({
    Roles.config.players,
    Roles.config.deferred_roles,
}, function(tbl)
    Roles.config.players = tbl[1]
    Roles.config.deferred_roles = tbl[2]
end)

--- Getter.
-- Functions which get roles
-- @section get

--- Internal function used to trigger a few different things when roles are changed
-- this is the raw internal trigger as the other function is called at other times
-- there is a second half called role_update which triggers after the event call, it also is called when a player joins
local function emit_player_roles_updated(player, type, roles, by_player_name, skip_game_print)
    by_player_name = by_player_name or game.player and game.player.name or "<server>"
    local by_player = game.players[by_player_name]
    local by_player_index = by_player and by_player.index or 0
    -- get the event id from the type of emit
    local event = Roles.events.on_role_assigned
    if type == "unassign" then
        event = Roles.events.on_role_unassigned
    end
    -- Get the names of the roles
    local role_names = {}
    for index, role in ipairs(roles) do
        role_names[index] = role.name
    end

    -- output to all the different locations: game print, player sound, event trigger and role log
    if not skip_game_print then
        game.print({ "expcore-roles.game-message-" .. type, player.name, table.concat(role_names, ", "), by_player_name }, Colours.cyan)
    end
    if type == "assign" then
        player.play_sound{ path = "utility/achievement_unlocked" }
    else
        player.play_sound{ path = "utility/game_lost" }
    end
    script.raise_event(event, {
        name = event,
        tick = game.tick,
        player_index = player.index,
        by_player_index = by_player_index,
        roles = role_names,
    })
    write_json("log/roles.log", {
        player_name = player.name,
        by_player_name = by_player_name,
        type = type,
        roles_changed = role_names,
    })
end

--[[-- Returns a string which contains all roles in index order displaying all data for them
@treturn string the debug output string

@usage-- Print the debug string
game.player.print(Roles.debug())

]]
function Roles.debug()
    local output = ""
    for index, role_name in ipairs(Roles.config.order) do
        local role = Roles.config.roles[role_name]
        local color = role.custom_color or Colours.white
        local color_str = string.format("[color=%d, %d, %d]", color.r, color.g, color.b)
        output = output .. string.format("\n%s %s) %s[/color]", color_str, index, serpent.line(role))
    end

    return output
end

--[[-- Prints a message to all players in the given roles, may send duplicate message however factorio blocks spam
@tparam table roles table a of roles which to send the message to
@tparam string message the message to send to the players

@usage-- Print a message to the given roles
Roles.print_to_roles({'Administrator', 'Moderator'}, 'Hello, World!')

]]
function Roles.print_to_roles(roles, message)
    for _, role in ipairs(roles) do
        role = Roles.get_role_from_any(role)
        if role then role:print(message) end
    end
end

--[[-- Prints a message to all players who have the given role or one which is higher (excluding default)
@tparam string role the name of the role to send the message to
@tparam string message the message to send to the players

@usage-- Print a message to the roles above this role, includes the given role
Roles.print_to_roles_higher('Moderator', 'Hello, World!')

]]
function Roles.print_to_roles_higher(role, message)
    role = Roles.get_role_from_any(role)
    if not role then return end
    local roles = {}
    for index, role_name in ipairs(Roles.config.order) do
        if index <= role.index and role_name ~= Roles.config.internal.default then
            roles[#roles + 1] = role_name
        end
    end

    Roles.print_to_roles(roles, message)
end

--[[-- Prints a message to all players who have the given role or one which is lower (excluding default)
@tparam string role the name of the role to send the message to
@tparam string message the message to send to the players

@usage-- Print a message to the roles below this role, includes the given role
Roles.print_to_roles_higher('Moderator', 'Hello, World!')

]]
function Roles.print_to_roles_lower(role, message)
    role = Roles.get_role_from_any(role)
    if not role then return end
    local roles = {}
    for index, role_name in ipairs(Roles.config.order) do
        if index >= role.index and role_name ~= Roles.config.internal.default then
            roles[#roles + 1] = role_name
        end
    end

    Roles.print_to_roles(roles, message)
end

--[[-- Get a role for the given name
@tparam string name the name of the role to get
@treturn Roles._prototype the role with that name or nil

@usage-- Get a role by its name
local role = Roles.get_role_by_name('Moderator')

]]
function Roles.get_role_by_name(name)
    return Roles.config.roles[name]
end

--[[-- Get a role with the given order index
@tparam number index the place in the order list of the role to get
@treturn Roles._prototype the role with that index in the order list or nil

@usage-- Get a role by its index in the order list
local role = Roles.get_role_by_name(2)

]]
function Roles.get_role_by_order(index)
    local name = Roles.config.order[index]
    return Roles.config.roles[name]
end

--[[-- Gets a role from a name, index or role object (where it is just returned)
nb: this function is used for the input for most outward facing functions
@tparam ?number|string|table any the value used to find the role
@treturn Roles._prototype the role that was found or nil see above

@usage-- Get a role by its name or order
local role = Roles.get_role_from_any('Moderator')

]]
function Roles.get_role_from_any(any)
    local t_any = type(any)
    if t_any == "number" or tonumber(any) then
        any = tonumber(any)
        return Roles.get_role_by_order(any)
    elseif t_any == "string" then
        return Roles.get_role_by_name(any)
    elseif t_any == "table" then
        return Roles.get_role_by_name(any.name)
    end
end

--- Returns all roles in order of index
function Roles.get_roles_ordered()
    local rtn = {}
    for index, role_name in ipairs(Roles.config.order) do
        rtn[index] = Roles.config.roles[role_name]
    end
    return rtn
end

--[[-- Gets all the roles of the given player, this will always contain the default role
@tparam LuaPlayer player the player to get the roles of
@treturn table a table where the values are the roles which the player has

@usage-- Get the roles that a player has
local roles = Roles.get_player_roles(game.player)

]]
function Roles.get_player_roles(player)
    if not player or player.index == 0 then return { Roles.config.roles[Roles.config.internal.root] } end
    local roles = Roles.config.players[player.name] or {}
    local default = Roles.config.roles[Roles.config.internal.default]
    local rtn = { default }
    for index, role_name in ipairs(roles) do
        rtn[index + 1] = Roles.config.roles[role_name]
    end

    return rtn
end

--[[-- Gets the highest role which the player has, can be used to compeer one player to another
@tparam LuaPlayer player the player to get the highest role of
@treturn the role with the highest order index which this player has

@usage-- Get the highest role that a player has
local role = Roles.get_player_highest_role(game.player)

]]
function Roles.get_player_highest_role(player)
    local roles = Roles.get_player_roles(player)
    local highest
    for _, role in ipairs(roles) do
        if not highest or role.index < highest.index then
            highest = role
        end
    end

    return highest
end

--- Assignment.
-- Functions for changing player's roles
-- @section assignment

--[[-- Gives a player the given role(s) with an option to pass a by player name used in the log
@tparam LuaPlayer player the player that will be assigned the roles
@tparam table roles table a of roles that the player will be given, can be one role and can be role names
@tparam[opt=<server>] string by_player_name the name of the player that will be shown in the log
@tparam[opt=false] boolean skip_checks when true there will be no checks are done for if the player is valid
@tparam[opt=false] boolean silent when true there will be no game message printed

@usage-- Assign a player to the Moderator role
Roles.assign_player(game.player,  'Moderator')

@usage-- Assign a player to the Moderator role, even if the player has never been on the map
Roles.assign_player('Cooldude2606',  'Moderator', nil, true)

]]
function Roles.assign_player(player, roles, by_player_name, skip_checks, silent)
    local valid_player = type(player) == "userdata" and player or game.get_player(player)
    if not skip_checks and not valid_player then return end

    -- Convert the roles into a table (allows for optional array)
    if type(roles) ~= "table" or roles.name then
        roles = { roles }
    end

    -- Convert to role objects
    local role_objects = {}
    for _, role in ipairs(roles) do
        local role_object = Roles.get_role_from_any(role)
        if role_object then table.insert(role_objects, role_object) end
    end

    -- If the player has a role that needs to defer the role changes, save the roles that need to be assigned later into a table
    if valid_player and Roles.player_has_flag(valid_player, "defer_role_changes") then
        local assign_later = Roles.config.deferred_roles[valid_player.name] or {}
        for _, role in ipairs(role_objects) do
            local role_change = assign_later[role.name]
            if role_change then
                role_change.count = role_change.count + 1
                if role_change.count == 1 then
                    role_change.by_player_name = by_player_name or "<server>"
                    role_change.silent = silent
                end
            else
                assign_later[role.name] = {
                    count = 1, by_player_name = by_player_name or "<server>", silent = silent,
                }
            end
        end

        Roles.config.deferred_roles[valid_player.name] = assign_later
        return
    end

    for _, role in ipairs(role_objects) do
        role:add_player(valid_player or player, valid_player == nil, true)
    end

    if valid_player then
        emit_player_roles_updated(valid_player, "assign", role_objects, by_player_name, silent)
    end
end

--[[-- Removes a player from the given role(s) with an option to pass a by player name used in the log
@tparam LuaPlayer player the player that will have the roles removed
@tparam table roles table a of roles to be removed from the player, can be one role and can be role names
@tparam[opt=<server>] string by_player_name the name of the player that will be shown in the logs
@tparam[opt=false] boolean skip_checks when true there will be no checks are done for if the player is valid
@tparam[opt=false] boolean silent when true there will be no game message printed

@usage-- Unassign a player from the Moderator role
Roles.unassign_player(game.player,  'Moderator')

@usage-- Unassign a player from the Moderator role, even if the player has never been on the map
Roles.unassign_player('Cooldude2606',  'Moderator', nil, true)

]]
function Roles.unassign_player(player, roles, by_player_name, skip_checks, silent)
    local valid_player = type(player) == "userdata" and player or game.get_player(player)
    if not skip_checks and not valid_player then return end
    if not player then return end

    -- Convert the roles into a table (allows for optional array)
    if type(roles) ~= "table" or roles.name then
        roles = { roles }
    end

    -- Convert to role objects
    local role_objects = {}
    for _, role in ipairs(roles) do
        local role_object = Roles.get_role_from_any(role)
        if role_object then table.insert(role_objects, role_object) end
    end

    -- If the player has a role that needs to defer the role changes, save the roles that need to be unassigned later into a table
    local defer_changes = Roles.player_has_flag(player, "defer_role_changes")
    if defer_changes then
        local assign_later = Roles.config.deferred_roles[valid_player.name] or {}
        for _, role in ipairs(role_objects) do
            local role_change = assign_later[role.name]
            if role_change then
                role_change.count = role_change.count - 1
                if role_change.count == -1 then
                    role_change.by_player_name = by_player_name or "<server>"
                    role_change.silent = silent
                end
            else
                assign_later[role.name] = {
                    count = -1, by_player_name = by_player_name or "<server>", silent = silent,
                }
            end
        end

        Roles.config.deferred_roles[valid_player.name] = assign_later
    end

    -- Remove the player from roles
    local role_changes = {}
    for _, role in ipairs(role_objects) do
        if not defer_changes or role:has_flag("defer_role_changes") then
            role:remove_player(valid_player or player, valid_player == nil, true)
            table.insert(role_changes, role)
        end
    end

    -- If there are deferred role changes, apply them now
    if defer_changes and not Roles.player_has_flag(valid_player, "defer_role_changes") then
        local assign_later = Roles.config.deferred_roles[player.name] or {}
        local assigns, unassigns = {}, {}
        for role_name, details in pairs(assign_later) do
            local role = Roles.get_role_from_any(role_name)
            if role then
                if details.count > 0 then
                    role:add_player(valid_player or player, valid_player == nil, true)
                    if not assigns[details.by_player_name] then assigns[details.by_player_name] = {} end
                    if not details.silent then table.insert(assigns[details.by_player_name], role) end
                elseif details.count < 0 then
                    role:remove_player(valid_player or player, valid_player == nil, true)
                    if not unassigns[details.by_player_name] then unassigns[details.by_player_name] = {} end
                    if not details.silent then table.insert(unassigns[details.by_player_name], role) end
                end
            end
        end

        for assign_by_player_name, assign_roles in pairs(assigns) do
            if #assign_roles > 0 then emit_player_roles_updated(valid_player, "assign", assign_roles, assign_by_player_name) end
        end

        for unassign_by_player_name, unassign_roles in pairs(unassigns) do
            if #unassign_roles > 0 then emit_player_roles_updated(valid_player, "unassign", unassign_roles, unassign_by_player_name) end
        end

        Roles.config.deferred_roles[player.name] = nil
    end

    if valid_player and #role_changes > 0 then
        emit_player_roles_updated(valid_player, "unassign", role_changes, by_player_name, silent)
    end
end

--[[-- Overrides all player roles with the given table of roles, useful to mass set roles on game start
@tparam[opt] string player_name the player to set the roles for, if not given all roles are overriden
@tparam table roles table a which is indexed by case sensitive player names and has the value of a table of role names

@usage-- Override the roles of a single player, other users are not effected
Roles.override_player_roles('Cooldude2606', {'Moderator'})

@usage-- Override all existing roles, effects all users not just ones listed
Roles.override_player_roles{
    ['Cooldude2606'] = {'Administrator', 'Moderator'},
    ['arty714'] = {'Administrator', 'Moderator'},
}

]]
function Roles.override_player_roles(player_name, roles)
    local player_roles = Roles.config.players
    if not roles then
        for k in pairs(player_roles) do player_roles[k] = nil end

        for k, new_roles in pairs(player_name) do player_roles[k] = new_roles end
    else
        Roles.config.players[player_name] = roles
    end
end

--- Checks.
-- Functions for checking player's roles
-- @section checks

--[[-- A test for weather a player has the given role
@tparam LuaPlayer player the player to test the roles of
@tparam ?string|number|table search_role a pointer to the role that is being searched for
@treturn boolean true if the player has the role, false otherwise, nil for errors

@usage-- Test if a player has a role
local has_role = Roles.player_has_role(game.player, 'Moderator')

]]
function Roles.player_has_role(player, search_role)
    local roles = Roles.get_player_roles(player)
    if not roles then return end
    search_role = Roles.get_role_from_any(search_role)
    if not search_role then return end
    for _, role in ipairs(roles) do
        if role.name == search_role.name then return true end
    end

    return false
end

--[[-- A test for weather a player has the given flag true for at least one of they roles
@tparam LuaPlayer player the player to test the roles of
@tparam string flag_name the name of the flag that is being looked for
@treturn boolean true if the player has at least one role which has the flag set to true, false otherwise, nil for errors

@usage-- Test if a player has a role
local has_flag = Roles.player_has_flag(game.player, 'is_donator')

]]
function Roles.player_has_flag(player, flag_name)
    local roles = Roles.get_player_roles(player)
    if not roles then return end
    for _, role in ipairs(roles) do
        if role:has_flag(flag_name) then
            return true
        end
    end

    return false
end

--[[-- A test for weather a player has at least one role which is allowed the given action
@tparam LuaPlayer player the player to test the roles of
@tparam string action the name of the action that is being tested for
@treturn boolean true if the player has at least one role which is allowed this action, false otherwise, nil for errors

@usage-- Test if a player has a role
local has_flag = Roles.player_has_flag(game.player, 'is_donator')

]]
function Roles.player_allowed(player, action)
    local roles = Roles.get_player_roles(player)
    if not roles then return end
    for _, role in ipairs(roles) do
        if role:is_allowed(action) then
            return true
        end
    end

    return false
end

--- Definitions.
-- Functions which are used to define roles
-- @section checks

--[[-- Used to set the role order, higher in the list is better, must be called at least once in config
-- nb: function also re links parents due to expected position in the config file
@tparam table order table a which is keyed only by numbers (start 1) and values are roles in order with highest first

@usage-- Define which roles are higher than others
Roles.define_role_order{
    'System',
    'Administrator',
    'Moderator',
    'Donator',
    'Guest'
}

]]
function Roles.define_role_order(order)
    -- Clears and then rebuilds the order table
    ExpUtil.assert_not_runtime()
    Roles.config.order = {}
    local done = {}
    for index, role in ipairs(order) do
        if type(role) == "table" and role.name then
            done[role.name] = true
            Roles.config.order[index] = role.name
        else
            done[role] = true
            Roles.config.order[index] = role
        end
    end

    -- Check no roles were missed
    for role_name in pairs(Roles.config.roles) do
        if not done[role_name] then
            error("Role missing " .. role_name .. " from role order, all defined roles must be included.", 2)
        end
    end

    -- Re-links roles to they parents as this is called at the end of the config
    for index, role_name in pairs(Roles.config.order) do
        local role = Roles.config.roles[role_name]
        if not role then
            error("Role with name " .. role_name .. " has not beed defined, either define it or remove it from the order list.", 2)
        end
        role.index = index
        local parent = Roles.config.roles[role.parent]
        if parent then
            setmetatable(role.allowed_actions, { __index = parent.allowed_actions })
        end
    end
end

--[[-- Defines a new trigger for when a tag is added or removed from a player
@tparam string name the name of the flag which the roles will have
@tparam function callback the function that is called when roles are assigned

@usage-- Defining a flag trigger
Roles.define_flag_trigger('is_donator', function(player, state)
    player.character_running_speed_modifier = state and 1.5 or 1
end)

]]
function Roles.define_flag_trigger(name, callback)
    Roles.config.flags[name] = Async.register(callback)
end

--[[-- Sets the default role which every player will have, this needs to be called at least once
@tparam string name the name of the default role

@usage-- Setting the default role
Roles.set_default('Guest')

]]
function Roles.set_default(name)
    local role = Roles.config.roles[name]
    if not role then return end
    Roles.config.internal.default = name
end

--[[-- Sets the root role which will always have all permissions, any server actions act from this role
@tparam string name the name of the root role

@usage-- Setting the root role
Roles.set_root('System')

]]
function Roles.set_root(name)
    local role = Roles.config.roles[name]
    if not role then return end
    role:set_allow_all(true)
    Roles.config.internal.root = name
end

--[[-- Defines a new role and returns the prototype to allow configuration
@tparam string name the name of the new role, must be unique
@tparam[opt=name] string short_hand the shortened version of the name
@treturn Roles._prototype the start of the config chain for this role

@usage-- Defining a new role
local role = Roles.new_role('Moderator', 'Mod')

]]
function Roles.new_role(name, short_hand)
    ExpUtil.assert_not_runtime()
    if Roles.config.roles[name] then return error("Role name is non unique") end
    local role = setmetatable({
        name = name,
        short_hand = short_hand or name,
        allowed_actions = {},
        allow_all_actions = false,
        flags = {},
    }, { __index = Roles._prototype })
    Roles.config.roles[name] = role
    return role
end

--- Role Actions.
-- Functions for using the role action system
-- @section actions

--[[-- Sets the default allow state of the role, true will allow all actions
@tparam[opt=true] boolean state true will allow all actions
@treturn Roles._prototype allows chaining

@usage-- Allow all actions for this role, useful for root like roles
role:set_allow_all()

]]
function Roles._prototype:set_allow_all(state)
    if state == nil then state = true end
    self.allow_all_actions = not not state -- not not forces a boolean value
    return self
end

--[[-- Sets the allow actions for this role, actions in this list will be allowed for this role
@tparam table actions indexed with numbers and is an array of action names, order has no effect
@treturn Roles._prototype allows chaining

@usage-- Allow some actions for a role
role:allow{
    'command/kill',
    'gui/game settings'
}

]]
function Roles._prototype:allow(actions)
    if type(actions) ~= "table" then
        actions = { actions }
    end
    for _, action in ipairs(actions) do
        self.allowed_actions[action] = true
    end

    return self
end

--[[-- Sets the disallow actions for this role, will prevent actions from being allowed regardless of inheritance
@tparam table actions indexed with numbers and is an array of action names, order has no effect
@treturn Roles._prototype allows chaining

@usage-- Disallow an action for a role, useful if inherit an action from a parent
role:disallow{
    'command/kill',
    'gui/game settings'
}

]]
function Roles._prototype:disallow(actions)
    if type(actions) ~= "table" then
        actions = { actions }
    end
    for _, action in ipairs(actions) do
        self.allowed_actions[action] = false
    end

    return self
end

--[[-- Test for if a role is allowed the given action, mostly internal see Roles.player_allowed
@tparam string action the name of the action to test if it is allowed
@treturn boolean true if action is allowed, false otherwise

@usage-- Test if a role is allowed an action
local allowed = role:is_allowed('command/kill')

]]
function Roles._prototype:is_allowed(action)
    local is_root = Roles.config.internal.root.name == self.name
    return self.allowed_actions[action] or self.allow_all_actions or is_root
end

--- Role Flags.
-- Functions for using the role flag system
-- @section flags

--[[-- Sets the state of a flag for a role, flags can be used to apply effects to players
@tparam string name the name of the flag to set the value of
@tparam[opt=true] boolean value the state to set the flag to
@treturn Roles._prototype allows chaining

@usage-- Set a flag for a role
role:set_flag('is_admin')

]]
function Roles._prototype:set_flag(name, value)
    if value == nil then value = true end
    self.flags[name] = not not value -- not not forces a boolean value
    return self
end

--[[-- Clears all flags from this role, individual flags can be removed with set_flag(name, false)
@treturn Roles._prototype allows chaining

@usage-- Remove all flags from a role
role:clear_flags()

]]
function Roles._prototype:clear_flags()
    self.flags = {}
    return self
end

--[[-- A test for if the role has a flag set
@tparam string name the name of the flag to test for
@treturn boolean true if the flag is set, false otherwise

@usage-- Test if a role has a flag
local has_flag = role:has_flag('is_admin')

]]
function Roles._prototype:has_flag(name)
    return self.flags[name] or false
end

--- Role Properties.
-- Functions for changing other properties
-- @section properties

--[[-- Sets a custom player tag for the role, can be accessed by other code
@tparam string tag the value that the tag will be
@treturn Roles._prototype allows chaining

@usage-- Set a custom tag for this role, other code is required to set the tag
role:set_custom_tag('Mod')

]]
function Roles._prototype:set_custom_tag(tag)
    self.custom_tag = tag
    return self
end

--[[-- Sets a custom colour for the role, can be accessed by other code
@tparam table color ?string|table can either be and rgb colour or the name of a colour defined in the presets
@treturn Roles._prototype allows chaining

@usage-- Set a custom colour for this role, other code is required to use this value
role:set_custom_color{ r=255, g=100, b=100}

]]
function Roles._prototype:set_custom_color(color)
    if type(color) ~= "table" then
        color = Colours[color]
    end
    self.custom_color = color
    return self
end

--[[-- Sets the permission group for this role, players will be moved to the group of they highest role
@tparam string name the name of the permission group to have players moved to
@tparam[opt=false] boolean use_factorio_api when true the custom permission group module is ignored
@treturn Roles._prototype allows chaining

@usage-- Set the permission group for this role, see permission_groups.lua
role:set_permission_group('Admin')

]]
function Roles._prototype:set_permission_group(name, use_factorio_api)
    ExpUtil.assert_not_runtime()
    if use_factorio_api then
        self.permission_group = { true, name }
    else
        local group = Groups.get_group_by_name(name)
        if not group then return end
        self.permission_group = name
    end
    return self
end

--[[-- Sets the parent for a role, any action not in allow or disallow will be looked for in its parents
nb: this is a recursive action, and changing the allows and disallows will effect all children roles
@tparam string role the name of the role that will be the parent; has imminent effect if role is already defined
@treturn Roles._prototype allows chaining

@usage-- Set the parent for this role to inherit all actions allowed
role:set_parent('Guest')

]]
function Roles._prototype:set_parent(role)
    ExpUtil.assert_not_runtime()
    self.parent = role
    role = Roles.get_role_from_any(role)
    if not role then return self end
    setmetatable(self.allowed_actions, { __index = role.allowed_actions })
    return self
end

--[[-- Sets an auto assign condition that is checked every 60 seconds, if true is returned then the player will receive the role
nb: this is one way, failing false after already gaining the role will not revoke the role
@tparam function callback receives only one param which is player to assign, return true to assign the player
@treturn Roles._prototype allows chaining

@usage-- Give this role to a user if there are admin, ran every 60 seconds
role:set_auto_assign_condition(function(player)
    return player.admin
end)

]]
function Roles._prototype:set_auto_assign_condition(callback)
    ExpUtil.assert_not_runtime()
    self.auto_assign_condition = true
    Roles.config.auto_assign[self.name] = callback
    return self
end

--[[-- Get the auto assign condition for this role, returns nil if no condition is set
@treturn function The callback which was assigned as the auto assign condition

@usage-- Give this role to a user if there are admin, ran every 60 seconds
local condition = role:get_auto_assign_condition()

]]
function Roles._prototype:get_auto_assign_condition()
    return Roles.config.auto_assign[self.name]
end

--[[-- Sets the role to not allow players to have auto assign effect them, useful to keep people locked to a role
@tparam[opt=true] boolean state when true the players with this role will not be auto assigned to other roles
@treturn Roles._prototype allows chaining

@usage-- Make a role stop players from being auto assigned to other roles
role:set_block_auto_assign()

]]
function Roles._prototype:set_block_auto_assign(state)
    if state == nil then state = true end
    self.block_auto_assign = not not state -- forces a boolean value
    return self
end

--- Role Players.
-- Functions that control players in a role
-- @section players

--[[-- Adds a player to this role, players can have more than one role at a time, used internally see Roles.assign
@tparam LuaPlayer player the player that will be given this role
@tparam boolean skip_check when true player will be taken as the player name (use when player has not yet joined)
@tparam boolean skip_event when true the event emit will be skipped, this is used internally with Roles.assign
@treturn boolean true if the player was added successfully

@usage-- Assign a player to this role
role:add_player(game.player)

]]
function Roles._prototype:add_player(player, skip_check, skip_event)
    local valid_player = type(player) == "userdata" and player or game.get_player(player)
    -- Default role cant have players added or removed
    if self.name == Roles.config.internal.default then return end
    -- Check the player is valid, can be skipped but a name must be given
    local player_name
    if valid_player then
        player_name = valid_player.name
    elseif skip_check then
        player_name = player
    else
        return false
    end
    -- Add the role name to the player's roles
    local player_roles = Roles.config.players[player_name]
    if player_roles then
        for _, role_name in ipairs(player_roles) do
            if role_name == self.name then return false end
        end

        player_roles[#player_roles + 1] = self.name
    else
        Roles.config.players[player_name] = { self.name }
    end
    -- Emits event if required
    if valid_player and not skip_event then
        emit_player_roles_updated(valid_player, "assign", { self })
    end
    return true
end

--[[-- Removes a player from this role, players can have more than one role at a time, used internally see Roles.unassign
@tparam LuaPlayer player the player that will lose this role
@tparam boolean skip_check when true player will be taken as the player name (use when player has not yet joined)
@tparam boolean skip_event when true the event emit will be skipped, this is used internally with Roles.unassign
@treturn boolean true if the player was removed successfully

@usage-- Unassign a player from this role
role:remove_player(game.player)

]]
function Roles._prototype:remove_player(player, skip_check, skip_event)
    local valid_player = type(player) == "userdata" and player or game.get_player(player)
    -- Default role cant have players added or removed
    if self.name == Roles.config.internal.default then return end
    -- Check the player is valid, can be skipped but a name must be given
    local player_name
    if valid_player then
        player_name = valid_player.name
    elseif skip_check then
        player_name = player
    else
        return false
    end
    -- Remove the role from the players roles
    local player_roles = Roles.config.players[player_name]
    local found = false
    if player_roles then
        for index, role_name in ipairs(player_roles) do
            if role_name == self.name then
                player_roles[index] = player_roles[#player_roles]
                player_roles[#player_roles] = nil
                found = true
                break
            end
        end

        if #player_roles == 0 then
            Roles.config.players[player_name] = nil
        end
    end
    -- Emits event if required
    if valid_player and not skip_event then
        emit_player_roles_updated(valid_player, "unassign", { self })
    end
    return found
end

--[[-- Returns an array of all the players who have this role, can be filtered by online status
@tparam[opt=nil] boolean online when given will filter by this online state, nil will return all players
@treturn table all the players who have this role, indexed order is meaningless

@usage-- Get all the players with this role
local players = role:get_players()

@usage-- Get all online players with this role
local players = role:get_players(true)

]]
function Roles._prototype:get_players(online)
    local players = {}
    -- Search all players to check if they have this role
    for player_name, player_roles in pairs(Roles.config.players) do
        for _, role_name in ipairs(player_roles) do
            if role_name == self.name then
                local player = game.players[player_name]
                -- Filter by online state if required
                if player and (online == nil or player.connected == online) then
                    players[#players + 1] = player
                end
                break
            end
        end
    end

    return players
end

--[[-- Will print a message to all players with this role
@tparam string message the message that will be printed to the players
@treturn number the number of players who received the message

@usage-- Print a message to all players with this role
role:print('Hello, World!')

]]
function Roles._prototype:print(message)
    local players = self:get_players(true)
    for _, player in ipairs(players) do
        player.print(message)
    end

    return #players
end

--- Used internally to be the first trigger on an event change, would be messy to include this in 4 different places
local function role_update(event)
    local player = game.players[event.player_index]
    -- Updates flags given to the player
    for flag, async_function in pairs(Roles.config.flags) do
        local state = Roles.player_has_flag(player, flag)
        async_function(player, state)
    end

    -- Updates the players permission group
    local highest = Roles.get_player_highest_role(player)
    if highest.permission_group then
        if highest.permission_group[1] then
            local group = game.permissions.get_group(highest.permission_group[2])
            if group then
                Groups.add_to_permission_group_async(group, player)
            end
        else
            Groups.set_player_group(player, highest.permission_group)
        end
    end
end

--- Used internally to test if a player should be auto assigned a role
local function auto_assign(event)
    local player = game.players[event.player_index]
    local roles = Roles.config.players[player.name] or {}

    local lookup = {}
    -- Create a lookup table for existing roles, and check for block auto assign
    for _, role in ipairs(roles) do
        if role.block_auto_assign then return end
        lookup[role] = true
    end

    local assigns, ctn = {}, 0
    -- Check roles with auto assign conditions and run the handler
    for role, condition in pairs(Roles.config.auto_assign) do
        if not lookup[role] then
            local success, rtn = pcall(condition, player)
            if not success then
                log{ "expcore-roles.error-log-format-assign", role.name, rtn }
            elseif rtn == true then
                ctn = ctn + 1
                assigns[ctn] = role
            end
        end
    end

    -- Assign new roles if any were passed
    if ctn > 0 then Roles.assign_player(player, assigns) end
end

--- When a player joined or has a role change then the update is triggered
Event.add(Roles.events.on_role_assigned, role_update)
Event.add(Roles.events.on_role_unassigned, role_update)
Event.add(defines.events.on_player_joined_game, role_update)

--- Every 60 seconds and on join auto role assignment is checked
Event.add(defines.events.on_player_joined_game, auto_assign)
Event.on_nth_tick(3600, function()
    for _, player in ipairs(game.connected_players) do
        auto_assign{ player_index = player.index }
    end
end)

-- Return Roles
return Roles
