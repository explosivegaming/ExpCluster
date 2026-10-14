--[[-- ExpPlayerStatistics - Events
Tracks the statistics, and sends them to the controller.
]]

local ExpPlayerStatistics = require("modules/exp_player_statistics/control")
local config = ExpPlayerStatistics.config

local increment = ExpPlayerStatistics.increment
local floor = math.floor
local afk_required = 5 * 3600 -- 5 minutes
local send_interval = 5 * 3600 -- 5 minutes

--- @type table<defines.events, fun(event: EventData)>
local events = {}

--- Add a handler, chained after any other for the same event
--- @param event_id defines.events
--- @param handler fun(event: EventData)
local function add(event_id, handler)
    local existing = events[event_id]
    if existing then
        events[event_id] = function(event)
            existing(event)
            handler(event)
        end
    else
        events[event_id] = handler
    end
end

--- Get the player of an event if they are online
--- @param event { player_index: uint? }
--- @return LuaPlayer?
local function get_online_player(event)
    if not event.player_index then return nil end
    local player = game.players[event.player_index]
    if not player or not player.valid or not player.connected then return nil end
    return player
end

--- @param event EventData.on_player_left_game
add(defines.events.on_player_left_game, function(event)
    local player = game.players[event.player_index]
    ExpPlayerStatistics.send_and_forget(player.name)
end)

--- Count a minute of afk time for every player who has been afk long enough
local function count_afk_time()
    if game.tick == 0 then return end
    for _, player in pairs(game.connected_players) do
        if player.afk_time > afk_required then increment(player, "AfkTime") end
    end
end


--- @param event EventData.on_player_created
add(defines.events.on_player_created, function(event)
    increment(game.players[event.player_index], "MapsPlayed")
end)

--- @param event EventData.on_player_changed_position
add(defines.events.on_player_changed_position, function(event)
    local player = get_online_player(event)
    if not player or player.afk_time > afk_required then return end
    increment(player, "DistanceTravelled")
end)

--- @param event EventData.on_marked_for_deconstruction | EventData.on_player_mined_entity
local function on_removed(event)
    local player = get_online_player(event)
    if not player then return end
    local entity = event.entity
    if not entity.valid then return end
    if entity.type == "resource" then
        increment(player, "OreMined")
    elseif entity.type == "tree" then
        increment(player, "TreesDestroyed")
    elseif entity.force == player.force then
        increment(player, "MachinesRemoved")
    end
end
add(defines.events.on_marked_for_deconstruction, on_removed)
add(defines.events.on_player_mined_entity, on_removed)

--- Vehicles which credit their driver, or failing that their passenger, with what they hit
local crewed_vehicles = { car = true, ["spider-vehicle"] = true, locomotive = true }

--- Get the connected player behind the cause of damage or a death, nil for turrets, trains without a crew and the like
--- @param cause LuaEntity?
--- @return LuaPlayer?
local function get_cause_player(cause)
    if not cause or not cause.valid then return nil end

    local occupant = cause --- @type LuaEntity | LuaPlayer
    if crewed_vehicles[cause.type] then
        local crew = cause.get_driver() or cause.get_passenger()
        if not crew then return nil end
        occupant = crew
    end

    local player --- @type LuaPlayer?
    if occupant.object_name == "LuaPlayer" then
        player = occupant --[[@as LuaPlayer]]
    elseif occupant.type == "character" then
        player = occupant.player
    end

    if not player or not player.valid or not player.connected then return nil end
    return player
end

--- Check that damage or a death counts against an entity, it must be hostile to the player
--- @param entity LuaEntity
--- @param player LuaPlayer
--- @return boolean
local function is_hostile(entity, player)
    return entity.valid and entity.force ~= player.force and entity.force.name ~= "neutral"
end

--- @param event EventData.on_entity_damaged
add(defines.events.on_entity_damaged, function(event)
    local player = get_cause_player(event.cause)
    if not player or not is_hostile(event.entity, player) then return end
    increment(player, "DamageDealt", floor(event.final_damage_amount))
end)

--- @param event EventData.on_entity_died
add(defines.events.on_entity_died, function(event)
    local player = get_cause_player(event.cause)
    if not player or not is_hostile(event.entity, player) then return end
    increment(player, "Kills")
end)

--- Increment a statistic for every online player on a force
--- @param force LuaForce?
--- @param statistic string
local function increment_force(force, statistic)
    if not force or not force.valid then return end
    for _, player in pairs(force.connected_players) do
        increment(player, statistic)
    end
end

--- @param event EventData.on_rocket_launched
add(defines.events.on_rocket_launched, function(event)
    local silo = event.rocket_silo
    if not silo or not silo.valid then return end
    increment_force(silo.force --[[@as LuaForce]], "RocketsLaunched")
end)

--- @param event EventData.on_research_finished
add(defines.events.on_research_finished, function(event)
    local research = event.research
    if event.by_script or not research or not research.valid then return end
    increment_force(research.force, "ResearchCompleted")
end)

for statistic, event_id in pairs(config.counters) do
    add(event_id, function(event)
        local player = get_online_player(event)
        if player then increment(player, statistic) end
    end)
end

return {
    events = events,
    on_nth_tick = {
        [3600] = count_afk_time,
        [send_interval] = ExpPlayerStatistics.send_all,
    },
}
