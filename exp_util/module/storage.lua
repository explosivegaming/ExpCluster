--[[-- Util Module - Storage
- Provides a method of using storage with the guarantee that keys will not conflict
@core Storage
@alias Storage

@usage--- Drop in boiler plate:
-- Below is a drop in boiler plate which ensures your storage access will not conflict with other modules
local storage = {}
Storage.register(storage, function(tbl)
    storage = tbl
end)

@usage--- Registering new storage tables:
-- The boiler plate above is not recommend because it is not descriptive in its function
-- Best practice is to list out all variables you are storing in storage and their function
local MyModule = {
    public_data = {} -- Stores data which other modules can access
}

local private_data = {} -- Stores data which other modules cant access
local more_private_data = {} -- Stores more data which other modules cant access
-- You can not store a whole module in storage because not all data types are serialisable
Storage.register({
    MyModule.public_data,
    private_data,
    more_private_data
}, function(tbl)
    -- You can also use this callback to set metatable on class instances you have stored in storage
    MyModule.public_data = tbl[1]
    private_data = tbl[2]
    more_private_data = tbl[3]
end)

]]

local Clustorio = require("modules/clusterio/api")
local ExpUtil = require("modules/exp_util/common")

local Storage = {
    registered = {}, -- Map of all registered values and their initial values
}

--- Register a new table to be stored in storage, can only be called once per file, can not be called during runtime
-- @tparam table tbl The initial value for the table you are registering, this should be a local variable
-- @tparam function callback The callback used to replace local references and metatables
function Storage.register(tbl, callback)
    ExpUtil.assert_not_runtime()
    ExpUtil.assert_argument_type(tbl, "table", 1, "tbl")
    ExpUtil.assert_argument_type(callback, "function", 2, "callback")

    local name = ExpUtil.safe_file_path(2)
    if Storage.registered[name] then
        error("Storage.register can only be called once per file", 2)
    end

    Storage.registered[name] = {
        init = tbl,
        callback = callback,
    }
end

--- Register a metatable which will be automatically restored during on_load
-- @tparam string name The name of the metatable to register, must be unique within your module
function Storage.register_metatable(name, tbl)
    local module_name = ExpUtil.get_module_name(2)
    script.register_metatable(module_name .. "." .. name, tbl)
end

--- Restore aliases on load, we do not need to initialise data during this event
function Storage.on_load()
    local exp_storage = storage.exp_storage
    if exp_storage == nil then return end
    for name, info in pairs(Storage.registered) do
        if exp_storage[name] ~= nil then
            info.callback(exp_storage[name])
        end
    end
end

--- Event Handler, sets initial values if needed and calls all callbacks
function Storage.on_init()
    local exp_storage = storage.exp_storage
    if exp_storage == nil then
        exp_storage = {}
        storage.exp_storage = exp_storage
    end

    for name, info in pairs(Storage.registered) do
        if exp_storage[name] == nil then
            exp_storage[name] = info.init
        end
        info.callback(exp_storage[name])
    end
end

Storage.events = {
    [Clustorio.events.on_server_startup] = Storage.on_init,
}

return Storage
