--[[-- ExpReports
Lets players report each other, with the reports kept on the controller.

Nothing is stored in the lua state. Each call sends a request to the
controller through the instance plugin, and the answer is printed to the
player who asked once it arrives, if they are still online.
]]

local clusterio_api = require("modules/clusterio/api")
local ExpUtil = require("modules/exp_util")

local format_player_name = ExpUtil.format_player_name_locale

--- @class ExpReports
local ExpReports = {
    --- Raised once the controller has accepted a report, the reported player is online
    --- @type EventData.ExpReports.on_player_reported
    on_player_reported = script.generate_event_name(),
    --- Raised once the controller has deleted reports, the reported player is online
    --- @type EventData.ExpReports.on_reports_deleted
    on_reports_deleted = script.generate_event_name(),
}

--- @class EventData.ExpReports.on_player_reported : EventData
--- @field player_index uint
--- @field by_player_name string
--- @field reason string
--- @field report_count number Reports against the player including this one
--- @field by_player_names string[] Who made each of those reports

--- @class EventData.ExpReports.on_reports_deleted : EventData
--- @field player_index uint
--- @field by_player_name string Who deleted the reports
--- @field count number

--- @class ExpReports.Report
--- @field id number
--- @field player_name string
--- @field by_player_name string
--- @field reason string
--- @field instance_name string
--- @field updated_at_ms number

local error_settings = { color = ExpUtil.color.orange_red, sound_path = "utility/wire_pickup" }

--- Report a player, the outcome is printed once the controller answers
--- @param player LuaPlayer
--- @param reported_player LuaPlayer
--- @param reason string
function ExpReports.create_report(player, reported_player, reason)
    clusterio_api.send_json("exp_reports:create", {
        player_name = reported_player.name,
        by_player_name = player.name,
        reason = reason,
    })
end

--- List the reports against a player, or against everyone, printed to the player once the controller answers
--- @param player LuaPlayer
--- @param reported_player LuaPlayer?
function ExpReports.list_reports(player, reported_player)
    clusterio_api.send_json("exp_reports:list", {
        caller = player.name,
        player_name = reported_player and reported_player.name or nil,
    })
end

--- Delete the reports against a player, or only those from one player
--- @param player LuaPlayer
--- @param reported_player LuaPlayer
--- @param by_player_name string?
function ExpReports.delete_reports(player, reported_player, by_player_name)
    clusterio_api.send_json("exp_reports:delete", {
        caller = player.name,
        player_name = reported_player.name,
        by_player_name = by_player_name,
    })
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

--- The controller accepted a report
--- @param payload { report: ExpReports.Report, reports: ExpReports.Report[] }
function ExpReports.receive_created(payload)
    local report = payload.report
    local player_name = format_player_name(report.player_name)
    local by_player_name = format_player_name(report.by_player_name)
    for _, player in pairs(game.connected_players) do
        if player.admin then
            player.print{ "exp-reports.created-admin", player_name, by_player_name, report.reason }
        else
            player.print{ "exp-reports.created", player_name, report.reason }
        end
    end

    local player = get_online_player(report.player_name)
    if not player then return end

    local by_player_names = {}
    for index, other in ipairs(payload.reports) do
        by_player_names[index] = other.by_player_name
    end

    script.raise_event(ExpReports.on_player_reported, {
        name = ExpReports.on_player_reported,
        tick = game.tick,
        player_index = player.index,
        by_player_name = report.by_player_name,
        reason = report.reason,
        report_count = #payload.reports,
        by_player_names = by_player_names,
    })
end

--- The controller answered a list request
--- @param payload { caller: string, player_name: string?, reports: ExpReports.Report[] }
function ExpReports.receive_list(payload)
    local caller = get_online_player(payload.caller)
    if not caller then return end

    if payload.player_name then
        caller.print{ "exp-reports.list-title", format_player_name(payload.player_name), #payload.reports }
        for _, report in ipairs(payload.reports) do
            caller.print{ "exp-reports.list-entry", format_player_name(report.by_player_name), report.reason }
        end
        return
    end

    local counts = {} --- @type table<string, number>
    local names = {} --- @type string[]
    for _, report in ipairs(payload.reports) do
        if not counts[report.player_name] then
            names[#names + 1] = report.player_name
            counts[report.player_name] = 0
        end
        counts[report.player_name] = counts[report.player_name] + 1
    end

    if #names == 0 then
        caller.print{ "exp-reports.list-all-none" }
        return
    end

    table.sort(names)
    caller.print{ "exp-reports.list-all-title" }
    for _, name in ipairs(names) do
        caller.print{ "exp-reports.list-all-entry", format_player_name(name), counts[name] }
    end
end

--- The controller deleted reports
--- @param payload { caller: string, player_name: string, by_player_name: string?, count: number }
function ExpReports.receive_deleted(payload)
    if payload.count == 0 then
        local caller = get_online_player(payload.caller)
        if caller then
            caller.print({ "exp-reports.deleted-none", format_player_name(payload.player_name) }, error_settings)
        end
        return
    end

    game.print{ "exp-reports.deleted", format_player_name(payload.player_name), payload.count, format_player_name(payload.caller) }

    local player = get_online_player(payload.player_name)
    if not player then return end

    script.raise_event(ExpReports.on_reports_deleted, {
        name = ExpReports.on_reports_deleted,
        tick = game.tick,
        player_index = player.index,
        by_player_name = payload.caller,
        count = payload.count,
    })
end

--- The controller refused a request, the message is printed to whoever asked
--- @param payload { caller: string, message: string }
function ExpReports.receive_error(payload)
    local caller = get_online_player(payload.caller)
    if caller then
        caller.print(payload.message, error_settings)
    end
end

return ExpReports
