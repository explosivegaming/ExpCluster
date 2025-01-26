--[[-- Core Module - Datastore
- A module used to store data in the global table with the option to have it sync to an external source.
@core Datastore
@alias DatastoreManager

@usage-- Types of Datastore
-- This datastore will not save data externally and can be used to watch for updates on values within it
-- A common use might be to store data for a gui and only update the gui when a value changes
local LocalDatastore = Datastore.connect('LocalDatastore')

-- This datastore will allow you to use the save and request method, this allows you to have persistent data
-- Should be used over auto save as it creates less save requests, but this means you need to tell the data to be saved
-- We use this type for player data as we know the data only needs to be saved when the player leaves
local PersistentDatastore = Datastore.connect('PersistentDatastore', true) -- save_to_disk

-- This datastore is the same as above but the save method will be called automatically when ever you change a value
-- An auto save datastore should be used if the data does not change often, this can be global settings and things of that sort
-- If it is at all possible to setup events to unload and/or save the data then this is preferable
local AutosaveDatastore = Datastore.connect('AutosaveDatastore', true, true) -- save_to_disk, auto_save

-- Finally you can have a datastore that propagates its changes to all other connected servers, this means request does not need to be used
-- This should be used when you might have data conflicts while saving, this is done by pushing the saved value to all active servers
-- The request method has little use after server start as any external changes to the value will be pushed automatically
-- Auto save can also be used with this type and you should follow the same guidelines above for when this should be avoided
local PropagateDatastore = Datastore.connect('PropagateDatastore', true, false, true) -- save_to_disk, propagate_changes

@usage-- Using Datastores Locally
-- Once you have your datastore connection setup, any further requests with connect will return the same datastore
-- This is important to know because the settings passed as parameters you have an effect when it is first created

-- One useful thing that you might want to set up before runtime is a serializer, this will convert non string keys into strings
-- This serializer will allow use to pass a player object and still have it serialized to the players name
local ExampleData = Datastore.connect('ExampleData')
ExampleData:set_serializer(function(rawKey)
    return rawKey.name
end)

-- If we want to get data from the datastore we can use get or get_all
local value = ExampleData:get(player, defaultValue)
local values = ExampleData:get_all()

-- If we want to set data then we can use set, increment, update, or update_all
ExampleData:set(player, 10)
ExampleData:increment(player)
ExampleData:update(player, function(player_name, value)
    return value * 2
end)
ExampleData:update_all(function(player_name, value)
    return value * 2
end)

-- If we want to remove data then we use remove
ExampleData:remove(player)

-- We can also listen for updates to a value done by any of the above methods with on_update
ExampleData:on_update(function(player_name, value)
    game.print(player_name..' has had their example data updated to '..tostring(value))
end)

@usage-- Using Datastore Externally
-- If save_to_disk is used then this opens up the option for persistent data which you can request, save, and remove
-- All of the local methods are still usable put now there is the option for extra events
-- In order for this to work there must be an external script to read datastore.pipe and inject with Datastore.ingest

-- To request data you would use request and the on_load event, this event can be used to modify data before it is used
ExampleData:request(player)
ExampleData:on_load(function(player_name, value)
    game.print('Loaded example data for '..player_name)
    -- A value can be returned here to overwrite the received value
end)

-- To save data you would use save and the on_save event, this event can be used to modify data before it is saved
ExampleData:save(player)
ExampleData:on_save(function(player_name, value)
    game.print('Saved example data for '..player_name)
    -- A value can be returned here to overwrite the value which is saved
end)

-- To remove data locally but not externally, like if a player logs off, you would use unload and on_unload
ExampleData:unload(player)
ExampleData:on_unload(function(player_name, value)
    game.print('Unloaded example data for '..player_name)
    -- Any return is ignored, this is event is for cleaning up other data
end)

@usage-- Using Datastore Messaging
-- The message action can be used regardless of save_to_disk being set as no data is saved, but an external script is still required
-- These messages can be used to send data to other servers which doesnt need to be saved such as shouts or commands
-- Using messages is quite simple only using message and on_message
ExampleData:message(key, message)
ExampleData:on_message(function(key, message)
    game.print('Received message '..message)
end)

@usage-- Combined Datastores
-- A combined datastore is a datastore which stores its data inside of another datastore
-- This means that the data is stored more efficiently in the external database and less requests need to be made
-- To understand how combined datastores work think of each key in the parent as a table where the sub datastore is a key in that table
-- Player data is the most used version of the combined datastore, below is how the player data module is setup
local PlayerData = Datastore.connect('PlayerData', true) -- saveToDisk
PlayerData:set_serializer(Datastore.name_serializer) -- use player name as key
PlayerData:combine('Statistics')
PlayerData:combine('Settings')
PlayerData:combine('Required')

-- You can then further combine datastores to any depth, below we add some possible settings and statistics that we might use
-- Although we dont in this example, each of these functions returns the datastore object which you should use as a local value
PlayerData.Settings:combine('Color')
PlayerData.Settings:combine('Quickbar')
PlayerData.Settings:combine('JoinMessage')
PlayerData.Statistics:combine('Playtime')
PlayerData.Statistics:combine('JoinCount')

-- Because sub datastore work just like a normal datastore you dont need any special code, using get and set will still return as if it wasnt a sub datastore
-- Things like the serializer and the datastore settings are always the same as the parent so you dont need to worry about setting up the serializer each time
-- And because save, request, and unload methods all point to the root datastore you are able to request and save your data as normal

-- If you used get_all on PlayerData this is what you would get:
{
    Cooldude2606 = {
        Settings = {
            Color = 'ColorValue',
            Quickbar = 'QuickbarValue',
            JoinMessage = 'JoinMessageValue'
        },
        Statistics = {
            Playtime = 'PlaytimeValue',
            JoinCount = 'JoinCountValue'
        }
    }
}

-- If you used get_all on PlayerData.Settings this is what you would get:
{
    Cooldude2606 = {
        Color = 'ColorValue',
        Quickbar = 'QuickbarValue',
        JoinMessage = 'JoinMessageValue'
    }
}

-- If you used get_all on PlayerData.Settings.Color this is what you would get:
{
    Cooldude2606 = 'ColorValue'
}

]]

local Storage = require("modules/exp_util/storage")

local DatastoreManager = {}
local Datastores = {}
local Datastore = {}
local Data = {}
local copy = table.deep_copy
local trace = debug.traceback
local table_to_json = helpers.table_to_json
local json_to_table = helpers.json_to_table
local write_file = helpers.write_file

--- Save datastores in the global table
Storage.register(Data, function(tbl)
    Data = tbl
    for name, datastore in pairs(Datastores) do
        datastore.data = Data[name]
    end
end, function(tbl)
    for name in pairs(Datastores) do
        tbl[name] = tbl[name] or {}
    end
end)

----- Datastore Manager
-- @section datastoreManager

--- Metatable used on datastores
DatastoreManager.metatable = {
    __index = function(self, key) return rawget(self.children, key) or rawget(Datastore, key) end,
    __newidnex = function(_, _, _) error("Datastore can not be modified", 2) end,
    __call = function(self, ...) return self:get(...) end,
}

--[[-- Make a new datastore connection, if a connection already exists then it is returned
@tparam string datastore_name The name that you want the new datastore to have, this can not have any whitespace
@tparam[opt=false] boolean saveToDisk When set to true, using the save method with write the data to datastore.pipe
@tparam[opt=false] boolean autoSave When set to true, using any method which modifies data will cause the data to be saved
@tparam[opt=false] boolean propagateChanges When set to true, using the save method will send the data to all other connected servers
@treturn table The new datastore connection that can be used to access and modify data in the datastore

@usage-- Connecting to the test datastore which will allow saving to disk
local ExampleData = Datastore.connect('ExampleData', true) -- saveToDisk

]]
function DatastoreManager.connect(datastore_name, save_to_disk, autosave, propagate_changes)
    if Datastores[datastore_name] then return Datastores[datastore_name] end
    if package.lifecycle ~= package.lifecycle_stage.control then
        -- Only allow this function to be called during the control stage
        error("New datastore connection can not be created during runtime", 2)
    end

    local new_datastore = {
        name = datastore_name,
        value_name = datastore_name,
        auto_save = autosave or false,
        save_to_disk = save_to_disk or false,
        propagate_changes = propagate_changes or false,
        serializer = false,
        parent = false,
        children = {},
        metadata = {},
        events = {},
        data = {},
    }

    Data[datastore_name] = new_datastore.data
    Datastores[datastore_name] = new_datastore
    return setmetatable(new_datastore, DatastoreManager.metatable)
end

--[[-- Make a new datastore that stores its data inside of another one
@tparam string datastore_name The name of the datastore that will contain the data for the new datastore
@tparam string subdatastore_name The name of the new datastore, this name will also be used as the key inside the parent datastore
@treturn table The new datastore connection that can be used to access and modify data in the datastore

@usage-- Setting up a datastore which stores its data inside of another datastore
local BarData = Datastore.combine('ExampleData', 'Bar')

]]
function DatastoreManager.combine(datastore_name, subdatastore_name)
    local datastore = assert(Datastores[datastore_name], "Datastore not found " .. tostring(datastore_name))
    return datastore:combine(subdatastore_name)
end

--[[-- Ingest the result from a request, this is used through a rcon interface to sync data
@tparam string action The action that should be done, can be: remove, message, propagate, or request
@tparam string datastore_name The name of the datastore that should have the action done to it
@tparam string key The key of that datastore that is having the action done to it
@tparam string valueJson The json string for the value being ingested, remove does not require a value

@usage-- Replying to a data request
Datastore.ingest('request', 'ExampleData', 'TestKey', 'Foo')

]]
function DatastoreManager.ingest(action, datastore_name, key, value_json)
    local datastore = assert(Datastores[datastore_name], "Datastore ingest error, Datastore not found " .. tostring(datastore_name))
    assert(type(action) == "string", "Datastore ingest error, Action is not a string got: " .. type(action))
    assert(type(key) == "string", "Datastore ingest error, Key is not a string got: " .. type(key))

    if action == "remove" then
        datastore:raw_set(key)
    elseif action == "message" then
        local success, value = pcall(json_to_table, value_json)
        if not success or value == nil then value = tonumber(value_json) or value_json end
        datastore:raise_event("on_message", key, value)
    elseif action == "propagate" or action == "request" then
        local success, value = pcall(json_to_table, value_json)
        if not success or value == nil then value = tonumber(value_json) or value_json end
        local old_value = datastore:raw_get(key)
        value = datastore:raise_event("on_load", key, value, old_value)
        datastore:set(key, value)
    end
end

--[[-- Debug, Use to get all datastores, or return debug info on a datastore
@tparam[opt] string datastore_name The name of the datastore to get the debug info of

@usage-- Get all the datastores
local datastores = Datastore.debug()

@usage-- Getting the debug info for a datastore
local debug_info = Datastore.debug('ExampleData')

]]
function DatastoreManager.debug(datastore_name)
    if not datastore_name then return Datastores end
    local datastore = assert(Datastores[datastore_name], "Datastore not found " .. tostring(datastore_name))
    return datastore:debug()
end

--[[-- Commonly used serializer, returns the name of the object
@tparam any rawKey The raw key that will be serialized, this can be things like player, force, surface, etc
@treturn string The name of the object that was passed

@usage-- Using the name serializer for your datastore
local ExampleData = Datastore.connect('ExampleData')
ExampleData:set_serializer(Datastore.name_serializer)

]]
function DatastoreManager.name_serializer(raw_key)
    return raw_key.name
end

----- Datastore Internal
-- @section datastore-internal

--[[-- Debug, Get the debug info for this datastore
@treturn table The debug info for this datastore, contains stuff like parent, settings, children, etc

@usage-- Get the debug info for a datastore
local ExampleData = Datastore.connect('ExampleData')
local debug_info = ExampleData:debug()

]]
function Datastore:debug()
    local debug_info = {}

    if self.parent then
        debug_info.parent = self.parent.name
    else
        debug_info.settings = { auto_save = self.auto_save, save_to_disk = self.save_to_disk, propagate_changes = self.propagate_changes, serializer = not not self.serializer }
    end

    local children = {}
    for name in pairs(self.children) do children[#children + 1] = name end

    if #children > 0 then debug_info.children = children end

    local events = {}
    for name, handlers in pairs(self.events) do events[name] = #handlers end

    if next(events) then debug_info.events = events end

    if next(self.metadata) then debug_info.metadata = self.metadata end
    debug_info.data = self:get_all()

    return debug_info
end

--[[-- Internal, Get data following combine logic
@tparam string key The key to get the value of from this datastore
@tparam[opt=false] boolean fromChild If the get request came from a child of this datastore
@treturn any The value that was stored at this key in this datastore

@usage-- Internal, Get the data from a datastore
local value = self:raw_get('TestKey')

]]
function Datastore:raw_get(key, from_child)
    local data = self.data
    if self.parent then
        data = self.parent:raw_get(key, true)
        key = self.value_name
    end
    local value = data[key]
    if value ~= nil then return value end
    if from_child then value = {} end
    data[key] = value
    return value
end

--[[-- Internal, Set data following combine logic
@tparam string key The key to set the value of in this datastore
@tparam any value The value that will be set at this key

@usage-- Internal, Set the value in a datastore
self:raw_set('TestKey', 'Foo')

]]
function Datastore:raw_set(key, value)
    if self.parent then
        local data = self.parent:raw_get(key, true)
        data[self.value_name] = value
    else
        self.data[key] = value
    end
end

local function serialize_error(err) error("An error ocurred in a datastore serializer: " .. trace(err)) end
--[[-- Internal, Return the serialized key
@tparam any rawKey The key that needs to be serialized, if it is already a string then it is returned
@treturn string The key after it has been serialized

@usage-- Internal, Ensure that the key is a string
key = self:serialize(key)

]]
function Datastore:serialize(raw_key)
    if type(raw_key) == "string" then return raw_key end
    assert(self.serializer, "Datastore does not have a serializer and received non string key")
    local success, key = xpcall(self.serializer, serialize_error, raw_key)
    return success and key or nil
end

--[[-- Internal, Writes an event to the output file to be saved and/or propagated
@tparam string action The action that should be wrote to datastore.pipe, can be request, remove, message, save, propagate
@tparam string key The key that the action is being preformed on
@tparam any value The value that should be used with the action

@usage-- Write a data request to datastore.pipe
self:write_action('request', 'TestKey')

@usage-- Write a data save to datastore.pipe
self:write_action('save', 'TestKey', 'Foo')

]]
function Datastore:write_action(action, key, value)
    local data = { action, self.name, key }
    if value ~= nil then
        data[4] = type(value) == "table" and table_to_json(value) or value
    end
    write_file("ext/datastore.out", table.concat(data, " ") .. "\n", true, 0)
end

----- Datastore Local
-- @section datastore-local

--[[-- Create a new datastore which is stores its data inside of this datastore
@tparam string subdatastore_name The name of the datastore that will have its data stored in this datastore
@treturn table The new datastore that was created inside of this datastore

@usage-- Add a new sub datastore
local ExampleData = Datastore.connect('ExampleData')
local BarData = ExampleData:combine('Bar')

]]
function Datastore:combine(subdatastore_name)
    local new_datastore = DatastoreManager.connect(self.name .. "." .. subdatastore_name)
    self.children[subdatastore_name] = new_datastore
    new_datastore.value_name = subdatastore_name
    new_datastore.serializer = self.serializer
    new_datastore.auto_save = self.auto_save
    new_datastore.parent = self
    Data[new_datastore.name] = nil
    new_datastore.data = nil
    return new_datastore
end

--[[-- Set a callback that will be used to serialize keys which aren't strings
@tparam function callback The function that will be used to serialize non string keys passed as an argument

@usage-- Set a custom serializer, this would be the same as Datastore.name_serializer
local ExampleData = Datastore.connect('ExampleData')
ExampleData:set_serializer(function(rawKey)
    return rawKey.name
end)

]]
function Datastore:set_serializer(callback)
    assert(type(callback) == "function", "Callback must be a function")
    self.serializer = callback
end

--[[-- Set a default value to be returned by get if no other default is given, using will mean get will never return nil, set using the default will set to nil to save space
@tparam any value The value that will be deep copied by get if the value is nil and no other default is given
@tparam boolean allowSet When true if the default is passed as the value for set it will be set rather than setting nil

@usage-- Set a default value to be returned by get
local ExampleData = Datastore.connect('ExampleData')
ExampleData:set_default('Foo')

]]
function Datastore:set_default(value, allow_set)
    self.default = value
    self.allow_set_to_default = allow_set
end

--[[-- Set metadata tags on this datastore which can be accessed by other scripts
@tparam table tags A table of tags that you want to set in the metadata for this datastore

@usage-- Adding metadata that could be used by a gui to help understand the stored data
local ExampleData = Datastore.connect('ExampleData')
ExampleData:set_metadata{
    caption = 'Test Data',
    tooltip = 'Data used for testing datastores',
    type = 'table'
}

]]
function Datastore:set_metadata(tags)
    local metadata = self.metadata
    for key, value in pairs(tags) do
        metadata[key] = value
    end
end

--[[-- Get a value from local storage, option to have a default value, do not edit the data returned as changes may not save, use update if you want to make changes
@tparam any key The key that you want to get the value of, must be a string unless a serializer is set
@tparam[opt] any default The default value that will be returned if no value is found in the datastore

@usage-- Get a key from the datastore, the default will be deep copied if no value exists in the datastore
local ExampleData = Datastore.connect('ExampleData')
local value = ExampleData:get('TestKey')

]]
function Datastore:get(key, default)
    key = self:serialize(key)
    local value = self:raw_get(key)
    if value ~= nil then return value end
    return copy(default or self.default)
end

--[[-- Set a value in local storage, will trigger on_update then on_save, save_to_disk and auto_save is required for on_save
@tparam any key The key that you want to set the value of, must be a string unless a serializer is set
@tparam any value The value that you want to set for this key

@usage-- Set a value in the datastore, this will trigger on_update, if auto_save is true then will trigger save
local ExampleData = Datastore.connect('ExampleData')
ExampleData:set('TestKey', 'Foo')

]]
function Datastore:set(key, value)
    key = self:serialize(key)
    local old_value = self:raw_get(key)
    if value == self.default and not self.allow_set_to_default then
        self:raw_set(key)
    else
        self:raw_set(key, value)
    end
    self:raise_event("on_update", key, value, old_value)
    if self.auto_save then self:save(key) end
    return value
end

--[[-- Increment the value in local storage, only works for number values, will trigger on_update then on_save, save_to_disk and auto_save is required for on_save
@tparam any key The key that you want to increment the value of, must be a string unless a serializer is set
@tparam[opt=1] number delta The amount that you want to increment the value by, can be negative or a decimal

@usage-- Increment a value in a datastore, the value must be a number or nil, if nil 0 is used as the start value
local ExampleData = Datastore.connect('ExampleData')
ExampleData:increment('TestNumber')

]]
function Datastore:increment(key, delta)
    key = self:serialize(key)
    local value = self:raw_get(key) or 0
    return self:set(key, value + (delta or 1))
end

local function update_error(err) log("An error occurred in datastore update:\n\t" .. trace(err)) end
--[[-- Use a function to update the value locally, will trigger on_update then on_save, save_to_disk and auto_save is required for on_save
@tparam any key The key that you want to apply the update to, must be a string unless a serializer is set
@tparam function callback The function that will be used to update the value at this key

@usage-- Using a function to update a value, if a value is returned then this will be the new value
local ExampleData = Datastore.connect('ExampleData')
ExampleData:increment('TestKey', function(key, value)
    return value..value
end)

]]
function Datastore:update(key, callback)
    key = self:serialize(key)
    local value = self:get(key)
    local raw_value = self:raw_get(key)
    local old_value = copy(self:raw_get(key))
    local success, new_value = xpcall(callback, update_error, key, value)
    if not success then
        self:raw_set(key, old_value)
    elseif new_value ~= nil then
        self:set(key, new_value)
    elseif raw_value == nil then
        self:set(key, value)
    else
        self:raise_event("on_update", key, value, old_value)
        if self.auto_save then self:save(key) end
    end
end

--[[-- Remove a value locally and on the external source, works regardless of propagateChanges, requires save_to_disk for external changes
@tparam any key The key that you want to remove locally and externally, must be a string unless a serializer is set

@usage-- Remove a key locally and externally
local ExampleData = Datastore.connect('ExampleData')
ExampleData:remove('TestKey')

]]
function Datastore:remove(key)
    key = self:serialize(key)
    local old_value = self:raw_get(key)
    self:raw_set(key)
    self:raise_event("on_update", key, nil, old_value)
    if self.save_to_disk then self:write_action("remove", key) end
    if self.parent and self.parent.auto_save then return self.parent:save(key) end
end

local function filter_error(err) log("An error ocurred in a datastore filter:\n\t" .. trace(err)) end
--[[-- Internal, Used to filter elements from a table
@tparam table tbl The table that will have the filter applied to it
@tparam[opt] function callback The function that will be used as a filter, if none giving then the provided table is returned
@treturn table The table which has only the key values pairs which passed the filter

@usage-- Internal, Filter a table by the values it contains, return true to keep the key value pair
local filtered_table = filter({5,3,4,1,2}, function(key, value)
    return value > 2
end)

]]
local function filter(tbl, callback)
    if not callback then return tbl end
    local rtn = {}
    for key, value in pairs(tbl) do
        local success, add = xpcall(callback, filter_error, key, value)
        if success and add then rtn[key] = value end
    end

    return rtn
end

--[[-- Get all keys in this datastore, optional filter callback
@tparam[opt] function callback The filter function that can be used to filter the results returned
@treturn table All the data that is in this datastore, filtered if a filter was provided

@usage-- Get all the data in this datastore
local ExampleData = Datastore.connect('ExampleData')
local data = ExampleData:get_all()

@usage-- Get all the data in this datastore, with a filter
local ExampleData = Datastore.connect('ExampleData')
local data = ExampleData:get_all(function(key, value)
    return type(value) == 'string'
end)

]]
function Datastore:get_all(callback)
    if not self.parent then
        return filter(self.data, callback)
    else
        local data, value_name = {}, self.value_name
        for key, value in pairs(self.parent:get_all()) do
            data[key] = value[value_name]
        end

        return filter(data, callback)
    end
end

--[[-- Update all keys in this datastore using the same update function
@tparam function callback The update function that will be applied to each key

@usage-- Get all the data in this datastore, with a filter
local ExampleData = Datastore.connect('ExampleData')
ExampleData:update_all(function(key, value)
    return value..value
end)

]]
function Datastore:update_all(callback)
    local data = self:get_all()
    for key, value in pairs(data) do
        local old_value = copy(value)
        local success, new_value = xpcall(callback, update_error, key, value)
        if success and new_value ~= nil then
            self:set(key, new_value)
        else
            self:raise_event("on_update", key, value, old_value)
            if self.auto_save then self:save(key) end
        end
    end
end

----- Datastore External
-- @section datastore-external

--[[-- Request a value from an external source, will trigger on_load when data is received
@tparam any key The key that you want to request from an external source, must be a string unless a serializer is set

@usage-- Request a key from an external source, on_load is triggered when data is received
local ExampleData = Datastore.connect('ExampleData')
ExampleData:request('TestKey')

]]
function Datastore:request(key)
    if self.parent then return self.parent:request(key) end
    key = self:serialize(key)
    self:write_action("request", key)
end

--[[-- Save a value to an external source, will trigger on_save before data is saved, save_to_disk must be set to true
@tparam any key The key that you want to save to an external source, must be a string unless a serializer is set

@usage-- Save a key to an external source, save_to_disk must be set to true for there to be any effect
local ExampleData = Datastore.connect('ExampleData')
ExampleData:save('TestKey')

]]
function Datastore:save(key)
    if self.parent then self.parent:save(key) end
    if not self.save_to_disk then return end
    key = self:serialize(key)
    local value = self:raise_event("on_save", key, copy(self:raw_get(key)))
    local action = self.propagate_changes and "propagate" or "save"
    self:write_action(action, key, value)
end

--[[-- Save a value to an external source and remove locally, will trigger on_unload then on_save, save_to_disk is not required for on_unload
@tparam any key The key that you want to unload from the datastore, must be a string unless a serializer is set

@usage-- Unload a key from the datastore, get will now return nil and value will be saved externally if save_to_disk is set to true
local ExampleData = Datastore.connect('ExampleData')
ExampleData:unload('TestKey')

]]
function Datastore:unload(key)
    if self.parent then return self.parent:unload(key) end
    key = self:serialize(key)
    self:raise_event("on_unload", key, copy(self:raw_get(key)))
    self:save(key)
    self:raw_set(key)
end

--[[-- Use to send a message over the connection, works regardless of saveToDisk and propagateChanges
@tparam any key The key that you want to send a message over, must be a string unless a serializer is set
@tparam any message The message that you want to send to other connected servers, or external source

@usage-- Send a message to other servers on this key, can listen for messages with on_message
local ExampleData = Datastore.connect('ExampleData')
ExampleData:message('TestKey', 'Foo')

]]
function Datastore:message(key, message)
    key = self:serialize(key)
    self:write_action("message", key, message)
end

--[[-- Save all the keys in the datastore, optional filter callback
@tparam[opt] function callback The filter function that can be used to filter the keys saved

@usage-- Save all the data in this datastore
local ExampleData = Datastore.connect('ExampleData')
local data = ExampleData:save_all()

@usage-- Save all the data in this datastore, with a filter
local ExampleData = Datastore.connect('ExampleData')
ExampleData:save_all(function(key, value)
    return type(value) == 'string'
end)

]]
function Datastore:save_all(callback)
    local data = self:get_all(callback)
    for key in pairs(data) do self:save(key) end
end

--[[-- Unload all the keys in the datastore, optional filter callback
@tparam[opt] function callback The filter function that can be used to filter the keys unloaded

@usage-- Unload all the data in this datastore
local ExampleData = Datastore.connect('ExampleData')
ExampleData:unload_all()

@usage-- Unload all the data in this datastore, with a filter
local ExampleData = Datastore.connect('ExampleData')
ExampleData:unload_all(function(key, value)
    return type(value) == 'string'
end)

]]
function Datastore:unload_all(callback)
    local data = self:get_all(callback)
    for key in pairs(data) do self:unload(key) end
end

----- Events
-- @section events

local function event_error(err) log("An error ocurred in a datastore event handler:\n\t" .. trace(err)) end
--[[-- Internal, Raise an event on this datastore
@tparam string event_name The name of the event to raise for this datastore
@tparam string key The key that this event is being raised for
@tparam[opt] any value The current value that this key has, might be a deep copy of the value
@tparam[opt] any old_value The previous value that this key has, might be a deep copy of the value
@tparam[opt] string source Where this call came from, used to do event recursion so can be parent or child
@treturn any The value that is left after being passed through all the event handlers

@usage-- Internal, Getting the value that should be saved
value = self:raise_event('on_save', key, value)

]]
function Datastore:raise_event(event_name, key, value, old_value, source)
    -- Raise the event for the children of this datastore
    if source ~= "child" and next(self.children) then
        if type(value) ~= "table" then value = {} end
        for value_name, child in pairs(self.children) do
            local old_child_value = old_value and old_value[value_name] or nil
            value[value_name] = child:raise_event(event_name, key, value[value_name], old_child_value, "parent")
        end
    end

    -- Raise the event for this datastore
    local handlers = self.events[event_name]
    if handlers then
        for _, handler in ipairs(handlers) do
            local success, new_value = xpcall(handler, event_error, key, value, old_value)
            if success and new_value ~= nil then value = new_value end
        end
    end

    -- Raise the event for the parent of this datastore
    if source ~= "parent" and self.parent then
        local parent_value = self.parent:raw_get(key, true)
        self.parent:raise_event(event_name, key, parent_value, parent_value, "child")
    end

    -- If this is the save event and the table is empty then return nil
    if event_name == "on_save" and next(self.children) and not next(value) then return end
    return value
end

--[[-- Internal, Returns a function which will add a callback to an event
@tparam string event_name The name of the event that this should create a handler adder for
@treturn function The function that can be used to add handlers to this event

@usage-- Internal, Get the function to add handlers to on_load
Datastore.on_load = event_factory('on_load')

]]
local function event_factory(event_name)
    return function(self, callback)
        assert(type(callback) == "function", "Handler must be a function")
        local handlers = self.events[event_name]
        if not handlers then
            self.events[event_name] = { callback }
        else
            handlers[#handlers + 1] = callback
        end
    end
end

--[[-- Register a callback that triggers when data is loaded from an external source, returned value is saved locally
@tparam function callback The handler that will be registered to the on_load event
@usage-- Adding a handler to on_load, returned value will be saved locally, can be used to deserialize the value beyond a normal json
local ExampleData = Datastore.connect('ExampleData')
ExampleData:on_load(function(key, value)
    game.print('Test data loaded for: '..key)
end)
]]
Datastore.on_load = event_factory("on_load")

--[[-- Register a callback that triggers before data is saved, returned value is saved externally
@tparam function callback The handler that will be registered to the on_load event
@usage-- Adding a handler to on_save, returned value will be saved externally, can be used to serialize the value beyond a normal json
local ExampleData = Datastore.connect('ExampleData')
ExampleData:on_save(function(key, value)
    game.print('Test data saved for: '..key)
end)
]]
Datastore.on_save = event_factory("on_save")

--[[-- Register a callback that triggers before data is unloaded, returned value is ignored
@tparam function callback The handler that will be registered to the on_load event
@usage-- Adding a handler to on_unload, returned value is ignored, can be used to clean up guis or local values related to this data
local ExampleData = Datastore.connect('ExampleData')
ExampleData:on_load(function(key, value)
    game.print('Test data unloaded for: '..key)
end)
]]
Datastore.on_unload = event_factory("on_unload")

--[[-- Register a callback that triggers when a message is received, returned value is ignored
@tparam function callback The handler that will be registered to the on_load event
@usage-- Adding a handler to on_message, returned value is ignored, can be used to receive messages from other connected servers without saving data
local ExampleData = Datastore.connect('ExampleData')
ExampleData:on_message(function(key, value)
    game.print('Test data message for: '..key)
end)
]]
Datastore.on_message = event_factory("on_message")

--[[-- Register a callback that triggers any time a value is changed, returned value is ignored
@tparam function callback The handler that will be registered to the on_load event
@usage-- Adding a handler to on_update, returned value is ignored, can be used to update guis or send messages when data is changed
local ExampleData = Datastore.connect('ExampleData')
ExampleData:on_update(function(key, value)
    game.print('Test data updated for: '..key)
end)
]]
Datastore.on_update = event_factory("on_update")

----- Module Return
return DatastoreManager
