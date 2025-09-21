--[[ Control - Bonus
Various bonus related event handlers

TODO Refactor this fully, this is temp to get it out of the player bonus gui file
]]

local Roles = require("modules/exp_legacy/expcore/roles")
local config = require("modules/exp_legacy/config/bonus")

--- @param event EventData.on_force_created
local function apply_force_bonus(event)
    local force = event.force
    for k, v in pairs(config.force_bonus) do
        force[k] = v.initial_value
    end
end

--- @param event EventData.on_surface_created
local function apply_surface_bonus(event)
    local surface = assert(game.get_surface(event.surface_index))
    for k, v in pairs(config.surface_bonus) do
        surface[k] = v.initial_value
    end
end

--- @param event EventData.on_player_died
local function fast_respawn(event)
    local player = assert(game.get_player(event.player_index))
    if Roles.player_has_flag(player, "instant-respawn") then
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
