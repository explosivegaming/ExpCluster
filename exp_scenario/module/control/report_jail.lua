--[[-- Control - Report Jail
When a player is reported, the player is automatically jailed if the combined playtime of the reporters exceeds the reported player
]]

local ExpUtil = require("modules/exp_util")
local Jail = require("modules/exp_scenario/control/jail")
local Reports = require("modules/exp_reports")

local max = math.max
local format_player_name = ExpUtil.format_player_name_locale

--- Check if the player has too many reports against them, weighed by the playtime of the reporters
--- @param event EventData.ExpReports.on_player_reported
local function on_player_reported(event)
    local player = assert(game.get_player(event.player_index))

    local total_playtime = 0
    for _, by_player_name in ipairs(event.by_player_names) do
        local by_player = game.get_player(by_player_name)
        total_playtime = total_playtime + (by_player and by_player.online_time or 0)
    end

    -- Total time greater than the players own time, or 30 minutes, which ever is greater
    if event.report_count > 1 and total_playtime > max(player.online_time * 2, 108000) then
        Jail.jail_player(player, "<reports>", "Reported by too many players, please wait for a moderator.")
        game.print{ "exp_report-jail.chat-jailed", format_player_name(player) }
    end
end

return {
    events = {
        [Reports.on_player_reported] = on_player_reported,
    }
}
