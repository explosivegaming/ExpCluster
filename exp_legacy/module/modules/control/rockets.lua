--[[-- Control Module - Rockets
    - Stores rocket stats for each force.
    @control Rockets
    @alias Rockets

    @usage
    -- import the module from the control modules
    local Rockets = require("modules.exp_legacy.modules.control.rockets") --- @dep modules.control.rockets

    -- Some basic information is stored for each silo that has been built
    -- the data includes: the tick it was built, the rockets launched from it and more
    Rockets.get_silo_data(rocket_silo_entity)

    -- Some information is also stored for each force
    Rockets.get_stats('player')

    -- You can get the rocket data for all silos for a force by using get_silos
    Rockets.get_silos('player')

    -- You can get the launch time for a rocket, meaning what game tick the 50th rocket was launched
    Rockets.get_rocket_time('player', 50)

    -- The rolling average will work out the time to launch one rocket based on the last X rockets
    Rockets.get_rolling_average('player', 10)

]]

local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event
local Storage = require("modules/exp_util/storage")
local config = require("modules.exp_legacy.config.gui.rockets") --- @dep config.rockets

local largest_rolling_avg = 0
for _, avg_over in pairs(config.stats.rolling_avg) do
    if avg_over > largest_rolling_avg then
        largest_rolling_avg = avg_over
    end
end

local Rockets = {
    times = {},
    stats = {},
    silos = {},
}

local rocket_times = Rockets.times
local rocket_stats = Rockets.stats
local rocket_silos = Rockets.silos
Storage.register({
    rocket_times = rocket_times,
    rocket_stats = rocket_stats,
    rocket_silos = rocket_silos,
}, function(tbl)
    Rockets.times = tbl.rocket_times
    Rockets.stats = tbl.rocket_stats
    Rockets.silos = tbl.rocket_silos
    rocket_times = Rockets.times
    rocket_stats = Rockets.stats
    rocket_silos = Rockets.silos
end)

--- Gets the silo data for a given silo entity
--- @param silo LuaEntity Rocket silo entity
--- @return table # Data table for this silo, contains rockets launch, silo status, and its force
function Rockets.get_silo_data(silo)
    return rocket_silos[silo.unit_number]
end

--- Gets the silo entity from its silo name, reverse to get_silo_data
--- @param silo_name string Silo name that is stored in its data
--- @return LuaEntity # Rocket silo entity
function Rockets.get_silo_entity(silo_name)
    return rocket_silos[tonumber(silo_name)].entity
end

--- Gets the rocket stats for a force
--- @param force_name string Name of the force to get the stats for
--- @return table # Stats for the force
function Rockets.get_stats(force_name)
    return rocket_stats[force_name] or {}
end

--- Gets all the rocket silos that belong to a force
--- @param force_name string Name of the force to get the silos for
--- @return table # Array of silo data that all belong to this force
function Rockets.get_silos(force_name)
    local rtn = {}
    for _, silo_data in pairs(rocket_silos) do
        if silo_data.force == force_name then
            table.insert(rtn, silo_data)
        end
    end

    return rtn
end

--- Gets the launch time of a given rocket, due to cleaning not all counts are valid
--- @param force_name string Name of the force to get the count for
--- @param rocket_number number Number of the rocket to get the launch time for
--- @return number? # Game tick that the rocket was launched on
function Rockets.get_rocket_time(force_name, rocket_number)
    return rocket_times[force_name] and rocket_times[force_name][rocket_number] or nil
end

--- Gets the number of rockets that a force has launched
--- @param force_name string the name of the force to get the count for
--- @return number # Number of rockets that the force has launched
function Rockets.get_rocket_count(force_name)
    local force = game.forces[force_name]
    return force.rockets_launched
end

--- Gets the total number of rockets launched by all forces
--- @return number # Total number of rockets launched this game
function Rockets.get_game_rocket_count()
    local rtn = 0
    for _, force in pairs(game.forces) do
        rtn = rtn + force.rockets_launched
    end

    return rtn
end

--- Gets the rolling average time to launch a rocket
--- @param force_name string Name of the force to get the average for
--- @param count number Distance to get the rolling average over
--- @return number # Number of ticks required to launch one rocket
function Rockets.get_rolling_average(force_name, count)
    local force = game.forces[force_name]
    local rocket_count = force.rockets_launched
    if rocket_count == 0 then return 0 end
    local last_launch_time = rocket_times[force_name][rocket_count]
    local start_rocket_time = 0
    if count < rocket_count then
        start_rocket_time = rocket_times[force_name][rocket_count - count + 1]
        rocket_count = count
    end
    return math.floor((last_launch_time - start_rocket_time) / rocket_count)
end

--- When a launch is trigger it will wait for the silo to reset
--- @param event EventData.on_rocket_launch_ordered
Event.add(defines.events.on_rocket_launch_ordered, function(event)
    local silo_data = Rockets.get_silo_data(event.rocket_silo)
    assert(silo_data, "Rocket silo missing data: " .. tostring(event.rocket_silo))
    silo_data.launched = silo_data.launched + 1
    silo_data.awaiting_reset = true
end)

--- Event used to update the stats and the hui when a rocket is launched
--- @param event EventData.on_cargo_pod_finished_ascending
Event.add(defines.events.on_cargo_pod_finished_ascending, function(event)
    local force = event.cargo_pod.force
    local force_name = force.name
    local rockets_launched = force.rockets_launched

    --- Handles updates to the rocket stats
    local stats = rocket_stats[force_name]
    if not stats then
        rocket_stats[force_name] = {}
        stats = rocket_stats[force_name]
    end

    if rockets_launched == 1 then
        stats.first_launch = event.tick
        stats.fastest_launch = event.tick
    elseif event.tick - stats.last_launch < stats.fastest_launch then
        stats.fastest_launch = event.tick - stats.last_launch
    end

    stats.last_launch = event.tick

    --- Appends the new rocket into the array
    if not rocket_times[force_name] then
        rocket_times[force_name] = {}
    end

    rocket_times[force_name][rockets_launched] = event.tick

    local remove_rocket = rockets_launched - largest_rolling_avg
    if remove_rocket > 0 and not table.contains(config.milestones, remove_rocket) then
        rocket_times[force_name][remove_rocket] = nil
    end
end)

--- Adds a silo to the list when it is built
--- @param event EventData.on_built_entity | EventData.on_robot_built_entity
local function on_built(event)
    local entity = event.entity
    if entity.valid and entity.name == "rocket-silo" then
        rocket_silos[entity.unit_number] = {
            name = tostring(entity.unit_number),
            force = entity.force.name,
            entity = entity,
            launched = 0,
            awaiting_reset = false,
            built = game.tick,
        }
    end
end

Event.add(defines.events.on_built_entity, on_built)
Event.add(defines.events.on_robot_built_entity, on_built)

return Rockets
