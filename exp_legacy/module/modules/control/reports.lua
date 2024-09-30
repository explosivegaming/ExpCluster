--[[-- Control Module - Reports
    - Adds a way to report players and store report messages.
    @control Reports
    @alias Reports

    @usage
    -- import the module from the control modules
    local Reports = require("modules.exp_legacy.modules.control.reports") --- @dep modules.control.reports

    -- This will place a report on "MrBiter" (must be a valid player) the report will have been made
    -- by "Cooldude2606" (must be the player name) with the reason 'Liking biters too much' this can be
    -- seen by using Reports.get_report.
    Reports.report_player('MrBiter', 'Cooldude2606', 'Liking biters too much') -- true

    -- The other get methods can be used to get all the reports on a player or to test if a player is reported.
    Reports.get_report('MrBiter', 'Cooldude2606') -- 'Liking biters too much'

    -- This will remove the warning on 'MrBiter' (must be a valid player) which was made by 'Cooldude2606'.
    Reports.remove_report('MrBiter', 'Cooldude2606') -- true

    -- This will remove all the report that have been made against 'MrBiter'. Note that the remove event will
    -- be triggered once per report issused.
    Reports.remove_all('MrBiter') -- true

]]

local Storage = require("modules/exp_util/storage")

local valid_player = function(p) return type(p) == "userdata" and p or game.get_player(p) end

local Reports = {
    user_reports = {}, -- stores all user reports, global table
    events = {
        --- When a player is reported
        -- @event on_player_reported
        -- @tparam number player_index the player index of the player who got reported
        -- @tparam string by_player_name the name of the player who made the report
        -- @tparam string reason the reason given for the report
        on_player_reported = script.generate_event_name(),
        --- When a report is removed from a player
        -- @event on_report_removed
        -- @tparam number player_index the player index of the player who has the report removed
        -- @tparam string reported_by_name the name of the player who made the removed report
        -- @tparam string removed_by_name the name of the player who removed the report
        -- @tparam number batch_count the number of reports removed in this batch, always one when not a batch
        -- @tparam number batch the index of this event in a batch, always one when not a batch
        on_report_removed = script.generate_event_name(),
    },
}

local user_reports = Reports.user_reports
Storage.register(user_reports, function(tbl)
    Reports.user_reports = tbl
    user_reports = Reports.user_reports
end)

--- Getters.
-- Functions used to get information from reports
-- @section get-functions

--- Gets a list of all reports that a player has against them
-- @tparam LuaPlayer player the player to get the report for
-- @treturn table a list of all reports, key is by player name, value is reason
function Reports.get_reports(player)
    player = valid_player(player)
    if not player then return end

    return user_reports[player.name] or {}
end

--- Gets a single report against a player given the name of the player who made the report
-- @tparam LuaPlayer player the player to get the report for
-- @tparam string by_player_name the name of the player who made the report
-- @treturn ?string|nil string is the reason that the player was reported, if the player is not reported
function Reports.get_report(player, by_player_name)
    player = valid_player(player)
    if not player then return end
    if not by_player_name then return end

    local reports = user_reports[player.name]
    return reports and reports[by_player_name]
end

--- Checks if a player is reported, option to get if reported by a certain player
-- @tparam LuaPlayer player the player to check if reported
-- @tparam[opt] string by_player_name when given will check if reported by this player
-- @treturn boolean if the player has been reported
function Reports.is_reported(player, by_player_name)
    player = valid_player(player)
    if not player then return end

    local reports = user_reports[player.name] or {}
    if by_player_name then
        return reports[by_player_name] ~= nil
    else
        return table_size(reports) > 0
    end
end

--- Counts the number of reports that a player has aganist them
-- @tparam LuaPlayer player the player to count the reports for
-- @tparam[opt] function custom_count when given this function will be used to count the reports
-- @treturn number the number of reports that the user has
function Reports.count_reports(player, custom_count)
    player = valid_player(player)
    if not player then return end

    local reports = user_reports[player.name] or {}
    if custom_count then
        local ctn = 0
        for by_player_name, reason in pairs(reports) do
            ctn = ctn + custom_count(player, by_player_name, reason)
        end

        return ctn
    else
        return table_size(reports)
    end
end

--- Setters.
-- Functions used to get information from reports
-- @section set-functions

--- Adds a report to a player, each player can only report another player once
-- @tparam LuaPlayer player the player to add the report to
-- @tparam string by_player_name the name of the player that is making the report
-- @tparam[opt='Non given.'] string reason the reason that the player is being reported
-- @treturn boolean whether the report was added successfully
function Reports.report_player(player, by_player_name, reason)
    player = valid_player(player)
    if not player then return end
    local player_name = player.name

    if reason == nil or not reason:find("%S") then reason = "No reason given" end

    local reports = user_reports[player_name]
    if not reports then
        reports = {}
        user_reports[player_name] = reports
    end

    if reports[by_player_name] then
        return false
    else
        reports[by_player_name] = reason
    end

    script.raise_event(Reports.events.on_player_reported, {
        name = Reports.events.on_player_reported,
        tick = game.tick,
        player_index = player.index,
        by_player_name = by_player_name,
        reason = reason,
    })

    return true
end

--- Used to emit the report removed event, own function due to repeated use in Report.remove_all
-- @tparam LuaPlayer player the player who is having the report removed from them
-- @tparam string reported_by_name the player who had the report
-- @tparam string removed_by_name the player who is clearing the report
-- @tparam number batch the index of this event in a batch, always one when not a batch
-- @tparam number batch_count the number of reports removed in this batch, always one when not a batch
local function report_removed_event(player, reported_by_name, removed_by_name, batch, batch_count)
    script.raise_event(Reports.events.on_report_removed, {
        name = Reports.events.on_report_removed,
        tick = game.tick,
        player_index = player.index,
        reported_by_name = reported_by_name,
        removed_by_name = removed_by_name,
        batch_count = batch_count or 1,
        batch = batch or 1,
    })
end

--- Removes a report from a player
-- @tparam LuaPlayer player the player to remove the report from
-- @tparam string reported_by_name the name of the player that made the report
-- @tparam string removed_by_name the name of the player who removed the report
-- @treturn boolean whether the report was removed successfully
function Reports.remove_report(player, reported_by_name, removed_by_name)
    player = valid_player(player)
    if not player then return end

    local reports = user_reports[player.name]
    if not reports then
        return false
    end

    local reason = reports[reported_by_name]
    if not reason then
        return false
    end

    report_removed_event(player, reported_by_name, removed_by_name)

    reports[reported_by_name] = nil
    return true
end

--- Removes all reports from a player
-- @tparam LuaPlayer player the player to remove the reports from
-- @tparam string removed_by_name the name of the player who removed the report
-- @treturn boolean whether the reports were removed successfully
function Reports.remove_all(player, removed_by_name)
    player = valid_player(player)
    if not player then return end

    local reports = user_reports[player.name]
    if not reports then
        return false
    end
    local ctn, total = 0, #reports
    for reported_by_name, _ in pairs(reports) do
        ctn = ctn + 1
        report_removed_event(player, reported_by_name, removed_by_name, ctn, total)
    end

    user_reports[player.name] = nil
    return true
end

return Reports
