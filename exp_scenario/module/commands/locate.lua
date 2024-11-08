--[[-- Commands - Locate
Adds a command that will return the last location of a player
]]

local Commands = require("modules/exp_commands")
local format_player_name = Commands.format_player_name_locale

local format = string.format

--- Open remote view at a players last location
Commands.new("locate", { "exp-commands_locate.description" })
    :add_aliases{ "last-location", "find" }
    :argument("player", { "exp-commands_locate.arg-player" }, Commands.types.player)
    :optional("remote", { "exp-commands_locate.arg-remote" }, Commands.types.boolean)
    :register(function(player, other_player, remote)
        --- @cast other_player LuaPlayer
        --- @cast remote boolean?
        local surface = other_player.physical_surface
        local position = other_player.physical_position
        if remote and other_player.controller_type == defines.controllers.remote then
            surface = other_player.surface
            position = other_player.position
        end

        if player.index > 0 then
            -- This check allows rcon to use the command
            player.set_controller{
                type = defines.controllers.remote,
                surface = surface,
                position = position,
            }
        end

        return Commands.status.success{
            "exp-commands_locate.response",
            format_player_name(other_player),
            format("%.1f", position.x),
            format("%.1f", position.y),
        }
    end)
