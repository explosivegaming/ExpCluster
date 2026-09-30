--[[-- ExpScenario - Features
Features which the controller can enable, disable, and configure while the game is running

A feature's config is the table returned by Features.config. The controller sends
overrides over rcon, these are kept in storage and copied onto that same table,
so read values when they are used rather than copying them into locals when the
file loads. Values derived from the config can be rebuilt with Features.on_apply.

Booleans, numbers, strings, and lists of strings can be overridden, including
those in nested tables which are addressed as "section.key". Use Features.optional
for a value which has no default. Values used while the file loads, such as
on_nth_tick periods, stay as plain values and are not listed in features.ts.

--- Declaring a feature with config, small configs live at the top of the file which uses them:
local Features = require("modules/exp_scenario/features")
local config = Features.config("my_feature", {
    show_message = true,
    role_id = Features.optional("number"),
})

--- Handlers do nothing while the feature is disabled, a feature without config can be guarded by name:
return Features.guard(config, {
    events = { [defines.events.on_player_joined_game] = on_player_joined_game },
})

--- Toolbar buttons are hidden while disabled, which also hides their left element:
Gui.toolbar.create_button{
    visible = function(player, element) return Features.is_enabled("my_feature") end,
}

--- Commands are denied and left out of help while disabled:
Commands.new("my_command", { "..." }):add_flags{ feature = "my_feature" }
]]

local Storage = require("modules/exp_util/storage")

--- @class ExpScenario.Features
local Features = {
    events = {
        --- Raised when the controller changes a feature, gui and commands are refreshed by control/features.lua
        on_feature_changed = script.generate_event_name(),
    },
}

--- @class ExpScenario.FeatureConfig
--- @field enabled boolean

--- @alias ExpScenario.Feature string | ExpScenario.FeatureConfig

--- @class ExpScenario.FeatureField
--- @field parent table The table holding the value within the config
--- @field key string The key of the value within its parent
--- @field default any
--- @field type string "boolean", "number", "string", "list" of strings, or a type which can not be overridden

--- @class ExpScenario.Optional
--- @field __feature_optional string

--- The live config tables by feature name
local features = {} --- @type table<string, ExpScenario.FeatureConfig>

--- The values of each feature by feature name then path
local fields = {} --- @type table<string, table<string, ExpScenario.FeatureField>>

--- Called after a feature is applied by feature name
local on_apply = {} --- @type table<string, fun(config: table)[]>

--- Overrides received from the controller by feature name then path
local overrides = {} --- @type table<string, table<string, boolean | number | string | string[]>>

--- Check if a table is a list, empty tables count as lists
--- @param tbl table
--- @return boolean
local function is_list(tbl)
    return next(tbl) == nil or tbl[1] ~= nil
end

--- Check if a table is a list of strings, empty tables count as lists of strings
--- @param tbl table
--- @return boolean
local function is_string_list(tbl)
    if not is_list(tbl) then return false end
    for _, item in pairs(tbl) do
        if type(item) ~= "string" then return false end
    end
    return true
end

--- Check if an override can replace a field
--- @param field ExpScenario.FeatureField
--- @param value any
--- @return boolean
local function is_valid(field, value)
    if field.type == "list" then
        return type(value) == "table" and is_string_list(value)
    end
    return type(value) == field.type and (field.type == "boolean" or field.type == "number" or field.type == "string")
end

--- Reset a feature to its defaults and apply its overrides
--- @param name string
local function apply(name)
    local feature_overrides = overrides[name] or {}
    for path, field in pairs(fields[name]) do
        local value = feature_overrides[path]
        if value == nil then
            value = field.default
        elseif not is_valid(field, value) then
            log("[WARNING] Invalid override for " .. name .. "." .. path .. ", using the default")
            value = field.default
        end
        field.parent[field.key] = value
    end

    for _, callback in ipairs(on_apply[name]) do
        callback(features[name])
    end
end

Storage.register(overrides, function(tbl)
    overrides = tbl
    for name in pairs(features) do
        apply(name)
    end
end)

--- Mark a value as having no default, the argument is the type it can be overridden with
--- @param value_type "boolean" | "number" | "string" | "list"
--- @return any
function Features.optional(value_type)
    return { __feature_optional = value_type }
end

--- Collect the values of a config table, recursing into nested tables which are not lists
--- @param feature_fields table<string, ExpScenario.FeatureField>
--- @param tbl table
--- @param prefix string
local function collect_fields(feature_fields, tbl, prefix)
    for key, value in pairs(tbl) do
        if type(key) == "string" then
            local field = { parent = tbl, key = key, default = value, type = type(value) }
            if type(value) == "table" then
                if value.__feature_optional then
                    field.default = nil
                    field.type = value.__feature_optional
                    tbl[key] = nil
                elseif is_string_list(value) then
                    field.type = "list"
                elseif is_list(value) then
                    field.type = "table"
                else
                    collect_fields(feature_fields, value, prefix .. key .. ".")
                    field = nil
                end
            end
            if field then
                feature_fields[prefix .. key] = field
            end
        end
    end
end

--- Declare a feature and its config, features are enabled unless the config says otherwise
--- @generic T : table
--- @param name string
--- @param config T?
--- @return T
function Features.config(name, config)
    assert(features[name] == nil, "Feature already declared: " .. name)
    config = config or {} --[[@as T]]
    if config.enabled == nil then
        config.enabled = true
    end

    local feature_fields = {}
    collect_fields(feature_fields, config, "")

    features[name] = config
    fields[name] = feature_fields
    on_apply[name] = {}
    return config
end

--- Get the config of a feature from its name, or return the config given
--- @param feature ExpScenario.Feature
--- @return ExpScenario.FeatureConfig
local function resolve(feature)
    if type(feature) == "table" then
        return feature
    end
    return features[feature] or error("Unknown feature: " .. tostring(feature), 3)
end

--- Get the name of a feature from its config, or return the name given
--- @param feature ExpScenario.Feature
--- @return string
local function resolve_name(feature)
    if type(feature) == "string" then
        return feature
    end
    for name, config in pairs(features) do
        if config == feature then
            return name
        end
    end
    error("Unknown feature config", 3)
end

--- Check if a feature is enabled
--- @param feature ExpScenario.Feature
--- @return boolean
function Features.is_enabled(feature)
    return resolve(feature).enabled
end

--- Call a function now and whenever the config of a feature changes, used to rebuild values derived from it
-- Also called during on_load, so it must only change locals and not the game state
--- @param feature ExpScenario.Feature
--- @param callback fun(config: any)
function Features.on_apply(feature, callback)
    local name = resolve_name(feature)
    table.insert(on_apply[name], callback)
    callback(features[name])
end

--- Make the event and on_nth_tick handlers of an event handler lib do nothing while the feature is disabled
-- A name which has not been declared is declared without config
--- @generic T : table
--- @param feature ExpScenario.Feature
--- @param lib T
--- @return T
function Features.guard(feature, lib)
    if type(feature) == "string" and features[feature] == nil then
        Features.config(feature)
    end
    local config = resolve(feature)

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

--- @class ExpScenario.FeatureUpdate
--- @field name string
--- @field enabled boolean
--- @field values table<string, boolean | number | string | string[]>

--- Called over rcon by the instance plugin with the features which changed, unknown features are ignored
--- @param updates ExpScenario.FeatureUpdate[]
function Features.receive_update(updates)
    for _, update in ipairs(updates) do
        local name = update.name
        local feature_fields = fields[name]
        if feature_fields then
            local override = { enabled = update.enabled }
            for path, value in pairs(update.values) do
                if feature_fields[path] == nil then
                    log("[WARNING] Unknown override for " .. name .. "." .. path)
                end
                override[path] = value
            end

            overrides[name] = override
            apply(name)
            script.raise_event(Features.events.on_feature_changed, { feature_name = name })
        end
    end
end

return Features
