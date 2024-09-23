--- Makes polution look much nice of the map, ie not one big red mess
-- @addon Pollution-Grading

local Event = require 'utils.event' --- @dep utils.event
local config = require 'config.pollution_grading' --- @dep config.pollution_grading

local delay = config.update_delay * 3600 -- convert from minutes to ticks
Event.on_nth_tick(delay, function()
    local surface = game.surfaces[1]
    local true_max = surface.get_pollution(config.reference_point)
    local max = true_max*config.max_scalar
    local min = max*config.min_scalar
    local settings = game.map_settings.pollution
    settings.expected_max_per_chunk = max
    settings.min_to_show_per_chunk = min
end)