--- Config to control when players items are removed, this is a list of event names that will trigger inventory clear
-- @config inventory_clear

local events = defines.events
return {
    events.on_player_banned,
    events.on_player_kicked,
    --events.on_player_left_game
}