--[[-- Commands - Sudo
System command to execute a command as another player using their permissions (except for permissions group actions)

--- Run the example command as another player
-- As Cooldude2606: /repeat 5
/_system-sudo Cooldude2606 repeat 5
]]

local Commands = require("modules/exp_commands")

Commands.new("_sudo", { "exp-commands_sudo.description" })
    :argument("player", { "exp-commands_sudo.arg-player" }, Commands.types.player)
    :argument("command", { "exp-commands_sudo.arg-command" }, Commands.types.key_of(Commands.registered_commands))
    :optional("arguments", { "exp-commands_sudo.arg-arguments" }, Commands.types.string)
    :enable_auto_concatenation()
    :add_flags{ "system_only" }
    :register(function(_player, player, command, parameter)
        --- @cast player LuaPlayer
        --- @cast command ExpCommand
        --- @cast parameter string

        --- @diagnostic disable-next-line: invisible
        return Commands._event_handler{
            name = command.name,
            tick = game.tick,
            player_index = player.index,
            parameter = parameter,
        }
    end)
