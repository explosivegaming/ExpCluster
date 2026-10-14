--[[-- ExpDiscordAuth
Links Factorio accounts to Discord accounts, the links are kept on the controller.

A player logs in with Discord on the web interface, which gives them a code.
Typing that code in game links the account they are playing on. Nothing is
stored in the lua state, every call goes to the controller and the answer is
printed to the player once it arrives, if they are still online.
]]

local clusterio_api = require("modules/clusterio/api")
local ExpUtil = require("modules/exp_util")

--- @class ExpDiscordAuth
local ExpDiscordAuth = {}

local error_settings = { color = ExpUtil.color.orange_red, sound_path = "utility/wire_pickup" }

--- Link the player to the Discord account which made the code
--- @param player LuaPlayer
--- @param code string
function ExpDiscordAuth.link(player, code)
    clusterio_api.send_json("exp_discord_auth:link", { player_name = player.name, code = code })
end

--- Remove the link between the player and their Discord account
--- @param player LuaPlayer
function ExpDiscordAuth.unlink(player)
    clusterio_api.send_json("exp_discord_auth:unlink", { player_name = player.name })
end

--- Print the Discord account the player is linked to
--- @param player LuaPlayer
function ExpDiscordAuth.get_linked(player)
    clusterio_api.send_json("exp_discord_auth:get", { player_name = player.name })
end

--- A player who can still be printed to, nil once they have left
--- @param name string
--- @return LuaPlayer?
local function get_online_player(name)
    local player = game.get_player(name)
    if player and player.valid and player.connected then
        return player
    end
    return nil
end

--- The controller linked the player
--- @param payload { player_name: string, discord_name: string }
function ExpDiscordAuth.receive_linked(payload)
    local player = get_online_player(payload.player_name)
    if not player then return end
    player.print{ "exp-discord-auth.linked", payload.discord_name }
end

--- The controller removed the link, discord_name is nil if there was none
--- @param payload { player_name: string, discord_name: string?, url: string }
function ExpDiscordAuth.receive_unlinked(payload)
    local player = get_online_player(payload.player_name)
    if not player then return end
    if payload.discord_name then
        player.print{ "exp-discord-auth.unlinked", payload.discord_name }
    else
        player.print({ "exp-discord-auth.not-linked", payload.url }, error_settings)
    end
end

--- The controller answered which account the player is linked to
--- @param payload { player_name: string, discord_name: string?, url: string }
function ExpDiscordAuth.receive_get(payload)
    local player = get_online_player(payload.player_name)
    if not player then return end
    if payload.discord_name then
        player.print{ "exp-discord-auth.linked-to", payload.discord_name }
    else
        player.print{ "exp-discord-auth.not-linked", payload.url }
    end
end

--- The controller refused a request
--- @param payload { player_name: string, message: string }
function ExpDiscordAuth.receive_error(payload)
    local player = get_online_player(payload.player_name)
    if not player then return end
    player.print(payload.message, error_settings)
end

return ExpDiscordAuth
