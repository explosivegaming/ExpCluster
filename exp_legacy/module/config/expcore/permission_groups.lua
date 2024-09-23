--- Use this file to add new permission groups to the game;
-- start with Permission_Groups.new_group('name');
-- then use either :allow_all() or :disallow_all() to set the default for non specified actions;
-- then use :allow{} and :disallow{} to specify certain actions to allow/disallow
-- @config Permission-Groups

--local Event = require 'utils.event' -- @dep utils.event
local Permission_Groups = require 'expcore.permission_groups' --- @dep expcore.permission_groups

Permission_Groups.new_group('Admin')
:allow_all()
:disallow{
    'add_permission_group', -- admin
    'delete_permission_group',
    'edit_permission_group',
    'import_permissions_string',
    'map_editor_action',
    'toggle_map_editor',
    'change_multiplayer_config',
    'set_heat_interface_mode',
    'set_heat_interface_temperature',
    'set_infinity_container_filter_item',
    'set_infinity_container_remove_unfiltered_items',
    'set_infinity_pipe_filter'
}

Permission_Groups.new_group('Trusted')
:allow_all()
:disallow{
    'add_permission_group', -- admin
    'delete_permission_group',
    'edit_permission_group',
    'import_permissions_string',
    'map_editor_action',
    'toggle_map_editor',
    'change_multiplayer_config',
    'set_heat_interface_mode',
    'set_heat_interface_temperature',
    'set_infinity_container_filter_item',
    'set_infinity_container_remove_unfiltered_items',
    'set_infinity_pipe_filter',
    'admin_action' -- trusted
}

Permission_Groups.new_group('Standard')
:allow_all()
:disallow{
    'add_permission_group', -- admin
    'delete_permission_group',
    'edit_permission_group',
    'import_permissions_string',
    'map_editor_action',
    'toggle_map_editor',
    'change_multiplayer_config',
    'set_heat_interface_mode',
    'set_heat_interface_temperature',
    'set_infinity_container_filter_item',
    'set_infinity_container_remove_unfiltered_items',
    'set_infinity_pipe_filter',
    'admin_action', -- trusted
    'change_programmable_speaker_alert_parameters', -- standard
    'drop_item',
    'set_auto_launch_rocket'
}

Permission_Groups.new_group('Guest')
:allow_all()
:disallow{
    'add_permission_group', -- admin
    'delete_permission_group',
    'edit_permission_group',
    'import_permissions_string',
    'map_editor_action',
    'toggle_map_editor',
    'change_multiplayer_config',
    'set_heat_interface_mode',
    'set_heat_interface_temperature',
    'set_infinity_container_filter_item',
    'set_infinity_container_remove_unfiltered_items',
    'set_infinity_pipe_filter',
    'admin_action', -- trusted
    'change_programmable_speaker_alert_parameters', -- standard
    'drop_item',
    'set_auto_launch_rocket',
    'change_programmable_speaker_parameters', -- guest
    'change_train_stop_station',
    --'deconstruct',
    'remove_cables',
    'remove_train_station',
    'reset_assembling_machine',
    'rotate_entity',
    'use_artillery_remote',
    'launch_rocket',
    'cancel_research',
    'activate_cut',
    'flush_opened_entity_fluid',
    'flush_opened_entity_specific_fluid'
}

Permission_Groups.new_group('Restricted')
:disallow_all()
:allow('write_to_console')

--[[ These events are used until a role system is added to make it easier for our admins

local trusted_time = 60*60*60*10 -- 10 hour
local standard_time = 60*60*60*3 -- 3 hour
local function assign_group(player)
    local current_group_name = player.permission_group and player.permission_group.name or 'None'
    if player.admin then
        Permission_Groups.set_player_group(player,'Admin')
    elseif player.online_time > trusted_time or current_group_name == 'Trusted' then
        Permission_Groups.set_player_group(player,'Trusted')
    elseif player.online_time > standard_time or current_group_name == 'Standard' then
        Permission_Groups.set_player_group(player,'Standard')
    else
        Permission_Groups.set_player_group(player,'Guest')
    end
end

Event.add(defines.events.on_player_joined_game,function(event)
    local player = game.players[event.player_index]
    assign_group(player)
end)

Event.add(defines.events.on_player_promoted,function(event)
    local player = game.players[event.player_index]
    assign_group(player)
end)

Event.add(defines.events.on_player_demoted,function(event)
    local player = game.players[event.player_index]
    assign_group(player)
end)

local check_interval = 60*60*15 -- 15 minutes
Event.on_nth_tick(check_interval,function(event)
    for _,player in pairs(game.connected_players) do
        assign_group(player)
    end
end)]]
