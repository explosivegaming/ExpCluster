--[[-- Commands Module - Interface
    - Adds a command that acts as a direct link to the the active softmod, for debug use
    @commands Interface
]]

local Commands = require 'expcore.commands' --- @dep expcore.commands
local Global = require 'utils.global' --- @dep utils.global

-- modules that are loaded into the interface env to be accessed
local interface_modules = {
    ['Commands'] = Commands,
    ['output'] = _C.player_return,
    ['Group'] = 'expcore.permission_groups',
    ['Roles'] = 'expcore.roles',
    ['Gui'] = 'expcore.gui',
    ['Async'] = 'expcore.async',
    ['Datastore'] = 'expcore.datastore',
    ['External'] = 'expcore.external'
}

-- loads all the modules given in the above table
for key, value in pairs(interface_modules) do
    if type(value) == 'string' then
        interface_modules[key] = _C.opt_require(value)
    end
end

local interface_env = {} -- used as a persistent sandbox for interface commands
local interface_callbacks = {} -- saves callbacks which can load new values per use
Global.register(interface_env, function(tbl)
    interface_env = tbl
end)

--- Adds a static module that can be accessed with the interface
-- @tparam string name The name that the value is assigned to
-- @tparam any value The value that will be accessible in the interface env
-- callback param - player: LuaPlayer - the player who used the command
local function add_interface_module(name, value)
    interface_modules[name] = value
end

--- Adds a dynamic value that is calculated when the interface is used
-- @tparam string name The name that the value is assigned to
-- @tparam function callback The function that will be called to get the value
local function add_interface_callback(name, callback)
    if type(callback) == 'function' then
        interface_callbacks[name] = callback
    end
end

--- Internal, this is a meta function for __index when self[key] is nil
local function get_index(_, key)
    if interface_env[key] then
        return interface_env[key]
    elseif interface_modules[key] then
        return interface_modules[key]
    elseif _G[key] then
        return _G[key]
    end
end

--- Sends an invocation to be ran and returns the result.
-- @command interface
-- @tparam string invocation the command that will be run
Commands.new_command('interface', {'expcom-interface.description'}, 'Sends an invocation to be ran and returns the result.')
:add_param('invocation', false)
:enable_auto_concat()
:set_flag('admin_only')
:register(function(player, invocation)
    -- If the invocation has no white space then prepend return to it
    if not invocation:find('%s') and not invocation:find('return') then
        invocation = 'return '..invocation
    end

    -- _env will be the new _ENV that the invocation will run inside of
    local _env = setmetatable({}, {
        __index = get_index,
        __newindex = interface_env
    })

    -- If the command is ran by a player then load the dynamic values
    if player then
        for name, callback in pairs(interface_callbacks) do
            local _, rtn = pcall(callback, player)
            rawset(_env, name, rtn)
        end
    end

    -- Compile the invocation with the custom _env value
    local invocation_func, compile_error = load(invocation, 'interface', nil, _env)
    if compile_error then return Commands.error(compile_error) end

    -- Run the invocation
    local success, rtn = pcall(invocation_func)
    if not success then
        local err = rtn:gsub('%.%.%..-/temp/currently%-playing', '')
        return Commands.error(err)
    end
    return Commands.success(rtn)
end)

-- Adds some basic callbacks for the interface
add_interface_callback('player', function(player) return player end)
add_interface_callback('surface', function(player) return player.surface end)
add_interface_callback('force', function(player) return player.force end)
add_interface_callback('position', function(player) return player.position end)
add_interface_callback('entity', function(player) return player.selected end)
add_interface_callback('tile', function(player) return player.surface.get_tile(player.position) end)

-- Module Return
return {
    add_interface_module = add_interface_module,
    add_interface_callback = add_interface_callback,
    interface_env = interface_env,
    clean_stack_trace = function(str) return str:gsub('%.%.%..-/temp/currently%-playing', '') end
}
