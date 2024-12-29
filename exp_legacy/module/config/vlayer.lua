--- Settings for vlayer including the allowed items, the update frequency, and some cheats
-- @config Vlayer

return {
    update_tick_storage = 60, --- @setting update_tick_storage The number of ticks between each update of the storage interfaces
    update_tick_energy = 10, --- @setting update_tick_energy The number of ticks between each update of the energy and circuit interfaces
    update_tick_gui = 60, --- @setting update_tick_gui The number of ticks between each update of the gui

    unlimited_capacity = false, --- @setting unlimited_capacity When true the vlayer has an unlimited energy capacity, accumulators are not required
    unlimited_surface_area = false, --- @setting unlimited_surface_area When true the vlayer has an unlimited surface area, landfill is not required
    modded_auto_downgrade = false, --- @setting modded_auto_downgrade When true modded items will be converted into their base game equivalent, original items can not be recovered

    mimic_surface = "nauvis", --- @setting mimic_surface Surface name/index the vlayer will copy its settings from, use nil to use the settings below
    surface = { --- @setting surface When mimic_surface is nil these settings will be used instead, see LuaSurface for details
        always_day = false,
        solar_power_multiplier = 1,
        min_brightness = 0.15,
        ticks_per_day = 25200,
        daytime = 0,
        dusk = 0.25,
        evening = 0.45,
        morning = 0.55,
        dawn = 0.75,
    },

    interface_limit = { --- @setting interface_limit Sets the limit for the number of vlayer interfaces that can be created
        energy = 1, -- >1 allows for disconnected power networks to receive power
        circuit = 20, -- No caveats
        storage_input = 20, -- No caveats
        storage_output = 1, -- >0 allows for item teleportation (allowed_items only)
    },

    allowed_items = { --- @setting allowed_items List of all items allowed in vlayer storage and their properties
        --[[
            Allowed properties:
            starting_value : The amount of the item placed into the vlayer on game start, ignores area requirements
            required_area : When greater than 0 the items properties are not applied unless their is sufficient surplus surface area
            production : The energy production of the item in MW, used for solar panels
            discharge : The energy discharge of the item in MW, used for accumulators
            capacity : The energy capacity of the item in MJ, used for accumulators
            surface_area : The surface area provided by the item, used for landfill
        ]]
        ["solar-panel"] = {
            starting_value = 0,
            required_area = 9,
            production = 0.06, -- MW
        },
        ["accumulator"] = {
            starting_value = 0,
            required_area = 4,
            discharge = 0.3, -- MW
            capacity = 5, -- MJ
        },
        ["landfill"] = {
            starting_value = 0,
            required_area = 0,
            surface_area = 8, -- Tiles
        },
        ["wood"] = {
            starting_value = 0,
            required_area = 0,
            surface_area = 0,
            fuel_value = 2, -- MJ
            power = true, -- turn all wood to power to reduce trash
        },
        ["coal"] = {
            starting_value = 0,
            required_area = 0,
            surface_area = 0,
            fuel_value = 4, -- MJ
            power = true, -- turn all coal to power to reduce trash
        },
        ["solid-fuel"] = {
            starting_value = 0,
            required_area = 0,
            surface_area = 0,
            fuel_value = 12, -- MJ
            power = true, -- turn all solid fuel to power to reduce trash
        },
        ["rocket-fuel"] = {
            starting_value = 0,
            required_area = 0,
            surface_area = 0,
            fuel_value = 100, -- MJ
            power = true, -- turn all rocket fuel to power to reduce trash
        }
        --[[
        ["iron-ore"] = {
            starting_value = 0,
            required_area = 0,
            surface_area = 0,
        },
        ["copper-ore"] = {
            starting_value = 0,
            required_area = 0,
            surface_area = 0,
        },
        ["stone"] = {
            starting_value = 0,
            required_area = 0,
            surface_area = 0,
        },
        ["uranium-ore"] = {
            starting_value = 0,
            required_area = 0,
            surface_area = 0,
        },
        ]]
    },

    modded_items = { --- @setting modded_items List of all modded items allowed in vlayer storage and their base game equivalent
        ["solar-panel-2"] = {
            starting_value = 0,
            base_game_equivalent = "solar-panel",
            multiplier = 4,
        },
        ["solar-panel-3"] = {
            starting_value = 0,
            base_game_equivalent = "solar-panel",
            multiplier = 16,
        },
        ["solar-panel-4"] = {
            starting_value = 0,
            base_game_equivalent = "solar-panel",
            multiplier = 64,
        },
        ["solar-panel-5"] = {
            starting_value = 0,
            base_game_equivalent = "solar-panel",
            multiplier = 256,
        },
        ["solar-panel-6"] = {
            starting_value = 0,
            base_game_equivalent = "solar-panel",
            multiplier = 1024,
        },
        ["solar-panel-7"] = {
            starting_value = 0,
            base_game_equivalent = "solar-panel",
            multiplier = 4096,
        },
        ["solar-panel-8"] = {
            starting_value = 0,
            base_game_equivalent = "solar-panel",
            multiplier = 16384,
        },
        ["accumulator-2"] = {
            starting_value = 0,
            base_game_equivalent = "accumulator",
            multiplier = 4,
        },
        ["accumulator-3"] = {
            starting_value = 0,
            base_game_equivalent = "accumulator",
            multiplier = 16,
        },
        ["accumulator-4"] = {
            starting_value = 0,
            base_game_equivalent = "accumulator",
            multiplier = 64,
        },
        ["accumulator-5"] = {
            starting_value = 0,
            base_game_equivalent = "accumulator",
            multiplier = 256,
        },
        ["accumulator-6"] = {
            starting_value = 0,
            base_game_equivalent = "accumulator",
            multiplier = 1024,
        },
        ["accumulator-7"] = {
            starting_value = 0,
            base_game_equivalent = "accumulator",
            multiplier = 4096,
        },
        ["accumulator-8"] = {
            starting_value = 0,
            base_game_equivalent = "accumulator",
            multiplier = 16384,
        },
    }
}
