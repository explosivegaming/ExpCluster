--- When a player is reported, the player is automatically jailed if the combined playtime of the reporters exceeds the reported player
-- @addon report-jail

local Event = require 'utils.event' ---@dep utils.event
local Jail = require 'modules.control.jail' ---@dep modules.control.jail
local Reports = require 'modules.control.reports' --- @dep modules.control.reports
local format_chat_player_name = _C.format_chat_player_name --- @dep expcore.common

--- Returns the playtime of the reporter. Used when calculating the total playtime of all reporters
local function reporter_playtime(_, by_player_name, _)
    local player = game.get_player(by_player_name)
    if player == nil then
        return 0
    end
    return player.online_time
end

Event.add(Reports.events.on_player_reported, function(event)
    local player = game.get_player(event.player_index)
    local total_playtime = Reports.count_reports(player, reporter_playtime)

    -- player less than 30 min
    if (Reports.count_reports(player) > 1) and (total_playtime > math.max(player.online_time * 2, 108000)) then
        local player_name_color = format_chat_player_name(player)
        Jail.jail_player(player, '<reports>', 'Reported by too many players, please wait for a moderator.')
        game.print{'report-jail.jail', player_name_color}
    end
end)
