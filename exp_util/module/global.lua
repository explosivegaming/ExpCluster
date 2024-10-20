--[[-- Util Module - Global
- Provides a method of using global with the guarantee that keys will not conflict
@core Global
@alias Global

@usage--- Drop in boiler plate:
-- Below is a drop in boiler plate which ensures your global access will not conflict with other modules
local global = {}
Global.register(global, function(tbl)
    global = tbl
end)

@usage--- Registering new global tables:
-- The boiler plate above is not recommend because it is not descriptive in its function
-- Best practice is to list out all variables you are storing in global and their function
local MyModule = {
    public_data = {} -- Stores data which other modules can access
}

local private_data = {} -- Stores data which other modules cant access
local more_private_data = {} -- Stores more data which other modules cant access
-- You can not store a whole module in global because not all data types are serialisable
Global.register({
    MyModule.public_data,
    private_data,
    more_private_data
}, function(tbl)
    -- You can also use this callback to set metatable on class instances you have stored in global
    MyModule.public_data = tbl[1]
    private_data = tbl[2]
    more_private_data = tbl[3]
end)

]]

local Clustorio = require("modules/clusterio/api")
local ExpUtil = require("modules.exp_util.common")

local Global = {
    registered = {}, -- Map of all registered values and their initial values
}

--- Register a new table to be stored in global, can only be called once per file, can not be called during runtime
-- @tparam table tbl The initial value for the table you are registering, this should be a local variable
-- @tparam function callback The callback used to replace local references and metatables
function Global.register(tbl, callback)
    ExpUtil.assert_not_runtime()
    ExpUtil.assert_argument_type(tbl, "table", 1, "tbl")
    ExpUtil.assert_argument_type(callback, "function", 2, "callback")

    local name = ExpUtil.safe_file_path(2)
    if Global.registered[name] then
        error("Global.register can only be called once per file", 2)
    end

    Global.registered[name] = {
        init = tbl,
        callback = callback
    }
end

--- Register a metatable which will be automatically restored during on_load
-- @tparam string name The name of the metatable to register, must be unique within your module
function Global.register_metatable(name, tbl)
    local module_name = ExpUtil.get_module_name(2)
    script.register_metatable(module_name.."."..name, tbl)
end

--- Restore aliases on load, we do not need to initialise data during this event
function Global.on_load()
    local globals = global.exp_global
	if globals == nil then return end
	for name, data in pairs(Global.registered) do
        if globals[name] ~= nil then
			data.callback(globals[name])
        end
    end
end

--- Event Handler, sets initial values if needed and calls all callbacks
local function on_server_startup()
    local globals = global.exp_global
    if globals == nil then
        globals = {}
        global.exp_global = globals
    end

    for name, data in pairs(Global.registered) do
        if globals[name] == nil then
            globals[name] = data.init
        end
        data.callback(globals[name])
    end
end

Global.on_init = on_server_startup
Global.events = {
    [Clustorio.events.on_server_startup] = on_server_startup
}

return Global
