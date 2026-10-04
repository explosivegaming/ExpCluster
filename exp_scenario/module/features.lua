--[[-- ExpScenario - Features
Features which the controller can enable, disable, and configure while the game is running

The config table is changed in place when the controller sends values, so read
them where they are used rather than caching them when the file loads. Values
read while the file loads, such as on_nth_tick periods, are not listed in features.ts.

--- Registering a feature, small configs live at the top of the file which uses them:
local Feature = require("modules/exp_scenario/features")
local feature, config = Feature.register("my_feature", {
    show_message = true, -- booleans, numbers, and strings
    role_id = Feature.optional("number"), -- no default
    item_names = Feature.set{ "iron-plate" }, -- indexed by name
    surface_names = Feature.list{ "nauvis" },
    section = { count = 1 }, -- addressed as "section.count"
})

--- Handlers do nothing while the feature is disabled:
return feature:guard{
    events = { [defines.events.on_player_joined_game] = on_player_joined_game },
}

--- Toolbar buttons and commands:
Gui.toolbar.create_button{ visible = function(player) return feature:is_enabled() end }
Commands.new("my_command", { "..." }):add_flags{ feature = feature }

--- Changes are raised per value:
[Feature.events.on_config_updated] = function(event) end, -- { feature_name, path, old_value, new_value }
]]

local Storage = require("modules/exp_util/storage")

--- @class ExpScenario.FeatureField
--- @field path string
--- @field parent table
--- @field key string
--- @field default any
--- @field type string "boolean", "number", "string", "list", "set", or a type which can not be set

--- @class ExpScenario.Features
local Feature = {
    _registered = {}, --- @type table<string, ExpScenario.Feature>
    events = {
        --- @type EventData.ExpScenario.on_config_updated
        on_config_updated = script.generate_event_name(),
    },
}

--- @class ExpScenario.Feature
--- @field name string
--- @field config table
--- @field fields table<string, ExpScenario.FeatureField> By path
--- @field values table<string, any> Last received from the controller, restored from storage on load
Feature._prototype = {}

--- @class EventData.ExpScenario.on_config_updated : EventData
--- @field feature_name string
--- @field path string "enabled" when the feature is enabled or disabled
--- @field old_value any
--- @field new_value any

local Feature_mt = {
    __index = Feature._prototype,
}

--- Only the values are stored, the rest is rebuilt when the file loads
local stored_values = {} --- @type table<string, table<string, any>>
Storage.register(stored_values, function(tbl)
    stored_values = tbl
    for name, feature in pairs(Feature._registered) do
        feature.values = tbl[name] or {}
        for path, field in pairs(feature.fields) do
            feature:_set_field(field, feature.values[path])
        end
    end
end)

--- @param value any
--- @return boolean
local function is_string_list(value)
    if type(value) ~= "table" then return false end
    if next(value) ~= nil and value[1] == nil then return false end
    for _, item in pairs(value) do
        if type(item) ~= "string" then return false end
    end
    return true
end

--- Lists and sets are compared by their contents
--- @param a any
--- @param b any
--- @return boolean
local function values_equal(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    if table_size(a) ~= table_size(b) then return false end
    for key, value in pairs(a) do
        if b[key] ~= value then return false end
    end
    return true
end

--- Marks a default made by Feature.list, Feature.set, or Feature.optional
local typed_mt = {}

--- @param list string[]
--- @return table<string, true>
local function list_to_set(list)
    local set = {}
    for _, item in ipairs(list) do
        set[item] = true
    end
    return set
end

--- Nested tables with string keys are sections
--- @param fields table<string, ExpScenario.FeatureField>
--- @param tbl table
--- @param prefix string
local function collect_fields(fields, tbl, prefix)
    for key, value in pairs(tbl) do
        if type(key) == "string" then
            local path = prefix .. key
            local field = { path = path, parent = tbl, key = key, default = value, type = type(value) }
            if type(value) == "table" then
                if getmetatable(value) == typed_mt then
                    field.type = value.type
                    field.default = value.default
                    tbl[key] = value.default
                elseif type(next(value)) == "string" then
                    collect_fields(fields, value, path .. ".")
                    field = nil
                end
            end
            if field then
                fields[path] = field
            end
        end
    end
end

--- A value with no default, the argument is the type it accepts
--- @param value_type "boolean" | "number" | "string"
--- @return any
function Feature.optional(value_type)
    return setmetatable({ type = value_type }, typed_mt)
end

--- A list of strings
--- @param items string[]
--- @return string[]
function Feature.list(items)
    return setmetatable({ type = "list", default = items }, typed_mt)
end

--- A set of strings, the controller sends a list
--- @param items string[]
--- @return table<string, true>
function Feature.set(items)
    return setmetatable({ type = "set", default = list_to_set(items) }, typed_mt)
end

--- Features are enabled unless the config says otherwise
--- @param name string
--- @param config table?
--- @return ExpScenario.Feature feature
--- @return table config
function Feature.register(name, config)
    assert(Feature._registered[name] == nil, "Feature already registered: " .. name)
    config = config or {}
    if config.enabled == nil then
        config.enabled = true
    end

    local fields = {}
    collect_fields(fields, config, "")

    local feature = setmetatable({
        name = name,
        config = config,
        fields = fields,
        values = {},
    }, Feature_mt) --[[@as ExpScenario.Feature]]

    Feature._registered[name] = feature
    return feature, config
end

--- @param name string
--- @return ExpScenario.Feature
function Feature.get(name)
    return Feature._registered[name] or error("Unknown feature: " .. tostring(name), 2)
end

--- @param field ExpScenario.FeatureField
--- @param value any
--- @return boolean
local function is_valid(field, value)
    if field.type == "list" or field.type == "set" then
        return is_string_list(value)
    end
    return type(value) == field.type and (field.type == "boolean" or field.type == "number" or field.type == "string")
end

--- Set a value, nil or an invalid value means the default
--- @package
--- @param field ExpScenario.FeatureField
--- @param value any
--- @return any # The value which was set
function Feature._prototype:_set_field(field, value)
    if value ~= nil and not is_valid(field, value) then
        log("[WARNING] Invalid value for " .. self.name .. "." .. field.path .. ", using the default")
        value = nil
    end
    if value == nil then
        value = field.default
    elseif field.type == "set" then
        value = list_to_set(value)
    end
    field.parent[field.key] = value
    return value
end

--- @return boolean
function Feature._prototype:is_enabled()
    return self.config.enabled
end

--- Make the event and on_nth_tick handlers of a lib do nothing while the feature is disabled
--- @generic T : table
--- @param lib T
--- @return T
function Feature._prototype:guard(lib)
    local config = self.config
    for _, handlers in pairs{ lib.events or {}, lib.on_nth_tick or {} } do
        for key, handler in pairs(handlers) do
            handlers[key] = function(event)
                if config.enabled then
                    return handler(event)
                end
            end
        end
    end

    return lib
end

--- Replace every value, then raise on_config_updated for each one which changed
--- @param values table<string, any> By path, "enabled" included
function Feature._prototype:update_config(values)
    self.values = values
    stored_values[self.name] = values

    local updates = {}
    for path, field in pairs(self.fields) do
        local old_value = field.parent[field.key]
        local new_value = self:_set_field(field, values[path])
        if not values_equal(old_value, new_value) then
            updates[#updates + 1] = { feature_name = self.name, path = path, old_value = old_value, new_value = new_value }
        end
    end

    for _, update in ipairs(updates) do
        script.raise_event(Feature.events.on_config_updated, update)
    end
end

--- @class ExpScenario.FeatureUpdate
--- @field name string
--- @field values table<string, any>

--- Called over rcon by the instance plugin, unknown features are ignored
--- @param updates ExpScenario.FeatureUpdate[]
function Feature.receive_update(updates)
    for _, update in ipairs(updates) do
        local feature = Feature._registered[update.name]
        if feature then
            feature:update_config(update.values)
        end
    end
end

return Feature
