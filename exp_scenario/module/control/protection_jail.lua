--[[-- Control - Projection Jail
When a player triggers protection multiple times they are automatically jailed
]]

local ExpUtil = require("modules/exp_util")
local Storage = require("modules/exp_util/storage")
local Jail = require("modules.exp_legacy.modules.control.jail")
local Protection = require("modules.exp_legacy.modules.control.protection")

local format_player_name = ExpUtil.format_player_name_locale

--- Stores how many times the repeat violation was triggered
--- @type table<number, number>
local repeat_count = {}
Storage.register(repeat_count, function(tbl)
    repeat_count = tbl
end)

--- When a protection is triggered increment their counter and jail if needed
local function on_repeat_violation(event)
    local player = assert(game.get_player(event.player_index))

    -- Increment the counter
    local count = (repeat_count[player.index] or 0) + 1
    repeat_count[player.index] = count

    -- Jail if needed
    if count >= 3 then
        Jail.jail_player(player, "<protection>", "Removed too many protected entities, please wait for a moderator.")
        game.print{ "exp_protection-jail.chat-jailed", format_player_name(player) }
    end
end

--- Clear the counter when they leave the game (stops a build up of data)
--- @param event EventData.on_player_left_game
local function on_player_left_game(event)
    repeat_count[event.player_index] = nil
end

local e = defines.events

return {
    events = {
        [Protection.events.on_repeat_violation] = on_repeat_violation,
        [e.on_player_left_game] = on_player_left_game,
    }
}
