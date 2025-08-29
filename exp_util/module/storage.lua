--[[ ExpUtil - Storage
Provides a method of using storage with the guarantee that keys will not conflict

--- Drop in boiler plate:
-- Below is a drop in boiler plate which ensures your storage access will not conflict with other modules
local storage = {}
Storage.register(storage, function(tbl)
    storage = tbl
end)

--- Registering new storage tables:
-- The boiler plate above is not recommend because it is not descriptive in its function
-- Best practice is to list out all variables you are storing in storage and their function
local MyModule = {
    public_data = {}
}

-- The use of root level primitives is discouraged, but if you must use them then
-- they can not be stored directly in locals and instead within a local table
local primitives = {
    my_primitive = 1,
}

local private_data = {}
local my_table = {}
-- You can not store a whole module in storage because not all data types are serialisable
Storage.register({
    MyModule.public_data,
    primitives,
    private_data,
    my_table,
}, function(tbl)
    MyModule.public_data = tbl[1]
    primitives = tbl[2]
    private_data = tbl[3]
    my_table = tbl[4]
end)

--- Registering metatables
-- Metatables are needed to create instances of a class, these used to be restored manually but not script.register_metatable exists
-- However it is possible for name conflicts to occur so it is encouraged to use Storage.register_metatable to avoid this
local my_metatable = Storage.register_metatable("MyMetaTable", {
    __call = function(self) game.print("I got called!") end
})

]]

local ExpUtil = require("modules/exp_util")

--- @class ExpUtil_Storage
local Storage = {
    _registered = {}, --- @type table<string, { init: table, callback: fun(tbl: table), on_init: fun(tbl: table)? }>
}

--- Register a new table to be stored in storage, can only be called once per file, can not be called during runtime
--- @generic T:table
--- @param tbl T The initial value for the table you are registering, this should be a local variable
--- @param callback fun(tbl: T) The callback used to replace local references and metatables
--- @param on_init fun(tbl: T)? The callback used to setup/validate storage if a static value is not enough
-- This function does not return the table because the callback can't access the local it would be assigned to
function Storage.register(tbl, callback, on_init)
    ExpUtil.assert_not_runtime()
    ExpUtil.assert_argument_type(tbl, "table", 1, "tbl")
    ExpUtil.assert_argument_type(callback, "function", 2, "callback")

    local name = ExpUtil.safe_file_path(2)
    if Storage._registered[name] then
        error("Storage.register can only be called once per file", 2)
    end

    Storage._registered[name] = {
        init = tbl,
        callback = callback,
        on_init = on_init,
    }
end

--- Register a metatable which will be automatically restored during on_load
--- @param name string The name of the metatable to register, must be unique within your module
--- @param tbl metatable The metatable to register
--- @return table # The metatable passed as the second argument
function Storage.register_metatable(name, tbl)
    local module_name = ExpUtil.get_module_name(2)
    script.register_metatable(module_name .. "." .. name, tbl)
    return tbl
end

--- Restore aliases on load, we do not need to initialise data during this event
--- @package
function Storage.on_load()
    --- @type table<string, table>
    local exp_storage = storage.exp_storage
    if exp_storage == nil then return end
    for name, info in pairs(Storage._registered) do
        if exp_storage[name] ~= nil then
            info.callback(exp_storage[name])
        end
    end
end

--- Event Handler, sets initial values if needed and calls all callbacks
--- @package
function Storage.on_init()
    --- @type table<string, table>
    local exp_storage = storage.exp_storage
    if exp_storage == nil then
        exp_storage = {}
        storage.exp_storage = exp_storage
    end

    for name, info in pairs(Storage._registered) do
        if exp_storage[name] == nil then
            exp_storage[name] = info.init
        end
        if info.on_init then
            info.on_init(exp_storage[name])
        end
        info.callback(exp_storage[name])
    end
end

--- @package
Storage.events = {
    [defines.events.on_multiplayer_init] = Storage.on_init,
    [defines.events.on_singleplayer_init] = Storage.on_init,
}

return Storage
