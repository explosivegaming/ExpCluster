--[[-- ExpScenario - Features
Features which the controller can enable, disable, and configure while the game is running

A feature's config is the table returned by Features.config. The controller sends
overrides over rcon, these are kept in storage and copied onto that same table,
so read values when they are used rather than copying them into locals when the
file loads. Only boolean, number, and string defaults can be overridden.

Values used while the file loads can not change without a restart. Periods can
use intervals instead of on_nth_tick, everything else such as toolbar sprites
stays as a plain value and is not listed in features.ts.

--- Declaring a feature with config, small configs live at the top of the file which uses them:
local Features = require("modules/exp_scenario/features")
local config = Features.config("my_feature", {
    show_message = true,
    check_seconds = 60,
})

--- Handlers do nothing while the feature is disabled, a feature without config can be guarded by name:
return Features.guard(config, {
    events = { [defines.events.on_player_joined_game] = on_player_joined_game },
    intervals = { check_seconds = check_players }, -- Runs every config.check_seconds seconds
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

local overridable = {
    boolean = true,
    number = true,
    string = true,
}

--- @class ExpScenario.FeatureConfig
--- @field enabled boolean

--- @alias ExpScenario.Feature string | ExpScenario.FeatureConfig

--- The live config tables by feature name
local features = {} --- @type table<string, ExpScenario.FeatureConfig>

--- Copies of the defaults by feature name, used to undo overrides
local defaults = {} --- @type table<string, table<string, any>>

--- Overrides received from the controller by feature name
local overrides = {} --- @type table<string, table<string, boolean | number | string>>

--- Reset a feature to its defaults and apply its overrides
--- @param name string
local function apply(name)
    local config = features[name]
    local feature_defaults = defaults[name]
    for key, value in pairs(feature_defaults) do
        config[key] = value
    end

    for key, value in pairs(overrides[name] or {}) do
        local default = feature_defaults[key]
        if default ~= nil and type(value) == type(default) and overridable[type(value)] then
            config[key] = value
        end
    end
end

Storage.register(overrides, function(tbl)
    overrides = tbl
    for name in pairs(features) do
        apply(name)
    end
end)

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

    local feature_defaults = {}
    for key, value in pairs(config) do
        feature_defaults[key] = value
    end

    features[name] = config
    defaults[name] = feature_defaults
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

--- Check if a feature is enabled
--- @param feature ExpScenario.Feature
--- @return boolean
function Features.is_enabled(feature)
    return resolve(feature).enabled
end

--- Make the handlers of an event handler lib do nothing while the feature is disabled
-- A name which has not been declared is declared without config. The intervals field
-- maps config keys to handlers, each runs every config[key] seconds, checked once a second
--- @generic T : table
--- @param feature ExpScenario.Feature
--- @param lib T
--- @return T
function Features.guard(feature, lib)
    if type(feature) == "string" and features[feature] == nil then
        Features.config(feature)
    end
    local config = resolve(feature)

    local intervals = lib.intervals
    if intervals then
        lib.intervals = nil
        lib.on_nth_tick = lib.on_nth_tick or {}
        local every_second = lib.on_nth_tick[60]
        lib.on_nth_tick[60] = function(event)
            if every_second then
                every_second(event)
            end
            -- Exactly one check each period lands within its first second
            local tick = event.tick
            for key, handler in pairs(intervals) do
                if tick % (config[key] * 60) < 60 then
                    handler(event)
                end
            end
        end
    end

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
--- @field values table<string, boolean | number | string>

--- Called over rcon by the instance plugin with the features which changed, unknown features are ignored
--- @param updates ExpScenario.FeatureUpdate[]
function Features.receive_update(updates)
    for _, update in ipairs(updates) do
        local name = update.name
        if features[name] then
            local override = { enabled = update.enabled }
            for key, value in pairs(update.values) do
                override[key] = value
            end

            overrides[name] = override
            apply(name)
            script.raise_event(Features.events.on_feature_changed, { feature_name = name })
        end
    end
end

return Features
