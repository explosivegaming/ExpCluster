--[[-- ExpPlayerStatistics
Player statistics kept on the controller.

What each player gains is kept here as unsent until it is sent to the
controller, every 5 minutes and when the player leaves. Once sent it is added
to the totals the controller gave when the player joined, so get() is the
total across every server either way.

Updates which are lost are not sent again. Anything unsent when the server
starts is from a save made before it was sent, so it is dropped rather than
risk counting it twice.

local ExpPlayerStatistics = require("modules/exp_player_statistics")

ExpPlayerStatistics.increment(player, "Kills")
ExpPlayerStatistics.get(player, "Kills")
for _, name in ipairs(ExpPlayerStatistics.display_order) do end
]]

local clusterio_api = require("modules/clusterio/api")
local ExpUtil = require("modules/exp_util")
local Storage = require("modules/exp_util/storage")
local config = require("modules/exp_player_statistics/config")

local format_number = require("util").format_number

--- @alias ExpPlayerStatistics.Stats table<string, number>

--- @class ExpPlayerStatistics.Totals
--- @field name string
--- @field stats ExpPlayerStatistics.Stats

--- @class ExpPlayerStatistics
local ExpPlayerStatistics = {
    config = config,
    --- Statistics in the order they are shown
    --- @type string[]
    display_order = config.display_order,
    --- Shown after the value
    --- @type table<string, string>
    units = { DistanceTravelled = " tiles" },
}

--- Measured in minutes and shown as a time
local time_statistics = { Playtime = true, AfkTime = true }
local long_time_format = ExpUtil.format_time_factory_locale{ format = "long", coefficient = 3600, hours = true, minutes = true }
local short_time_format = ExpUtil.format_time_factory_locale{ format = "short", coefficient = 3600, hours = true, minutes = true }

local unsent = {} --- @type table<string, ExpPlayerStatistics.Stats>
local totals = {} --- @type table<string, ExpPlayerStatistics.Stats>
Storage.register({ unsent, totals }, function(tbl)
    unsent = tbl[1]
    totals = tbl[2]
end)

--- Add to a statistic of a player
--- @param player LuaPlayer
--- @param statistic string
--- @param amount number? Defaults to 1
function ExpPlayerStatistics.increment(player, statistic, amount)
    local name = player.name
    local stats = unsent[name]
    if not stats then
        stats = {}
        unsent[name] = stats
    end
    stats[statistic] = (stats[statistic] or 0) + (amount or 1)
end

--- Get the total of a statistic for a player, on every server
--- @param player LuaPlayer | string
--- @param statistic string
--- @return number
function ExpPlayerStatistics.get(player, statistic)
    local name = type(player) == "string" and player or player.name
    local received = totals[name]
    local pending = unsent[name]
    return (received and received[statistic] or 0) + (pending and pending[statistic] or 0)
end

--- Get the value of a statistic as it is shown to players
--- @param statistic string
--- @param value number
--- @param short boolean? Use the short time format
--- @return LocalisedString
function ExpPlayerStatistics.format(statistic, value, short)
    if time_statistics[statistic] then
        return short and short_time_format(value) or long_time_format(value)
    end
    return format_number(value, false)
end

--- Move the unsent statistics of a player into their totals
--- @param name string
--- @return ExpPlayerStatistics.Stats?
local function take_unsent(name)
    local stats = unsent[name]
    if not stats then return nil end
    unsent[name] = nil

    local received = totals[name]
    if not received then
        received = {}
        totals[name] = received
    end
    for statistic, value in pairs(stats) do
        received[statistic] = (received[statistic] or 0) + value
    end
    return stats
end

--- Send what a player gained to the controller
--- @param name string
function ExpPlayerStatistics.send(name)
    local stats = take_unsent(name)
    if stats then
        clusterio_api.send_json("exp_player_statistics:update", { players = { { name = name, stats = stats } } })
    end
end

--- Send what every player gained to the controller, in one update
function ExpPlayerStatistics.send_all()
    local players, count = {}, 0
    for name in pairs(unsent) do
        count = count + 1
        players[count] = { name = name, stats = take_unsent(name) }
    end
    if count > 0 then
        clusterio_api.send_json("exp_player_statistics:update", { players = players })
    end
end

--- Send what a player gained and forget them, called when they leave
--- @param name string
function ExpPlayerStatistics.send_and_forget(name)
    ExpPlayerStatistics.send(name)
    totals[name] = nil
end

--- Called by the instance plugin over rcon when the server starts
function ExpPlayerStatistics.discard_unsent()
    for name in pairs(unsent) do
        unsent[name] = nil
    end
end

--- Called by the instance plugin over rcon when a player joins
--- @param payload ExpPlayerStatistics.Totals
function ExpPlayerStatistics.receive_totals(payload)
    local player = game.get_player(payload.name)
    if not player or not player.connected then return end
    totals[payload.name] = payload.stats
end

return ExpPlayerStatistics
