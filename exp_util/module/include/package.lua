-- luacheck:ignore global package

--- Enum values for the different lifecycle stages within a factorio module
-- Info on the data lifecycle and how we use it: https://lua-api.factorio.com/latest/auxiliary/data-lifecycle.html
-- We start in control stage and so values 1 thorough 3 are only present for completeness
package.lifecycle_stage = {
    settings = 1,
    data = 2,
    migration = 3,
    control = 4,
    init = 5,
    load = 6,
    config_change = 7,
    runtime = 8,
}

--- Stores the current lifecycle stage we are in, compare values against package.lifecycle_stage
--- See also: https://forums.factorio.com/viewtopic.php?f=28&t=115622
package.lifecycle = package.lifecycle_stage.control

return setmetatable({
    on_init = function() package.lifecycle = package.lifecycle_stage.init end,
    on_load = function() package.lifecycle = package.lifecycle_stage.load end,
    on_configuration_changed = function() package.lifecycle = package.lifecycle_stage.config_change end,
    events = {
        [defines.events.on_player_joined_game] = function() package.lifecycle = package.lifecycle_stage.runtime end,
        [defines.events.on_singleplayer_init] = function() package.lifecycle = package.lifecycle_stage.runtime end,
        [defines.events.on_multiplayer_init] = function() package.lifecycle = package.lifecycle_stage.runtime end,
    },
}, {
    __index = package,
})
