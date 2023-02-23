-- Vlayer Config
-- @config Vlayer

return {
    enabled = true,
    update_tick = 10,
    -- 1 MJ
    energy_input_min = 1000000,
    energy_limit = 1000000000000,
    land = {
        enabled = false,
        tile = "landfill",
        result = 4
    },
    always_day = false,
    battery_limit = true,
    interface_limit = {
        storage_input = 1,
        energy_input = 1,
        energy_output = 1,
        circuit = 1
    }
}