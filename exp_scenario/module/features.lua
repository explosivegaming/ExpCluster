--[[-- ExpScenario - Features
Features which the controller can enable, disable, and configure while the game is running

A feature's config table is changed in place when the controller sends overrides,
so read values when they are used rather than copying them into locals when the
file loads. Booleans, numbers, and strings can be overridden, as can lists and
sets of strings made with Feature.list and Feature.set, and values with no default
made with Feature.optional. Tables with string keys are nested sections whose
values are addressed as "section.key", other tables can not be overridden. Values used while the file
loads, such as on_nth_tick periods, stay as plain values and are not listed in
features.ts.

--- Registering a feature, small configs live at the top of the file which uses them:
local Feature = require("modules/exp_scenario/features")
local feature = Feature.register("my_feature", {
    show_message = true,
    role_id = Feature.optional("number"),
    item_names = Feature.set{ "iron-plate" },
    surface_names = Feature.list{ "nauvis" },
})
local config = feature.config

--- Handlers do nothing while the feature is disabled:
return feature:guard{
    events = { [defines.events.on_player_joined_game] = on_player_joined_game },
}

--- Toolbar buttons are hidden while disabled, which also hides their left element:
Gui.toolbar.create_button{
    visible = function(player, element) return feature:is_enabled() end,
}

--- Commands are denied and left out of help while disabled:
Commands.new("my_command", { "..." }):add_flags{ feature = feature }

--- Sets are kept as sets, the controller sends a list which is converted when it is applied:
if config.item_names[item.name] then end

--- Changes are raised per value:
[Feature.events.on_config_updated] = function(event) end, -- { feature_name, path, old_value, new_value }
]]

local Storage = require("modules/exp_util/storage")

--- @class ExpScenario.FeatureField
--- @field parent table The table holding the value within the config
--- @field key string The key of the value within its parent
--- @field default any
--- @field type string "boolean", "number", "string", "list" or "set" of strings, or a type which can not be overridden

--- @class ExpScenario.Feature
--- @field name string
--- @field config table Changed in place when the config is updated
--- @field fields table<string, ExpScenario.FeatureField> The values in the config by path
--- @field overrides table<string, any> The overrides from the controller by path, restored from storage on load
local Feature = {
    _registered = {}, --- @type table<string, ExpScenario.Feature>
    events = {
        --- Raised for each value which changes when the controller updates a feature
        --- @type EventData.ExpScenario.on_config_updated
        on_config_updated = script.generate_event_name(),
    },
}

--- @class EventData.ExpScenario.on_config_updated : EventData
--- @field feature_name string
--- @field path string The path of the value within the config, "enabled" when the feature is enabled or disabled
--- @field old_value any
--- @field new_value any

local Feature_mt = {
    __index = Feature,
}

--- The overrides of each feature by name, only these are stored because the rest is rebuilt when the file loads
local stored_overrides = {} --- @type table<string, table<string, any>>
Storage.register(stored_overrides, function(tbl)
    stored_overrides = tbl
    for name, feature in pairs(Feature._registered) do
        feature.overrides = tbl[name] or {}
        feature:_apply()
    end
end)

--- Check if a value is a list of strings, as sent by the controller for lists and sets
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

--- Check if two values are equal, lists and sets are compared by their contents
--- @param a any
--- @param b any
--- @return boolean
local function values_equal(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for key, value in pairs(a) do
        if b[key] ~= value then return false end
    end
    for key in pairs(b) do
        if a[key] == nil then return false end
    end
    return true
end

--- Marks a default made by Feature.list, Feature.set, or Feature.optional with the type of the field
local typed_mt = {}

--- Convert a list of strings into a set
--- @param list string[]
--- @return table<string, true>
local function list_to_set(list)
    local set = {}
    for _, item in ipairs(list) do
        set[item] = true
    end
    return set
end

--- Collect the values of a config table, recursing into nested sections
--- @param fields table<string, ExpScenario.FeatureField>
--- @param tbl table
--- @param prefix string
local function collect_fields(fields, tbl, prefix)
    for key, value in pairs(tbl) do
        if type(key) == "string" then
            local field = { parent = tbl, key = key, default = value, type = type(value) }
            if type(value) == "table" then
                local typed = getmetatable(value) == typed_mt and value
                if typed then
                    field.type = typed.type
                    field.default = typed.default
                    tbl[key] = typed.default
                elseif type(next(value)) == "string" then
                    collect_fields(fields, value, prefix .. key .. ".")
                    field = nil
                end
            end
            if field then
                fields[prefix .. key] = field
            end
        end
    end
end

--- Declare a value with no default, the argument is the type it can be overridden with
--- @param value_type "boolean" | "number" | "string"
--- @return any
function Feature.optional(value_type)
    return setmetatable({ type = value_type }, typed_mt)
end

--- Declare a list of strings which can be overridden
--- @param items string[]
--- @return string[]
function Feature.list(items)
    return setmetatable({ type = "list", default = items }, typed_mt)
end

--- Declare a set of strings which can be overridden, the controller sends a list which is converted when applied
--- @param items string[]
--- @return table<string, true>
function Feature.set(items)
    return setmetatable({ type = "set", default = list_to_set(items) }, typed_mt)
end

--- Register a feature and its config, features are enabled unless the config says otherwise
--- @param name string
--- @param config table?
--- @return ExpScenario.Feature
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
        overrides = {},
    }, Feature_mt) --[[@as ExpScenario.Feature]]

    Feature._registered[name] = feature
    return feature
end

--- Get a registered feature by name
--- @param name string
--- @return ExpScenario.Feature
function Feature.get(name)
    return Feature._registered[name] or error("Unknown feature: " .. tostring(name), 2)
end

--- Check if a field can take a value
--- @param field ExpScenario.FeatureField
--- @param value any
--- @return boolean
local function is_valid(field, value)
    if field.type == "list" or field.type == "set" then
        return is_string_list(value)
    end
    return type(value) == field.type and (field.type == "boolean" or field.type == "number" or field.type == "string")
end

--- Set every value to its override, or its default when there is no valid override
--- @package
function Feature:_apply()
    for path, field in pairs(self.fields) do
        local value = self.overrides[path]
        if value == nil then
            value = field.default
        elseif not is_valid(field, value) then
            log("[WARNING] Invalid override for " .. self.name .. "." .. path .. ", using the default")
            value = field.default
        elseif field.type == "set" then
            value = list_to_set(value)
        end
        field.parent[field.key] = value
    end
end

--- Check if the feature is enabled
--- @return boolean
function Feature:is_enabled()
    return self.config.enabled
end

--- Make the event and on_nth_tick handlers of an event handler lib do nothing while the feature is disabled
--- @generic T : table
--- @param lib T
--- @return T
function Feature:guard(lib)
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

--- Replace the overrides of the feature, then raise on_config_updated for each value which changed
--- @param enabled boolean
--- @param values table<string, boolean | number | string | string[]>
function Feature:update_config(enabled, values)
    local overrides = { enabled = enabled }
    for path, value in pairs(values) do
        if self.fields[path] == nil then
            log("[WARNING] Unknown override for " .. self.name .. "." .. path)
        end
        overrides[path] = value
    end

    local old_values = {}
    for path, field in pairs(self.fields) do
        old_values[path] = field.parent[field.key]
    end

    self.overrides = overrides
    stored_overrides[self.name] = overrides
    self:_apply()

    for path, field in pairs(self.fields) do
        local new_value = field.parent[field.key]
        if not values_equal(old_values[path], new_value) then
            script.raise_event(Feature.events.on_config_updated, {
                feature_name = self.name,
                path = path,
                old_value = old_values[path],
                new_value = new_value,
            })
        end
    end
end

--- @class ExpScenario.FeatureUpdate
--- @field name string
--- @field enabled boolean
--- @field values table<string, boolean | number | string | string[]>

--- Called over rcon by the instance plugin with the features which changed, unknown features are ignored
--- @param updates ExpScenario.FeatureUpdate[]
function Feature.receive_update(updates)
    for _, update in ipairs(updates) do
        local feature = Feature._registered[update.name]
        if feature then
            feature:update_config(update.enabled, update.values)
        end
    end
end

return Feature
