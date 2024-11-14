--[[-- Commands - Protected Tags
Adds a command that creates chart tags which can only be edited by admins
]]

local Commands = require("modules/exp_commands")
local Storage = require("modules/exp_util/storage")

--- Storage variables
local active_players = {} --- @type table<number, boolean> Stores all players in in protected mode
local map_tags = {} --- @type table<number, boolean> Stores all protected map tags

Storage.register({
    active_players = active_players,
    map_tags = map_tags,
}, function(tbl)
    active_players = tbl.active_players
    map_tags = tbl.map_tags
end)

--- Toggle admin marker mode, can only be applied to yourself
local cmd_protect_tag =
    Commands.new("protect-tag", { "exp-commands_tag-protection.description" })
    :add_aliases{ "ptag" }
    :add_flags{ "admin_only" }
    :register(function(player)
        if active_players[player.index] then
            active_players[player.index] = nil
            return Commands.status.success{ "exp-commands_tag-protection.exit" }
        else
            active_players[player.index] = true
            return Commands.status.success{ "exp-commands_tag-protection.enter" }
        end
    end)

--- When a player leaves the game, remove them from the active list
--- @param event EventData.on_player_left_game
local function on_player_left_game(event)
    active_players[event.player_index] = nil
end

--- Add a chart tag as protected if the player is in protected mode
--- @param event EventData.on_chart_tag_added
local function on_chart_tag_added(event)
    if not event.player_index then return end
    if not active_players[event.player_index] then return end

    local tag = event.tag
    local player = game.players[event.player_index]
    map_tags[tag.force.name .. tag.tag_number] = true
    player.print{ "exp-commands_tag-protection.create" }
end

--- Stop a tag from being edited or removed
--- @param event EventData.on_chart_tag_modified | EventData.on_chart_tag_removed
local function on_chart_tag_removed_or_modified(event)
    local tag = event.tag
    if not event.player_index then return end
    if not map_tags[tag.force.name .. tag.tag_number] then return end
    local player = game.players[event.player_index]

    -- Check if the player is in protected mode, and inform them that it was protected
    if active_players[event.player_index] then
        player.print{ "exp-commands_tag-protection.edit" }
        return
    end

    -- Check how the changes need to be reverted
    if event.name == defines.events.on_chart_tag_modified then
        -- Tag was modified, revert the changes
        tag.text = event.old_text
        tag.icon = event.old_icon
        tag.surface = event.old_surface
        tag.position = event.old_position
        if event.old_player_index then
            tag.last_user = game.players[event.old_player_index]
        else
            tag.last_user = nil
        end

    else
        -- Tag was removed, recreate the tag
        local new_tag =
            tag.force.add_chart_tag(tag.surface, {
                last_user = tag.last_user,
                position = tag.position,
                icon = tag.icon,
                text = tag.text,
            })

        --- @cast new_tag -nil
        map_tags[tag.force.name .. tag.tag_number] = nil
        map_tags[new_tag.force.name .. new_tag.tag_number] = true
    end

    if Commands.player_has_permission(player, cmd_protect_tag) then
        -- Player is not in protected mode, but has access to the command
        player.print({ "exp-commands_tag-protection.revert-has-access", cmd_protect_tag.name }, Commands.print_settings.error)
    else
        --- Player does not have access to protected mode
        player.print({ "exp-commands_tag-protection.revert-no-access" }, Commands.print_settings.error)
    end
end

local e = defines.events
return {
    events = {
        [e.on_chart_tag_added] = on_chart_tag_added,
        [e.on_player_left_game] = on_player_left_game,
        [e.on_chart_tag_modified] = on_chart_tag_removed_or_modified,
        [e.on_chart_tag_removed] = on_chart_tag_removed_or_modified,
    }
}
