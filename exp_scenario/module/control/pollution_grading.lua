--[[-- Control - Pollution Grading
Makes pollution look much nice of the map, ie not one big red mess
]]

local Feature = require("modules/exp_scenario/features")

local feature, config = Feature.register("pollution_grading", {
    reference_point = { -- where pollution is read from
        x = 0,
        y = 0,
    },
    max_scalar = 0.5, -- the scale between true max and max
    min_scalar = 0.17, -- the scale between the lowest max and min
})

local function check_surfaces()
    local max_reference = 0
    for _, surface in pairs(game.surfaces) do
        local reference = surface.get_pollution(config.reference_point)
        if reference > max_reference then
            max_reference = reference
        end
    end

    local max = max_reference * config.max_scalar
    local min = max * config.min_scalar
    local settings = game.map_settings.pollution
    settings.expected_max_per_chunk = max
    settings.min_to_show_per_chunk = min
end

return feature:guard{
    on_nth_tick = {
        [15 * 3600] = check_surfaces,
    },
}
