--- When a player triggers protection multiple times they are automatically jailed
-- @addon protection-jail

local ExpUtil = require("modules/exp_util")
local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event
local Storage = require("modules/exp_util/storage") --- @dep utils.global
local Jail = require("modules.exp_legacy.modules.control.jail") --- @dep modules.control.jail
local Protection = require("modules.exp_legacy.modules.control.protection") --- @dep modules.control.protection
local format_player_name = ExpUtil.format_player_name_locale --- @dep expcore.common

--- Stores how many times the repeat violation was triggered
local repeat_count = {}
Storage.register(repeat_count, function(tbl)
    repeat_count = tbl
end)

--- When a protection is triggered increment their counter and jail if needed
Event.add(Protection.events.on_repeat_violation, function(event)
    local player = game.players[event.player_index]

    -- Increment the counter
    if repeat_count[player.index] then
        repeat_count[player.index] = repeat_count[player.index] + 1
    else
        repeat_count[player.index] = 1
    end

    -- Jail if needed
    if repeat_count[player.index] < 3 then
        return
    end

    local player_name_color = format_player_name(player)
    Jail.jail_player(player, "<protection>", "Removed too many protected entities, please wait for a moderator.")
    game.print{ "protection-jail.jail", player_name_color }
end)

--- Clear the counter when they leave the game (stops a build up of data)
Event.add(defines.events.on_player_left_game, function(event)
    repeat_count[event.player_index] = nil
end)
