--[[-- ExpDiscord
Links Factorio accounts to Discord accounts, the links are kept on the controller.

A player logs in with Discord on the web interface, which gives them a code.
Typing that code in game links the account they are playing on. Nothing is
stored in the lua state, every call goes to the controller and the answer is
printed to the player once it arrives, if they are still online.
]]

local clusterio_api = require("modules/clusterio/api")
local ExpUtil = require("modules/exp_util")

--- @class ExpDiscord
local ExpDiscord = {}

local error_settings = { color = ExpUtil.color.orange_red, sound_path = "utility/wire_pickup" }

--- Link the player to the Discord account which made the code
--- @param player LuaPlayer
--- @param code string
function ExpDiscord.link(player, code)
    clusterio_api.send_json("exp_discord:link", { player_name = player.name, code = code })
end

--- Remove the link between the player and their Discord account
--- @param player LuaPlayer
function ExpDiscord.unlink(player)
    clusterio_api.send_json("exp_discord:unlink", { player_name = player.name })
end

--- Print the Discord account the player is linked to
--- @param player LuaPlayer
function ExpDiscord.get_link(player)
    clusterio_api.send_json("exp_discord:get", { player_name = player.name })
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
function ExpDiscord.receive_linked(payload)
    local player = get_online_player(payload.player_name)
    if not player then return end
    player.print{ "exp-discord.linked", payload.discord_name }
end

--- The controller removed the link, discord_name is nil if there was none
--- @param payload { player_name: string, discord_name: string? }
function ExpDiscord.receive_unlinked(payload)
    local player = get_online_player(payload.player_name)
    if not player then return end
    if payload.discord_name then
        player.print{ "exp-discord.unlinked", payload.discord_name }
    else
        player.print({ "exp-discord.not-linked" }, error_settings)
    end
end

--- The controller answered which account the player is linked to
--- @param payload { player_name: string, discord_name: string? }
function ExpDiscord.receive_get(payload)
    local player = get_online_player(payload.player_name)
    if not player then return end
    if payload.discord_name then
        player.print{ "exp-discord.linked-to", payload.discord_name }
    else
        player.print{ "exp-discord.not-linked" }
    end
end

--- The controller refused a request
--- @param payload { player_name: string, message: string }
function ExpDiscord.receive_error(payload)
    local player = get_online_player(payload.player_name)
    if not player then return end
    player.print(payload.message, error_settings)
end

return ExpDiscord
