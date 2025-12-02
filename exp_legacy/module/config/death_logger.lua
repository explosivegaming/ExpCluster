--- This config controls what happens when a player dies mostly about map markers and item collection;
-- allow_teleport_to_body_command and allow_collect_bodies_command can be over ridden if command_auth_runtime_disable is present;
-- if not present then the commands will not be loaded into the game
-- @config Death-Logger

return {
    collect_corpses = true, --- @setting collect_corpses enables items being returned to the spawn point in chests upon corpse expiring
    show_map_markers = true, --- @setting show_map_markers shows markers on the map where bodies are
    clean_map_markers = false,
    include_time_of_death = true, --- @setting include_time_of_death weather to include the time of death on the map marker
    map_icon = nil, --- @setting map_icon the icon that the map marker shows; nil means no icon; format as a SingleID
    show_light_at_corpse = true, --- @setting show_light_at_corpse if a light should be rendered at the corpse
    show_line_to_corpse = true, --- @setting show_line_to_corpse if a line should be rendered from you to your corpse
    period_check_map_tags = 60 * 60 * 5,
}
