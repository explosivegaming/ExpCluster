--[[-- Commands Module - Admin Markers
    - Adds a command that creates map markers which can only be edited by admins
    @commands Admin-Markers
]]

local Commands = require 'expcore.commands' --- @dep expcore.commands
local Global = require 'utils.global' --- @dep utils.global
local Event = require 'utils.event' --- @dep utils.event

local admins = {} -- Stores all players in admin marker mode
local markers = {} -- Stores all admin markers

--- Global variables
Global.register({
    admins = admins,
    markers = markers
}, function(tbl)
    admins = tbl.admins
    markers = tbl.markers
end)

--- Toggle admin marker mode, can only be applied to yourself
-- @command admin-marker
Commands.new_command('admin-marker', {'expcom-admin-marker.description'}, 'Toggles admin marker mode, new markers can only be edited by admins')
:set_flag('admin_only')
:add_alias('am', 'admin-markers')
:register(function(player)
    if admins[player.name] then
        -- Exit admin mode
        admins[player.name] = nil
        return Commands.success{'expcom-admin-marker.exit'}
    else
        -- Enter admin mode
        admins[player.name] = true
        return Commands.success{'expcom-admin-marker.enter'}
    end
end)

--- Listen for new map markers being added, add admin marker if done by player in admin mode
Event.add(defines.events.on_chart_tag_added, function(event)
    if not event.player_index then return end
    local player = game.get_player(event.player_index)
    if not admins[player.name] then return end
    local tag = event.tag
    markers[tag.force.name..tag.tag_number] = true
    Commands.print({'expcom-admin-marker.place'}, nil, player)
end)

--- Listen for players leaving the game, leave admin mode to avoid unexpected admin markers
Event.add(defines.events.on_player_left_game, function(event)
    if not event.player_index then return end
    local player = game.get_player(event.player_index)
    admins[player.name] = nil
end)

--- Listen for tags being removed or edited, maintain tags edited by non admins
local function maintain_tag(event)
    local tag = event.tag
    if not event.player_index then return end
    if not markers[tag.force.name..tag.tag_number] then return end
    local player = game.get_player(event.player_index)
    if player.admin then
        -- Player is admin, tell them it was an admin marker
        Commands.print({'expcom-admin-marker.edit'}, nil, player)
    elseif event.name == defines.events.on_chart_tag_modified then
        -- Tag was modified, revert the changes
        tag.text = event.old_text
        tag.last_user = event.old_player
        if event.old_icon then tag.icon = event.old_icon end
        player.play_sound{path='utility/wire_pickup'}
        Commands.print({'expcom-admin-marker.revert'}, nil, player)
    else
        -- Tag was removed, remake the tag
        player.play_sound{path='utility/wire_pickup'}
        Commands.print({'expcom-admin-marker.revert'}, 'orange_red', player)
        local new_tag = tag.force.add_chart_tag(tag.surface, {
            last_user = tag.last_user,
            position = tag.position,
            icon = tag.icon,
            text = tag.text,
        })
        markers[tag.force.name..tag.tag_number] = nil
        markers[new_tag.force.name..new_tag.tag_number] = true
    end
end

Event.add(defines.events.on_chart_tag_modified, maintain_tag)
Event.add(defines.events.on_chart_tag_removed, maintain_tag)
