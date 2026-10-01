--[[-- Control - Features
Refreshes the gui of every player when a feature is enabled or disabled, see features.lua
]]

local Feature = require("modules/exp_scenario/features")
local Gui = require("modules/exp_gui")

--- Toolbar buttons of disabled features are hidden, which also hides their left elements
--- @param event EventData.ExpScenario.on_config_updated
local function on_config_updated(event)
    if event.path ~= "enabled" then return end
    for _, player in pairs(game.connected_players) do
        Gui._ensure_consistency{ player_index = player.index }
    end
end

return {
    events = {
        [Feature.events.on_config_updated] = on_config_updated,
    },
}
