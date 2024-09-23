--- Kicks players when all players on the server are afk
-- @addon afk-kick

local Event = require 'utils.event' --- @dep utils.event
local Global = require 'utils.global' --- @dep utils.global
local config = require 'config.afk_kick' --- @dep config.afk_kick
local Async = require 'expcore.async' --- @dep expcore.async

--- Optional roles require
local Roles
if config.active_role then
    Roles = require 'expcore.roles'
end

--- Globals
local primitives = { last_active = 0 }
Global.register(primitives, function(tbl)
    primitives = tbl
end)

--- Kicks an afk player, used to add a delay so the gui has time to appear
local kick_player =
Async.register(function(player)
    if game.tick - primitives.last_active < config.kick_time then return end -- Safety Catch
    game.kick_player(player, 'AFK while no active players on the server')
end)

--- Check for an active player every update_time number of ticks
Event.on_nth_tick(config.update_time, function()
    -- Check for active players
    for _, player in ipairs(game.connected_players) do
        if player.afk_time < config.afk_time
        or config.admin_as_active and player.admin
        or config.trust_as_active and player.online_time > config.trust_time
        or config.active_role and (Roles.get_player_highest_role(player).index >= Roles.get_role_from_any(config.active_role).index) then
            -- Active player was found
            primitives.last_active = game.tick
            return
        end
    end

    -- No active player was found, check if players should be kicked
    if game.tick - primitives.last_active < config.kick_time then return end

    -- Kick time exceeded, kick all players
    for _, player in ipairs(game.connected_players) do
        -- Add a frame to say why the player was kicked
        local res = player.display_resolution
        local uis = player.display_scale
        player.gui.screen.add{
            type = 'frame',
            name = 'afk-kick',
            caption = {'afk-kick.message'},
        }.location = { x=res.width*(0.5 - 0.11*uis), y=res.height*(0.5 - 0.14*uis) }

        -- Kick the player, some delay needed because network delay
        Async.wait(10, kick_player, player)
    end
end)

--- Remove the screen gui if it is present
Event.add(defines.events.on_player_joined_game, function(event)
    local player = game.get_player(event.player_index)
    local frame = player.gui.screen["afk-kick"]
    if frame and frame.valid then frame.destroy() end
end)
