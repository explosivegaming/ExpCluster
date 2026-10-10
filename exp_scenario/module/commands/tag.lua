--[[-- Commands - Tag
Adds commands to set the tag shown after your name, inventory sync keeps it between servers
]]

local Commands = require("modules/exp_commands")
local format_text = Commands.format_rich_text_color
local Roles = require("modules/exp_roles")
local player_has_permission = Roles.player_has_permission

--- Split a player tag into its text and colour
--- @param tag string
--- @return string, string?
local function parse_tag(tag)
    local color, text = tag:match("^%- %[color=([^%]]*)%](.*)%[/color%]$")
    if color then
        --- @cast text string
        return text, color
    end
    return tag:match("^%- (.*)$") or tag, nil
end

--- Sets your player tag
Commands.new("tag", { "exp-commands_tag.description" })
    :argument("tag", { "exp-commands_tag.arg-tag" }, Commands.types.string_max_length(20))
    :enable_auto_concatenation()
    :register(function(player, tag)
        --- @cast tag string
        local _, color = parse_tag(player.tag)
        if tag == "" then
            player.tag = ""
        elseif color then
            player.tag = "- [color=" .. color .. "]" .. tag .. "[/color]"
        else
            player.tag = "- " .. tag
        end
    end)

--- Sets your player tag colour
Commands.new("tag-color", { "exp-commands_tag.description-color" })
    :argument("color", { "exp-commands_tag.arg-color" }, Commands.types.color)
    :register(function(player, color)
        --- @cast color Color
        local text = parse_tag(player.tag)
        if text == "" then
            return Commands.status.error{ "exp-commands_tag.no-tag" }
        end
        player.tag = "- " .. format_text(text, color)
    end)

--- Clears your tag, or the tag of another player
Commands.new("tag-clear", { "exp-commands_tag.description-clear" })
    :optional("player", { "exp-commands_tag.arg-player" }, Commands.types.lower_role_player)
    :defaults{
        player = function(player) return player end
    }
    :register(function(player, other_player)
        --- @cast other_player LuaPlayer
        if other_player ~= player and not player_has_permission(player, "exp_scenario.command.tag_clear.always") then
            return Commands.status.unauthorised()
        end
        other_player.tag = ""
    end)
