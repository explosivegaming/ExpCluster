--[[-- Control - Report Jail
When a player is reported, the player is automatically jailed if the combined playtime of the reporters exceeds the reported player
]]

local ExpUtil = require("modules/exp_util")
local Jail = require("modules.exp_legacy.modules.control.jail")
local Reports = require("modules.exp_legacy.modules.control.reports")

local max = math.max
local format_player_name = ExpUtil.format_player_name_locale

--- Returns the playtime of the reporter. Used when calculating the total playtime of all reporters
--- @param player LuaPlayer
--- @param by_player_name string
--- @param reason string
--- @return number
local function reporter_playtime(player, by_player_name, reason)
    local by_player = game.get_player(by_player_name)
    return by_player and by_player.online_time or 0
end

--- Check if the player has too many reports against them (based on playtime)
local function on_player_reported(event)
    local player = assert(game.get_player(event.player_index))
    local total_playtime = Reports.count_reports(player, reporter_playtime)

    -- Total time greater than the players own time, or 30 minutes, which ever is greater
    if Reports.count_reports(player) > 1 and total_playtime > max(player.online_time * 2, 108000) then
        Jail.jail_player(player, "<reports>", "Reported by too many players, please wait for a moderator.")
        game.print{ "exp_report-jail.chat-jailed", format_player_name(player) }
    end
end

return {
    events = {
        [Reports.events.on_player_reported] = on_player_reported,
    }
}
