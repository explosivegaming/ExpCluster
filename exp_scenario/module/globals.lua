--- @diagnostic disable: global-in-non-module

-- Access using `/sc exp_scenario.features.foo()`
exp_scenario = {
    features = require("modules/exp_scenario/features"),
    player_settings = require("modules/exp_scenario/control/player_settings"),
}
