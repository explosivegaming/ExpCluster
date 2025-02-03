--[[-- Commands - Cheats
Adds commands for cheating such as unlocking all technology or settings always day
]]

local Commands = require("modules/exp_commands")
local format_player_name = Commands.format_player_name_locale

--- Toggles cheat mode for your player, or another player.
Commands.new("set-cheat-mode", { "exp-commands_cheat.description-cheat-mode" })
    :optional("state", { "exp-commands_cheat.arg-state" }, Commands.types.boolean)
    :optional("player", { "exp-commands_cheat.arg-player" }, Commands.types.player)
    :add_aliases{ "cheat-mode", "toggle-cheat-mode" }
    :add_flags{ "admin_only" }
    :defaults{
        player = function(player) return player end,
    }
    :register(function(player, state, other_player)
        --- @cast state boolean?
        --- @cast player LuaPlayer
        if state == nil then
            other_player.cheat_mode = not other_player.cheat_mode
        else
            other_player.cheat_mode = state
        end
        return Commands.status.success{ "exp-commands_cheat.cheat-mode", other_player.cheat_mode }
    end)

--- Toggle always day for your surface, or another
Commands.new("set-always-day", { "exp-commands_cheat.description-always-day" })
    :optional("state", { "exp-commands_cheat.arg-state" }, Commands.types.boolean)
    :optional("surface", { "exp-commands_cheat.arg-surface" }, Commands.types.surface)
    :add_aliases{ "always-day", "toggle-always-day" }
    :add_flags{ "admin_only" }
    :defaults{
        surface = function(player) return player.surface end
    }
    :register(function(player, state, surface)
        --- @cast state boolean?
        --- @cast surface LuaSurface
        if state == nil then
            surface.always_day = not surface.always_day
        else
            surface.always_day = state
        end
        game.print{ "exp-commands_cheat.always-day", format_player_name(player), surface.name, surface.always_day }
    end)

--- Toggles friendly fire for your force or another
Commands.new("set-friendly-fire", { "exp-commands_cheat.description-friendly-fire" })
    :optional("state", { "exp-commands_cheat.arg-state" }, Commands.types.boolean)
    :optional("force", { "exp-commands_cheat.arg-force-friendly-fire" }, Commands.types.force)
    :add_aliases{ "friendly-fire", "toggle-friendly-fire" }
    :add_flags{ "admin_only" }
    :defaults{
        force = function(player) return player.force end
    }
    :register(function(player, state, force)
        --- @cast state boolean?
        --- @cast force LuaForce
        if state == nil then
            force.friendly_fire = not force.friendly_fire
        else
            force.friendly_fire = state
        end
        game.print{ "exp-commands_cheat.friendly-fire", format_player_name(player), force.name, force.friendly_fire }
    end)

--- Research all technology on your force, or another force.
Commands.new("research-all", { "exp-commands_cheat.description-research-all" })
    :optional("force", { "exp-commands_cheat.arg-force-research" }, Commands.types.force)
    :add_flags{ "admin_only" }
    :defaults{
        force = function(player) return player.force end
    }
    :register(function(player, force)
        --- @cast force LuaForce
        force.research_all_technologies()
        game.print{ "exp-commands_cheat.research-all", format_player_name(player), force.name }
        return Commands.status.success()
    end)

--- Clear all pollution from your surface or another
Commands.new("clear-pollution", { "exp-commands_cheat.description-clear-pollution" })
    :optional("surface", { "exp-commands_cheat.arg-surface" }, Commands.types.surface)
    :add_flags{ "admin_only" }
    :defaults{
        surface = function(player) return player.surface end -- Allow remote view
    }
    :register(function(player, surface)
        --- @cast surface LuaSurface
        surface.clear_pollution()
        game.print{ "exp-commands_cheat.clear-pollution", format_player_name(player), surface.name }
    end)

--- Toggles pollution being enabled in the game
Commands.new("set-pollution-enabled", { "exp-commands_cheat.description-pollution-enabled" })
    :optional("state", { "exp-commands_cheat.arg-state" }, Commands.types.boolean)
    :add_aliases{ "disable-pollution", "toggle-pollution-enabled" }
    :add_flags{ "admin_only" }
    :register(function(player, state)
        --- @cast state boolean?
        if state == nil then
            game.map_settings.pollution.enabled = not game.map_settings.pollution.enabled
        else
            game.map_settings.pollution.enabled = state
        end

        if game.map_settings.pollution.enabled == false then
            for _, surface in pairs(game.surfaces) do
                surface.clear_pollution()
            end
        end

        game.print{ "exp-commands_cheat.pollution-enabled", format_player_name(player), game.map_settings.pollution.enabled }
    end)

--- Set or get the game speed
Commands.new("set-game-speed", { "exp-commands_cheat.description-game-speed" })
    :optional("amount", { "exp-commands_cheat.arg-amount" }, Commands.types.number_range(0.2, 10))
    :add_aliases{ "game-speed" }
    :add_flags{ "admin_only" }
    :register(function(player, amount)
        --- @cast amount number?
        if amount then
            game.speed = math.round(amount, 3)
            local player_name = format_player_name(player)
            game.print{ "exp-commands_cheat.game-speed-set", player_name, game.speed }
            return Commands.status.success()
        else
            return Commands.status.success{ "exp-commands_cheat.game-speed-get", game.speed }
        end
    end)
