--[[-- Commands Module - Tag
    - Adds a command that allows players to have a custom tag after their name
    @data Tag
]]

local Commands = require 'expcore.commands' --- @dep expcore.commands
local Roles = require 'expcore.roles' --- @dep expcore.roles
require 'config.expcore.command_general_parse'
require 'config.expcore.command_role_parse'
require 'config.expcore.command_color_parse'

--- Stores the tag for a player
local PlayerData = require 'expcore.player_data' --- @dep expcore.player_data
local PlayerTags = PlayerData.Settings:combine('Tag')
local PlayerTagColors = PlayerData.Settings:combine('TagColor')
PlayerTags:set_metadata{
    permission = 'command/tag'
}
PlayerTagColors:set_metadata{
    permission = 'command/tag-color'
}

local set_tag = function (player, tag, color)
    if tag == nil or tag == '' then
        player.tag = ''
    elseif color then
        player.tag = '- [color='.. color ..']'..tag..'[/color]'
    else
        player.tag = '- '..tag
    end
end

--- When your tag is updated then apply the changes
PlayerTags:on_update(function(player_name, player_tag)
    local player = game.players[player_name]
    local player_tag_color = PlayerTagColors:get(player)

    set_tag(player, player_tag, player_tag_color)
end)

--- When your tag color is updated then apply the changes
PlayerTagColors:on_update(function(player_name, player_tag_color)
    local player = game.players[player_name]
    local player_tag = PlayerTags:get(player)

    set_tag(player, player_tag, player_tag_color)
end)

--- Sets your player tag.
-- @command tag
-- @tparam string tag the tag that will be after the name, there is a max length
Commands.new_command('tag', {'expcom-tag.description'}, 'Sets your player tag.')
:add_param('tag', false, 'string-max-length', 20)
:enable_auto_concat()
:register(function(player, tag)
    PlayerTags:set(player, tag)
end)

--- Sets your player tag color.
-- @command tag
-- @tparam string color name.
Commands.new_command('tag-color', 'Sets your player tag color.')
:add_param('color', false, 'color')
:enable_auto_concat()
:register(function(player, color)
    PlayerTagColors:set(player, color)
end)

--- Clears your tag. Or another player if you are admin.
-- @command tag-clear
-- @tparam[opt=self] LuaPlayer player the player to remove the tag from, nil will apply to self
Commands.new_command('tag-clear', {'expcom-tag.description-clear'}, 'Clears your tag. Or another player if you are admin.')
:add_param('player', true, 'player-role')
:set_defaults{player=function(player)
    return player -- default is the user using the command
end}
:register(function(player, action_player)
    if action_player.index == player.index then
        -- no player given so removes your tag
        PlayerTags:remove(action_player)

    elseif Roles.player_allowed(player, 'command/clear-tag/always') then
        -- player given and user is admin so clears that player's tag
        PlayerTags:remove(action_player)

    else
        -- user is not admin and tried to clear another users tag
        return Commands.error{'expcore-commands.unauthorized'}
    end
end)
