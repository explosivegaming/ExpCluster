--[[-- Control -- AFK Kick
Kicks players when all players on the server are afk
]]

local Async = require("modules/exp_util/async")
local Feature = require("modules/exp_scenario/features")
local Roles = require("modules/exp_roles")
local Storage = require("modules/exp_util/storage")
local feature = Feature.register("afk_kick", {
    admin_as_active = true, --- @setting admin_as_active When true admins will be treated as active regardless of afk time
    trust_as_active = true, --- @setting trust_as_active When true trusted players (by playtime) will be treated as active regardless of afk time
    active_role_id = Feature.optional("number"), --- @setting active_role_id Players with this role or higher are treated as active regardless of afk time
    afk_minutes = 10, --- @setting afk_minutes The time in minutes that must pass for a player to be considered afk
    kick_minutes = 30, --- @setting kick_minutes The time in minutes that must pass without any active players for all players to be kicked
    trust_minutes = 600, --- @setting trust_minutes The time in minutes that a player must be online for to count as trusted
})
local config = feature.config

local ticks_per_minute = 3600

--- @type { last_active: number }
local script_data = { last_active = 0 }
Storage.register(script_data, function(tbl)
    script_data = tbl
end)

--- Kicks an afk player, used to add a delay so the gui has time to appear
local afk_kick_player_async =
    Async.register(function(player)
        if game.tick - script_data.last_active < config.kick_minutes * ticks_per_minute then return end
        game.kick_player(player, "AFK while no active players on the server")
    end)

--- Check if a player has a role which counts as active regardless of afk time
--- @param player LuaPlayer
--- @return boolean
local function is_active_role(player)
    local role = config.active_role_id and Roles.get_role(config.active_role_id)
    return role ~= nil and not Roles.get_player_highest_role(player):is_lower_than(role)
end

--- Check if there is an active player
local function has_active_player()
    for _, player in ipairs(game.connected_players) do
        if player.afk_time < config.afk_minutes * ticks_per_minute
        or config.admin_as_active and player.admin
        or config.trust_as_active and player.online_time > config.trust_minutes * ticks_per_minute
        or is_active_role(player) then
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
    if game.tick - script_data.last_active < config.kick_minutes * ticks_per_minute then return end

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

return feature:guard{
    events = {
        [e.on_player_joined_game] = on_player_joined_game,
    },
    on_nth_tick = {
        [60 * 60] = check_afk_players,
    },
    has_active_player = has_active_player,
}
