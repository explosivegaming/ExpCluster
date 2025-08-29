--[[-- Commands - Teleport
Adds a command that allows players to teleport to other players and spawn
]]

local ExpUtil = require("modules/exp_util")
local teleport_player = ExpUtil.teleport_player

local Commands = require("modules/exp_commands")

local Roles = require("modules.exp_legacy.expcore.roles") --- @dep expcore.roles
local player_allowed = Roles.player_allowed

--- @class ExpCommands_Teleport.commands
local commands = {}

--- Teleports a player to another player.
--- @class ExpCommands_Teleport.commands.teleport: ExpCommand
--- @overload fun(player: LuaPlayer, other_player: LuaPlayer, target_player: LuaPlayer?)
commands.teleport = Commands.new("teleport", { "exp-commands_teleport.description-teleport" })
    :argument("player", { "exp-commands_teleport.arg-player-teleport" }, Commands.types.player_alive)
    :optional("target", { "exp-commands_teleport.arg-player-to" }, Commands.types.player_alive)
    :add_aliases{ "tp" }
    :add_flags{ "admin_only" }
    :register(function(player, other_player, target_player)
        --- @cast other_player LuaPlayer
        --- @cast target_player LuaPlayer?
        if target_player == nil then
            -- When no player is given, then instead behave like /goto
            if not teleport_player(player, other_player.physical_surface, other_player.physical_position) then
                return Commands.status.error{ "exp-commands_teleport.unavailable" }
            end
        elseif other_player == target_player then
            return Commands.status.invalid_input{ "exp-commands_teleport.same-player" }
        elseif not teleport_player(other_player, target_player.physical_surface, target_player.physical_position) then
            return Commands.status.error{ "exp-commands_teleport.unavailable" }
        end
    end) --[[ @as any ]]

--- Teleports a player to you.
--- @class ExpCommands_Teleport.commands.bring: ExpCommand
--- @overload fun(player: LuaPlayer, other_player: LuaPlayer)
commands.bring = Commands.new("bring", { "exp-commands_teleport.description-bring" })
    :argument("player", { "exp-commands_teleport.arg-player-from" }, Commands.types.player_alive)
    :add_flags{ "admin_only" }
    :register(function(player, other_player)
        --- @cast other_player LuaPlayer
        if player == other_player then
            return Commands.status.invalid_input{ "exp-commands_teleport.same-player" }
        elseif not teleport_player(other_player, player.physical_surface, player.physical_position) then
            return Commands.status.error{ "exp-commands_teleport.unavailable" }
        end
    end) --[[ @as any ]]

--- Teleports you to a player.
--- @class ExpCommands_Teleport.commands.goto: ExpCommand
--- @overload fun(player: LuaPlayer, other_player: LuaPlayer)
commands["goto"] = Commands.new("goto", { "exp-commands_teleport.description-goto" })
    :argument("player", { "exp-commands_teleport.arg-player-to" }, Commands.types.player_alive)
    :add_flags{ "admin_only" }
    :register(function(player, other_player)
        --- @cast other_player LuaPlayer
        if player == other_player then
            return Commands.status.invalid_input{ "exp-commands_teleport.same-player" }
        elseif not teleport_player(player, other_player.physical_surface, other_player.physical_position) then
            return Commands.status.error{ "exp-commands_teleport.unavailable" }
        end
    end) --[[ @as any ]]

--- Teleport to spawn
--- @class ExpCommands_Teleport.commands.spawn: ExpCommand
--- @overload fun(player: LuaPlayer, other_player: LuaPlayer)
commands.spawn = Commands.new("spawn", { "exp-commands_teleport.description-spawn" })
    :optional("player", { "exp-commands_teleport.arg-player-from" }, Commands.types.player_alive)
    :defaults{
        player = function(player)
            if player.character and player.character.health > 0 then
                return player
            end
        end,
    }
    :register(function(player, other_player)
        if not other_player then
            return Commands.status.error{ "exp-commands_teleport.unavailable" }
        elseif other_player == player then
            if not teleport_player(player, game.surfaces.nauvis, { 0, 0 }, "dismount") then
                return Commands.status.error{ "exp-commands_teleport.unavailable" }
            end
        elseif player_allowed(player, "command/spawn/always") then
            if not teleport_player(other_player, game.surfaces.nauvis, { 0, 0 }, "dismount") then
                return Commands.status.error{ "exp-commands_teleport.unavailable" }
            end
        else
            return Commands.status.unauthorised()
        end
    end) --[[ @as any ]]

return {
    commands = commands,
}
