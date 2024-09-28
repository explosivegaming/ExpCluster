--- Sends alert messages to our discord server when certain events are triggered
-- @addon Discord-Alerts

local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event
local Colors = require("modules/exp_util/include/color")
local write_json, format_time = _C.write_json, _C.format_time --- @dep expcore.common
local config = require("modules.exp_legacy.config.discord_alerts") --- @dep config.discord_alerts

local playtime_format = { hours = true, minutes = true, short = true, string = true }

local function append_playtime(player_name)
    if not config.show_playtime then
        return player_name
    end

    local player = game.get_player(player_name)

    if not player then
        return player_name
    end

    return player.name .. " (" .. format_time(player.online_time, playtime_format) .. ")"
end

local function get_player_name(event)
    local player = game.players[event.player_index]
    return player.name, event.by_player_name
end

local function to_hex(color)
    local hex_digits = "0123456789ABCDEF"
    local function hex(bit)
        local major, minor = math.modf(bit / 16)
        major, minor = major + 1, minor * 16 + 1
        return hex_digits:sub(major, major) .. hex_digits:sub(minor, minor)
    end

    return "0x" .. hex(color.r) .. hex(color.g) .. hex(color.b)
end

local function emit_event(args)
    local title = args.title or ""
    local color = args.color or "0x0"
    local description = args.description or ""

    if type(color) == "table" then
        color = to_hex(color)
    end

    local tick = args.tick or game.tick
    local tick_formatted = format_time(tick, { days = false, hours = true, minutes = true, short = true, string = true })

    local players_online = 0
    local admins_online = 0

    for _, player in pairs(game.connected_players) do
        players_online = players_online + 1

        if player.admin then
            admins_online = admins_online + 1
        end
    end

    local done = { title = true, color = true, description = true }
    local fields = { {
        name = "Server Details",
        value = string.format("Server: ${serverName} Time: %s\nTotal: %d Online: %d Admins: %d", tick_formatted, #game.players, players_online, admins_online),
    } }

    for key, value in pairs(args) do
        if not done[key] then
            done[key] = true
            local field = {
                name = key,
                value = value,
                inline = false,
            }

            local new_value, inline = value:gsub("<inline>", "", 1)
            if inline > 0 then
                field.value = new_value
                field.inline = true
            end

            table.insert(fields, field)
        end
    end

    write_json("ext/discord.out", {
        title = title,
        description = description,
        color = color,
        fields = fields,
    })
end

--- Repeated protected entity mining
if config.entity_protection then
    local EntityProtection = require("modules.exp_legacy.modules.control.protection") --- @dep modules.control.protection
    Event.add(EntityProtection.events.on_repeat_violation, function(event)
        local player_name = get_player_name(event)
        emit_event{
            title = "Entity Protection",
            description = "A player removed protected entities",
            color = Colors.yellow,
            ["Player"] = "<inline>" .. append_playtime(player_name),
            ["Entity"] = "<inline>" .. event.entity.name,
            ["Location"] = "X " .. event.entity.position.x .. " Y " .. event.entity.position.y,
        }
    end)
end

--- Reports added and removed
if config.player_reports then
    local Reports = require("modules.exp_legacy.modules.control.reports") --- @dep modules.control.reports
    Event.add(Reports.events.on_player_reported, function(event)
        local player_name, by_player_name = get_player_name(event)
        emit_event{
            title = "Report",
            description = "A player was reported",
            color = Colors.yellow,
            ["Player"] = "<inline>" .. append_playtime(player_name),
            ["By"] = "<inline>" .. append_playtime(by_player_name),
            ["Report Count"] = "<inline>" .. Reports.count_reports(player_name),
            ["Reason"] = event.reason,
        }
    end)
    Event.add(Reports.events.on_report_removed, function(event)
        if event.batch ~= 1 then return end
        local player_name = get_player_name(event)
        emit_event{
            title = "Reports Removed",
            description = "A player has a report removed",
            color = Colors.green,
            ["Player"] = "<inline>" .. player_name,
            ["By"] = "<inline>" .. event.removed_by_name,
            ["Report Count"] = "<inline>" .. event.batch_count,
        }
    end)
end

--- Warnings added and removed
if config.player_warnings then
    local Warnings = require("modules.exp_legacy.modules.control.warnings") --- @dep modules.control.warnings
    Event.add(Warnings.events.on_warning_added, function(event)
        local player_name, by_player_name = get_player_name(event)
        local player = game.get_player(player_name)
        emit_event{
            title = "Warning",
            description = "A player has been given a warning",
            color = Colors.yellow,
            ["Player"] = "<inline>" .. player_name,
            ["By"] = "<inline>" .. by_player_name,
            ["Warning Count"] = "<inline>" .. Warnings.count_warnings(player),
            ["Reason"] = event.reason,
        }
    end)
    Event.add(Warnings.events.on_warning_removed, function(event)
        if event.batch ~= 1 then return end
        local player_name = get_player_name(event)
        emit_event{
            title = "Warnings Removed",
            description = "A player has a warning removed",
            color = Colors.green,
            ["Player"] = "<inline>" .. player_name,
            ["By"] = "<inline>" .. event.removed_by_name,
            ["Warning Count"] = "<inline>" .. event.batch_count,
        }
    end)
end

--- When a player is jailed or unjailed
if config.player_jail then
    local Jail = require("modules.exp_legacy.modules.control.jail")
    Event.add(Jail.events.on_player_jailed, function(event)
        local player_name, by_player_name = get_player_name(event)
        emit_event{
            title = "Jail",
            description = "A player has been jailed",
            color = Colors.yellow,
            ["Player"] = "<inline>" .. player_name,
            ["By"] = "<inline>" .. by_player_name,
            ["Reason"] = event.reason,
        }
    end)
    Event.add(Jail.events.on_player_unjailed, function(event)
        local player_name, by_player_name = get_player_name(event)
        emit_event{
            title = "Unjail",
            description = "A player has been unjailed",
            color = Colors.green,
            ["Player"] = "<inline>" .. player_name,
            ["By"] = "<inline>" .. by_player_name,
        }
    end)
end

--- Ban and unban
if config.player_bans then
    Event.add(defines.events.on_player_banned, function(event)
        if event.by_player then
            local by_player = game.players[event.by_player]
            emit_event{
                title = "Banned",
                description = "A player has been banned",
                color = Colors.red,
                ["Player"] = "<inline>" .. event.player_name,
                ["By"] = "<inline>" .. by_player.name,
                ["Reason"] = event.reason,
            }
        end
    end)
    Event.add(defines.events.on_player_unbanned, function(event)
        if event.by_player then
            local by_player = game.players[event.by_player]
            emit_event{
                title = "Un-Banned",
                description = "A player has been un-banned",
                color = Colors.green,
                ["Player"] = "<inline>" .. event.player_name,
                ["By"] = "<inline>" .. by_player.name,
            }
        end
    end)
end

--- Mute and unmute
if config.player_mutes then
    Event.add(defines.events.on_player_muted, function(event)
        local player_name = get_player_name(event)
        emit_event{
            title = "Muted",
            description = "A player has been muted",
            color = Colors.yellow,
            ["Player"] = "<inline>" .. player_name,
        }
    end)
    Event.add(defines.events.on_player_unmuted, function(event)
        local player_name = get_player_name(event)
        emit_event{
            title = "Un-Muted",
            description = "A player has been un-muted",
            color = Colors.green,
            ["Player"] = "<inline>" .. player_name,
        }
    end)
end

--- Kick
if config.player_kicks then
    Event.add(defines.events.on_player_kicked, function(event)
        if event.by_player then
            local player_name = get_player_name(event)
            local by_player = game.players[event.by_player]
            emit_event{
                title = "Kick",
                description = "A player has been kicked",
                color = Colors.orange,
                ["Player"] = "<inline>" .. player_name,
                ["By"] = "<inline>" .. by_player.name,
                ["Reason"] = event.reason,
            }
        end
    end)
end

--- Promote and demote
if config.player_promotes then
    Event.add(defines.events.on_player_promoted, function(event)
        local player_name = get_player_name(event)
        emit_event{
            title = "Promote",
            description = "A player has been promoted",
            color = Colors.green,
            ["Player"] = "<inline>" .. player_name,
        }
    end)
    Event.add(defines.events.on_player_demoted, function(event)
        local player_name = get_player_name(event)
        emit_event{
            title = "Demote",
            description = "A player has been demoted",
            color = Colors.yellow,
            ["Player"] = "<inline>" .. player_name,
        }
    end)
end

--- Other commands
Event.add(defines.events.on_console_command, function(event)
    if event.player_index then
        local player_name = get_player_name(event)
        if config[event.command] then
            emit_event{
                title = event.command:gsub("^%l", string.upper),
                description = "/" .. event.command .. " was used",
                color = Colors.grey,
                ["By"] = "<inline>" .. player_name,
                ["Details"] = event.parameters ~= "" and event.parameters or nil,
            }
        end
    end
end)
