--[[-- ExpScenario - Features
Feature config which the controller can change while the game is running

Each feature declares its defaults in config/<name>.lua by returning the table
from Features.register. The controller sends overrides over rcon, these are kept
in storage and copied onto that same table, so read values when they are used
rather than copying them into locals when the file loads.

Only boolean, number, and string defaults can be overridden. Values used while
the file loads, such as on_nth_tick periods, can not change without a restart
and should not be listed in features.ts.

--- Declaring a feature:
local Features = require("modules/exp_scenario/features")
return Features.register("my_feature", {
    show_message = true,
})

--- Using it from a control file, handlers do nothing while it is disabled:
local config = require("modules/exp_scenario/config/my_feature")
return Features.guard(config, {
    events = { [defines.events.on_player_joined_game] = on_player_joined_game },
})
]]

local Storage = require("modules/exp_util/storage")

--- @class ExpScenario.Features
local Features = {}

local overridable = {
    boolean = true,
    number = true,
    string = true,
}

--- @class ExpScenario.FeatureConfig
--- @field enabled boolean

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

--- Register a feature and its defaults, features are enabled unless the defaults say otherwise
--- @generic T : table
--- @param name string
--- @param config T
--- @return T
function Features.register(name, config)
    assert(features[name] == nil, "Feature already registered: " .. name)
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

--- Wrap the event and on_nth_tick handlers of an event handler lib so they do nothing while the feature is disabled
--- @generic T : table
--- @param config ExpScenario.FeatureConfig
--- @param lib T
--- @return T
function Features.guard(config, lib)
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
        end
    end
end

return Features
