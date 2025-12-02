--[[-- Control - Discord Alerts
Sends alert messages to our discord server when certain events are triggered
]]

local ExpUtil = require("modules/exp_util")
local Colors = require("modules/exp_util/include/color")
local config = require("modules.exp_legacy.config.discord_alerts")

local format_string = string.format
local write_json = ExpUtil.write_json
local playtime_format = ExpUtil.format_time_factory{ format = "short", hours = true, minutes = true, seconds = true }
local emit_event_time_format = ExpUtil.format_time_factory{ format = "short", hours = true, minutes = true }

local e = defines.events
local events = {}

--- Append the play time to a players name
--- @param player_name string
--- @return string
local function append_playtime(player_name)
    if not config.show_playtime then
        return player_name
    end

    local player = game.get_player(player_name)
    if not player then
        return player_name
    end

    return format_string("%s (%s)", player.name, playtime_format(player.online_time))
end

--- Get the player name from an event
--- @param event { player_index: number, by_player_name: string? }
--- @return string, string
local function get_player_name(event)
    local player = game.players[event.player_index]
    return player.name, event.by_player_name
end

--- Convert a colour value into hex
--- @param color Color.0
--- @return string
local function to_hex(color)
    local hex_digits = "0123456789ABCDEF"
    local function hex(bit)
        local major, minor = math.modf(bit / 16)
        major, minor = major + 1, minor * 16 + 1
        return hex_digits:sub(major, major) .. hex_digits:sub(minor, minor)
    end

    return format_string("0x%s%s%s", hex(color.r), hex(color.g), hex(color.b))
end

--- Emit the requires json to file for the given event arguments
--- @param opts { title: string?, color: (Color.0 | string)?, description: string?, tick: number?, fields: { name: string, value: string, inline: boolean? }[] }
local function emit_event(opts)
    local admins_online = 0
    local players_online = 0
    for _, player in pairs(game.connected_players) do
        players_online = players_online + 1
        if player.admin then
            admins_online = admins_online + 1
        end
    end

    local tick_formatted = emit_event_time_format(opts.tick or game.tick)
    table.insert(opts.fields, 1, {
        name = "Server Details",
        value = format_string("Server: ${serverName} Time: %s\nTotal: %d Online: %d Admins: %d", tick_formatted, #game.players, players_online, admins_online),
    })

    local color = opts.color
    write_json("ext/discord.out", {
        title = opts.title or "",
        description = opts.description or "",
        color = type(color) == "table" and to_hex(color) or color or "0x0",
        fields = opts.fields,
    })
end

--- Repeated protected entity mining
if config.entity_protection then
    local EntityProtection = require("modules.exp_legacy.modules.control.protection")
    events[EntityProtection.events.on_repeat_violation] = function(event)
        local player_name = get_player_name(event)
        emit_event{
            title = "Entity Protection",
            description = "A player removed protected entities",
            color = Colors.yellow,
            fields = {
                { name = "Player", inline = true, value = append_playtime(player_name) },
                { name = "Entity", inline = true, value = event.entity.name },
                { name = "Location", value = format_string("X %.1f Y %.1f", event.entity.position.x, event.entity.position.y) },
            },
        }
    end
end

--- Reports added and removed
if config.player_reports then
    local Reports = require("modules.exp_legacy.modules.control.reports")
    events[Reports.events.on_player_reported] = function(event)
        local player_name, by_player_name = get_player_name(event)
        local player = assert(game.get_player(player_name))
        emit_event{
            title = "Report",
            description = "A player was reported",
            color = Colors.yellow,
            fields = {
                { name = "Player", inline = true, value = append_playtime(player_name) },
                { name = "By", inline = true, value = append_playtime(by_player_name) },
                { name = "Report Count", inline = true, value = Reports.count_reports(player) },
                { name = "Reason", value = event.reason },
            },
        }
    end
    events[Reports.events.on_report_removed] = function(event)
        if event.batch ~= 1 then return end
        local player_name = get_player_name(event)
        emit_event{
            title = "Reports Removed",
            description = "A player has a report removed",
            color = Colors.green,
            fields = {
                { name = "Player", inline = true, value = append_playtime(player_name) },
                { name = "By", inline = true, value = append_playtime(event.removed_by_name) },
                { name = "Report Count", inline = true, value = tostring(event.batch_count) },
            },
        }
    end
end

--- Warnings added and removed
if config.player_warnings then
    local Warnings = require("modules.exp_legacy.modules.control.warnings")
    events[Warnings.events.on_warning_added] = function(event)
        local player_name, by_player_name = get_player_name(event)
        local player = assert(game.get_player(player_name))
        emit_event{
            title = "Warning",
            description = "A player has been given a warning",
            color = Colors.yellow,
            fields = {
                { name = "Player", inline = true, value = append_playtime(player_name) },
                { name = "By", inline = true, value = append_playtime(by_player_name) },
                { name = "Report Count", inline = true, value = Warnings.count_warnings(player) },
                { name = "Reason", value = event.reason },
            },
        }
    end
    events[Warnings.events.on_warning_removed] = function(event)
        if event.batch ~= 1 then return end
        local player_name = get_player_name(event)
        emit_event{
            title = "Warnings Removed",
            description = "A player has a warning removed",
            color = Colors.green,
            fields = {
                { name = "Player", inline = true, value = append_playtime(player_name) },
                { name = "By", inline = true, value = append_playtime(event.removed_by_name) },
                { name = "Report Count", inline = true, value = tostring(event.batch_count) },
            },
        }
    end
end

--- When a player is jailed or unjailed
if config.player_jail then
    local Jail = require("modules.exp_legacy.modules.control.jail")
    events[Jail.events.on_player_jailed] = function(event)
        local player_name, by_player_name = get_player_name(event)
        emit_event{
            title = "Jail",
            description = "A player has been jailed",
            color = Colors.yellow,
            fields = {
                { name = "Player", inline = true, value = append_playtime(player_name) },
                { name = "By", inline = true, value = append_playtime(by_player_name) },
                { name = "Reason", value = event.reason },
            },
        }
    end
    events[Jail.events.on_player_unjailed] = function(event)
        local player_name, by_player_name = get_player_name(event)
        emit_event{
            title = "Unjail",
            description = "A player has been unjailed",
            color = Colors.green,
            fields = {
                { name = "Player", inline = true, value = append_playtime(player_name) },
                { name = "By", inline = true, value = append_playtime(by_player_name) },
            },
        }
    end
end

--- Ban and unban
if config.player_bans then
    --- @param event EventData.on_player_banned
    events[e.on_player_banned] = function(event)
        if event.by_player then
            local by_player = game.players[event.by_player]
            emit_event{
                title = "Banned",
                description = "A player has been banned",
                color = Colors.red,
                fields = {
                    { name = "Player", inline = true, value = append_playtime(event.player_name) },
                    { name = "By", inline = true, value = append_playtime(by_player.name) },
                    { name = "Reason", value = event.reason },
                },
            }
        end
    end
    --- @param event EventData.on_player_unbanned
    events[e.on_player_unbanned] = function(event)
        if event.by_player then
            local by_player = game.players[event.by_player]
            emit_event{
                title = "Un-Banned",
                description = "A player has been un-banned",
                color = Colors.green,
                fields = {
                    { name = "Player", inline = true, value = append_playtime(event.player_name) },
                    { name = "By", inline = true, value = append_playtime(by_player.name) },
                    { name = "Reason", value = event.reason },
                },
            }
        end
    end
end

--- Mute and unmute
if config.player_mutes then
    --- @param event EventData.on_player_muted
    events[e.on_player_muted] = function(event)
        local player_name = get_player_name(event)
        emit_event{
            title = "Muted",
            description = "A player has been muted",
            color = Colors.yellow,
            fields = {
                { name = "Player", inline = true, value = append_playtime(player_name) },
            },
        }
    end
    --- @param event EventData.on_player_unmuted
    events[e.on_player_unmuted] = function(event)
        local player_name = get_player_name(event)
        emit_event{
            title = "Un-Muted",
            description = "A player has been un-muted",
            color = Colors.green,
            fields = {
                { name = "Player", inline = true, value = append_playtime(player_name) },
            },
        }
    end
end

--- Kick
if config.player_kicks then
    --- @param event EventData.on_player_kicked
    events[e.on_player_kicked] = function(event)
        if event.by_player then
            local player_name = get_player_name(event)
            local by_player = game.players[event.by_player]
            emit_event{
                title = "Kick",
                description = "A player has been kicked",
                color = Colors.orange,
                fields = {
                    { name = "Player", inline = true, value = append_playtime(player_name) },
                    { name = "By", inline = true, value = append_playtime(by_player.name) },
                    { name = "Reason", value = event.reason },
                },
            }
        end
    end
end

--- Promote and demote
if config.player_promotes then
    --- @param event EventData.on_player_promoted
    events[e.on_player_promoted] = function(event)
        local player_name = get_player_name(event)
        emit_event{
            title = "Promote",
            description = "A player has been promoted",
            color = Colors.green,
            fields = {
                { name = "Player", inline = true, value = append_playtime(player_name) },
            },
        }
    end
    --- @param event EventData.on_player_demoted
    events[e.on_player_demoted] = function(event)
        local player_name = get_player_name(event)
        emit_event{
            title = "Demote",
            description = "A player has been demoted",
            color = Colors.yellow,
            fields = {
                { name = "Player", inline = true, value = append_playtime(player_name) },
            },
        }
    end
end


--- @param event EventData.on_console_command
events[e.on_console_command] = function(event)
    if event.player_index then
        local player_name = get_player_name(event)
        if config[event.command] then
            emit_event{
                title = event.command:gsub("^%l", string.upper),
                description = "/" .. event.command .. " was used",
                color = Colors.grey,
                fields = {
                    { name = "By", inline = true, value = append_playtime(player_name) },
                    { name = "Details", value = event.parameters ~= "" and event.parameters or "<no details>" },
                },
            }
        end
    end
end

return {
    events = events,
}
