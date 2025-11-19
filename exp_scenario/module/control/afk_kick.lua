--[[-- Control -- AFK Kick
Kicks players when all players on the server are afk
]]

local Async = require("modules/exp_util/async")
local Storage = require("modules/exp_util/storage")
local config = require("modules.exp_legacy.config.afk_kick")

--- @type { last_active: number }
local script_data = { last_active = 0 }
Storage.register(script_data, function(tbl)
    script_data = tbl
end)

--- Kicks an afk player, used to add a delay so the gui has time to appear
local afk_kick_player_async =
    Async.register(function(player)
        if game.tick - script_data.last_active < config.kick_time then return end
        game.kick_player(player, "AFK while no active players on the server")
    end)

--- Check if there is an active player
local function has_active_player()
    for _, player in ipairs(game.connected_players) do
        if player.afk_time < config.afk_time
        or config.admin_as_active and player.admin
        or config.trust_as_active and player.online_time > config.trust_time
        or config.custom_active_check and config.custom_active_check(player) then
            script_data.last_active = game.tick
            return true
        end
    end

    return false
end

--- Check for an active player every update_time number of ticks
local function check_afk_players()
    -- Check for active players
    if has_active_player() then return end

    -- Check if players should be kicked
    if game.tick - script_data.last_active < config.kick_time then return end

    -- Kick time exceeded, kick all players
    for _, player in ipairs(game.connected_players) do
        -- Add a frame to say why the player was kicked
        local frame = player.gui.screen.add{
            type = "frame",
            name = "afk-kick",
            caption = { "exp_afk-kick.kick-message" },
        }

        local uis = player.display_scale
        local res = player.display_resolution
        frame.location = {
            x = res.width * (0.5 - 0.11 * uis),
            y = res.height * (0.5 - 0.14 * uis),
        }

        -- Kick the player, some delay needed allow the gui to show
        afk_kick_player_async:start_after(60, player)
    end
end

--- Remove the screen gui if it is present
--- @param event EventData.on_player_joined_game
local function on_player_joined_game(event)
    local player = assert(game.get_player(event.player_index))
    local frame = player.gui.screen["afk-kick"]
    if frame and frame.valid then frame.destroy() end
end

local e = defines.events

return {
    events = {
        [e.on_player_joined_game] = on_player_joined_game,
    },
    on_nth_tick = {
        [config.update_time] = check_afk_players,
    },
    has_active_player = has_active_player,
}
