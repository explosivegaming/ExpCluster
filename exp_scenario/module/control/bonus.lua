--[[ Control - Bonus
Various bonus related event handlers

TODO Refactor this fully, this is temp to get it out of the player bonus gui file
]]

local Roles = require("modules/exp_roles")

--- Force bonuses are started at half their max value
local force_bonus = {
    ["worker_robots_battery_modifier"] = {
        max_value = 1,
        value_step = 1,
        scale = 1,
        cost = 1,
        is_percentage = false,
    },
    ["worker_robots_storage_bonus"] = {
        max_value = 1,
        value_step = 1,
        scale = 1,
        cost = 1,
        is_percentage = false,
    },
    ["following_robots_lifetime_modifier"] = {
        max_value = 1,
        value_step = 1,
        scale = 1,
        cost = 1,
        is_percentage = false,
    },

}

--- Surface bonuses are started at half their max value
local surface_bonus = {}

--- @param event EventData.on_force_created
local function apply_force_bonus(event)
    local force = event.force
    for k, v in pairs(force_bonus) do
        force[k] = math.floor(v.max_value / 2)
    end
end

--- @param event EventData.on_surface_created
local function apply_surface_bonus(event)
    local surface = assert(game.get_surface(event.surface_index))
    for k, v in pairs(surface_bonus) do
        surface[k] = math.floor(v.max_value / 2)
    end
end

--- @param event EventData.on_player_died
local function fast_respawn(event)
    local player = assert(game.get_player(event.player_index))
    if Roles.player_has_permission(player, "exp_scenario.player.instant_respawn") then
        player.ticks_to_respawn = 120
    end
end

local e = defines.events

return {
    events = {
        [e.on_force_created] = apply_force_bonus,
        [e.on_surface_created] = apply_surface_bonus,
        [e.on_player_died] = fast_respawn,
    }
}
