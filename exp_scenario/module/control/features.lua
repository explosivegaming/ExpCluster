--[[-- Control - Features
Refreshes the gui of every player when a feature is enabled or disabled, see features.lua
]]

local Features = require("modules/exp_scenario/features")
local Gui = require("modules/exp_gui")

--- Toolbar buttons of disabled features are hidden, which also hides their left elements
local function on_feature_changed()
    for _, player in pairs(game.connected_players) do
        Gui._ensure_consistency{ player_index = player.index }
    end
end

return {
    events = {
        [Features.events.on_feature_changed] = on_feature_changed,
    },
}
