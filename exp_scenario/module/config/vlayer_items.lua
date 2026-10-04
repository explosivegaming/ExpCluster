--- The items the vlayer can hold and what they do, see control/vlayer.lua
-- @config Vlayer-Items

return {
--- @class Vlayer.ItemProperties
--- @field starting_value number
--- @field required_area number
--- @field production number?
--- @field discharge number?
--- @field capacity number?
--- @field surface_area number?
--- @field fuel_value number?
--- @field power boolean?
--- @field modded boolean? Set when the item is registered from a modded equivalent
--- @field base_game_equivalent string?
--- @field multiplier number?

--- @type table<string, Vlayer.ItemProperties>
allowed_items = { -- List of all items allowed in vlayer storage and their properties
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
        surface_area = 20, -- Tiles
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
        power = false, -- turn all coal to power to reduce trash
    },
    ["solid-fuel"] = {
        starting_value = 0,
        required_area = 0,
        surface_area = 0,
        fuel_value = 12, -- MJ
        power = false, -- turn all solid fuel to power to reduce trash
    },
    ["rocket-fuel"] = {
        starting_value = 0,
        required_area = 0,
        surface_area = 0,
        fuel_value = 100, -- MJ
        power = false, -- turn all rocket fuel to power to reduce trash
    }
},

modded_items = { -- List of all modded items allowed in vlayer storage and their base game equivalent
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
