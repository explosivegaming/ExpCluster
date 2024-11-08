--[[-- Commands Module - Tag
    - Adds a command that allows players to have a custom tag after their name
    @data Tag
]]

local Commands = require("modules/exp_commands")
local Roles = require("modules.exp_legacy.expcore.roles") --- @dep expcore.roles

--- Stores the tag for a player
local PlayerData = require("modules.exp_legacy.expcore.player_data") --- @dep expcore.player_data
local PlayerTags = PlayerData.Settings:combine("Tag")
local PlayerTagColors = PlayerData.Settings:combine("TagColor")
PlayerTags:set_metadata{
    permission = "command/tag",
}
PlayerTagColors:set_metadata{
    permission = "command/tag-color",
}

local set_tag = function(player, tag, color)
    if tag == nil or tag == "" then
        player.tag = ""
    elseif color then
        player.tag = "- [color=" .. color .. "]" .. tag .. "[/color]"
    else
        player.tag = "- " .. tag
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
Commands.new("tag", "Sets your player tag.")
    :argument("tag", "", Commands.types.string_max_length(20))
    :enable_auto_concatenation()
    :register(function(player, tag)
        --- @cast tag string
        PlayerTags:set(player, tag)
    end)

--- Sets your player tag color.
Commands.new("tag-color", "Sets your player tag color.")
    :argument("color", "", Commands.types.color)
    :enable_auto_concatenation()
    :register(function(player, color)
        --- @cast color Color
        PlayerTagColors:set(player, color)
    end)

--- Clears your tag. Or another player if you are admin.
Commands.new("tag-clear", "Clears your tag. Or another player if you are admin.")
    :optional("player", "", Commands.types.lower_role_player)
    :defaults{
        player = function(player) return player end
    }
    :register(function(player, other_player)
        --- @cast other_player LuaPlayer
        if other_player == player then
            -- No player given so removes your tag
            PlayerTags:remove(other_player)
        elseif Roles.player_allowed(player, "command/clear-tag/always") then
            -- Player given and user is admin so clears that player's tag
            PlayerTags:remove(other_player)
        else
            -- User is not admin and tried to clear another users tag
            return Commands.status.unauthorised()
        end
    end)
