--- Popups for chat and damage, shared by control/chat_popup.lua and control/damage_popups.lua
-- @config Popups

local Features = require("modules/exp_scenario/features")

return Features.config("popups", {
    show_player_messages = true, --- @setting show_player_messages weather a message in chat will make a popup above them
    show_player_mentions = true, --- @setting show_player_mentions weather a mentioned player will have a popup when mentioned in chat
    show_player_damage = true, --- @setting show_player_damage weather to show damage done by players
    show_player_health = true, --- @setting show_player_health weather to show player health when attacked
    damage_location_variance = 0.8, --- @setting damage_location_variance how close to the eade of an entity the popups will appear
})
