--[[-- Control - Pollution Grading
Makes pollution look much nice of the map, ie not one big red mess
]]

local config = require("modules.exp_legacy.config.pollution_grading")

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

return {
    on_nth_tick = {
        [config.update_delay * 3600] = check_surfaces,
    }
}
