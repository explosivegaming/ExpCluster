--[[-- Control - Virtual Layer
Stores solar panels, accumulators and landfill in a virtual layer which produces power through interface entities
]]

local ExpUtil = require("modules/exp_util")
local Storage = require("modules/exp_util/storage")
local Feature = require("modules/exp_scenario/features")
local items = require("modules/exp_scenario/config/vlayer_items")

local feature, config = Feature.register("vlayer", {
    unlimited_capacity = false, -- an unlimited energy capacity, accumulators are not required
    unlimited_surface_area = false, -- an unlimited surface area, landfill is not required
    global_surface = false, -- every surface point to the main surface, allowing sharing of power and item
    landfill_area = 20, -- How much area a landfill provide
    interface_limit = { -- how many of each interface per surface can exist
        energy = 1, -- >1 allows for disconnected power networks to receive power
        circuit = -1,
        storage_input = -1,
        storage_output = 1, -- >0 allows for item teleportation of the allowed items
    },
})

local update_tick_storage = 60 -- How frequent the storage updates, in tick
local update_tick_energy = 10 -- How frequent the energy updates, in tick

local floor = math.floor
local min = math.min
local max = math.max
local mega = 1000000

--- @alias ExpScenario_Vlayer.InterfaceType "energy" | "circuit" | "storage_input" | "storage_output"

--- @class Vlayer.ItemProperties
--- @field required_area number
--- @field production table<number, number>? Power output in MW with a quality level key
--- @field input_limit table<number, number>? Power input limit in MW with a quality level key
--- @field output_limit table<number, number>? Power output limit in MW with a quality level key
--- @field capacity table<number, number>? Power capacity in MJ with a quality level key
--- @field surface_area number?

--- @class ExpScenario_Vlayer.Interfaces
--- @field energy LuaEntity[]
--- @field circuit LuaEntity[]
--- @field storage_input LuaEntity[]
--- @field storage_output LuaEntity[]

--- @class ExpScenario_Vlayer.Properties
--- @field total_surface_area number Tiles provided by landfill
--- @field used_surface_area number Tiles taken by allocated items
--- @field total_production number MW of every solar panel stored, allocated or not
--- @field production number Power output
--- @field input_limit number Power input limit
--- @field output_limit number Power output limit
--- @field capacity number MJ the allocated accumulators can hold

--- @class ExpScenario_Vlayer.Storage
--- @field items table<string, table<number, number>> Every stored item, allocated or not
--- @field unallocated table<string, table<number, number>> Items waiting for surface area
--- @field energy number J

--- @class ExpScenario_Vlayer.Statistics
--- @field total_surface_area number
--- @field used_surface_area number
--- @field remaining_surface_area number Surface area left after the unallocated items are counted
--- @field surface_area number
--- @field production_multiplier number
--- @field energy_max number W when the sun is up
--- @field energy_production number W right now
--- @field energy_total_production number W sustained if every stored solar panel was allocated
--- @field energy_sustained number W averaged over a day
--- @field energy_capacity number J
--- @field energy_storage number J

--- @class ExpScenario_Vlayer.SurfaceData
--- @field interfaces ExpScenario_Vlayer.Interfaces
--- @field properties ExpScenario_Vlayer.Properties
--- @field storage ExpScenario_Vlayer.Storage

--- @alias ExpScenario_Vlayer.Data ExpScenario_Vlayer.SurfaceData[]

--- @class ExpScenario_Vlayer
local Vlayer = {
    --- The config of the feature, read only
    config = config,
    feature = feature,
    --- @package
    events = {},
    --- @package
    on_nth_tick = {},
}

local quality_level_to_name = {}
local quality_name_to_level = {}

for _, q in pairs(prototypes.quality) do
    quality_level_to_name[q.level] = q.name
    quality_name_to_level[q.name] = q.level
end

--- The properties of every allowed item
local allowed_items = {} --- @type table<string, Vlayer.ItemProperties>

for _, name in pairs(items.allowed_categories["production"]) do
    local item_in_category = prototypes.get_entity_filtered{filters = {filter = "type", type = name}}

    for _, item in pairs(item_in_category) do
        local item_name = item.name

        allowed_items[item_name] = {
            required_area = item.tile_width * item.tile_height,
        }

        -- Quality affected items
        allowed_items[item_name]["production"] = {}

        for l, n in pairs(quality_level_to_name) do
            -- the number is per tick
            allowed_items[item_name]["production"][l] = item.get_max_energy_production(n) * 60 / mega or 0 -- W -> MW
        end
    end
end

for _, name in pairs(items.allowed_categories["storage"]) do
    local item_in_category = prototypes.get_entity_filtered{filters = {filter = "type", type = name}}

    for _, item in pairs(item_in_category) do
        local item_name = item.name

        allowed_items[item_name] = {
            required_area = item.tile_width * item.tile_height,
        }

        -- Quality affected items
        allowed_items[item_name]["input_limit"] = {}
        allowed_items[item_name]["output_limit"] = {}
        allowed_items[item_name]["capacity"] = {}
        local i_eesp = item.electric_energy_source_prototype

        for l, n in pairs(quality_level_to_name) do
            allowed_items[item_name]["input_limit"][l] = i_eesp and i_eesp.get_input_flow_limit(n) / mega or 0 -- W -> MW
            allowed_items[item_name]["output_limit"][l] = i_eesp and i_eesp.get_output_flow_limit(n) / mega or 0  -- W -> MW
            allowed_items[item_name]["capacity"][l] = i_eesp and i_eesp.buffer_capacity * prototypes.quality[n].accumulator_capacity_multiplier / mega or 0  -- J -> MJ
        end
    end
end

allowed_items["landfill"] = {
    required_area = 0,
    surface_area = config.landfill_area
}

--- @type ExpScenario_Vlayer.Data
local vlayer_data = {}

--- @param surface_index number
local function update_surface(surface_index)
    if vlayer_data[surface_index] then return end

    -- global surface will have its data point to the main surface
    if config.global_surface and vlayer_data[1] then return end

    vlayer_data[surface_index] = {
        interfaces = {
            energy = {},
            circuit = {},
            storage_input = {},
            storage_output = {},
        },
        properties = {
            total_surface_area = 0,
            used_surface_area = 0,
            total_production = 0,
            production = 0,
            input_limit = 0,
            output_limit = 0,
            capacity = 0,
        },
        storage = {
            items = {},
            unallocated = {},
            energy = 0,
        }
    }
end

update_surface(1)

Storage.register(vlayer_data, function(tbl)
    vlayer_data = tbl
end)

--- Interface entities are neutral so players can not mine them, these are the prototypes used for each type
local interface_names = {
    energy = "electric-energy-interface",
    circuit = "constant-combinator",
    storage_input = "storage-chest",
    storage_output = "requester-chest",
} --- @type table<ExpScenario_Vlayer.InterfaceType, string>

local interface_types = {} --- @type table<string, ExpScenario_Vlayer.InterfaceType>
for interface_type, name in pairs(interface_names) do
    interface_types[name] = interface_type
end

--- Statistics exposed on circuit interfaces and the signal each is sent as
local circuit_signals = {
    total_surface_area = "signal-A",
    used_surface_area = "signal-U",
    remaining_surface_area = "signal-R",
    production_multiplier = "signal-M",
    energy_production = "signal-P",
    energy_sustained = "signal-S",
    energy_capacity = "signal-C",
    energy_storage = "signal-E",
} --- @type table<string, string>

local circuit_description = {}
for stat_name, signal_name in pairs(circuit_signals) do
    circuit_description[#circuit_description + 1] = string.format("[virtual-signal=%s] = %s", signal_name, stat_name:gsub("_", " "))
end
circuit_description = table.concat(circuit_description, "\n")

--- Get every stored item keyed by name, allocated or not
--- @param s_index number Surface index
--- @return table<string, table<number, number>>
function Vlayer.get_items(s_index)
    local vd = assert(config.global_surface and vlayer_data[1] or vlayer_data[s_index])
    return vd.storage.items
end

--- Get the items waiting for surface area keyed by name
--- @param s_index number Surface index
--- @return table<string, table<number, number>>
function Vlayer.get_unallocated_items(s_index)
    local vd = assert(config.global_surface and vlayer_data[1] or vlayer_data[s_index])
    return vd.storage.unallocated
end

--- Get the items which contribute to the properties keyed by name
--- @param s_index number Surface index
--- @return table<string, table<number, number>>
function Vlayer.get_allocated_items(s_index)
    local allocated = {}
    local vd = assert(config.global_surface and vlayer_data[1] or vlayer_data[s_index])
    local storage = vd.storage
    local unallocated = storage.unallocated
    for name, qnc in pairs(storage.items) do
        allocated[name] = {}
        for quality, count in pairs(qnc) do
            allocated[name][quality] = count - (unallocated[name] and unallocated[name][quality] or 0)
        end
    end
    return allocated
end

--- Get the interface entities of each type, do not modify
--- @param s_index number Surface index
--- @return ExpScenario_Vlayer.Interfaces
function Vlayer.get_interfaces(s_index)
    local vd = assert(config.global_surface and vlayer_data[1] or vlayer_data[s_index])
    return vd.interfaces
end

--- Get the signal each statistic is sent as on circuit interfaces
--- @return table<string, string>
function Vlayer.get_circuits()
    return circuit_signals
end

--- Surface area left once the unallocated items have taken what they need
--- @param s_index number Surface index
--- @return number
local function get_remaining_surface_area(s_index)
    local vd = assert(config.global_surface and vlayer_data[1] or vlayer_data[s_index])
    local properties = vd.properties
    local unallocated = vd.storage.unallocated
    local remaining = properties.total_surface_area - properties.used_surface_area
    for name, qnc in pairs(unallocated) do
        for _, count in pairs(qnc) do
            remaining = remaining - allowed_items[name].required_area * count
        end
    end
    return remaining
end

--- Fraction of solar production available right now, from the darkness of a real surface or the config day cycle
--- @param s_index number Surface index
--- @return number
local function get_production_multiplier(s_index)
    local surface = assert(config.global_surface and game.surface[1] or game.surfaces[s_index]) --[[@as LuaSurface]]
    local multiplier = surface.solar_power_multiplier
    if surface.always_day then
        return multiplier
    end

    if surface.darkness then
        local brightness = 1 - surface.darkness
        if brightness < surface.min_brightness then
            return 0
        end
        return multiplier * (brightness - surface.min_brightness) / (1 - surface.min_brightness)
    end

    local daytime = (game.tick % surface.ticks_per_day) / surface.ticks_per_day
    surface.daytime = daytime
    if daytime <= surface.dusk then
        return multiplier
    elseif daytime <= surface.evening then
        return multiplier * (1 - (daytime - surface.dusk) / (surface.evening - surface.dusk))
    elseif daytime <= surface.morning then
        return 0
    elseif daytime <= surface.dawn then
        return multiplier * (daytime - surface.morning) / (surface.dawn - surface.morning)
    end
    return multiplier
end

--- Fraction of solar production averaged over a whole day, sunrise and sunset count for half
--- @param s_index number Surface index
--- @return number
local function get_sustained_multiplier(s_index)
    local surface = assert(config.global_surface and game.surface[1] or game.surfaces[s_index]) --[[@as LuaSurface]]
    local multiplier = surface.solar_power_multiplier
    if surface.always_day then
        return multiplier
    end

    local day_duration = 1 - surface.dawn + surface.dusk
    local sunset_duration = surface.evening - surface.dusk
    local sunrise_duration = surface.dawn - surface.morning
    return multiplier * (day_duration + 0.5 * (sunset_duration + sunrise_duration))
end

--- Apply the properties of an item to the layer, a negative count deallocates
--- @param s_index number Surface index
--- @param name string
--- @param count number
--- @param quality_level number
local function allocate_item(s_index, name, count, quality_level)
    local item = allowed_items[name]
    local vd = assert(config.global_surface and vlayer_data[1] or vlayer_data[s_index])
    local properties = vd.properties
    if item.production then
        local prod = item.production[quality_level] * count
        properties.production = properties.production + prod
        properties.total_production = properties.total_production + prod
    end
    for _, v in pairs({'input_limit', 'output_limit', 'capacity'}) do
        if item[v] then
            properties[v] = properties[v] + item[v][quality_level] * count
        end
    end
    if not item.surface_area then return end
    local area = item.surface_area * count
    properties.total_surface_area = properties.total_surface_area + area
    if item.required_area == 0 then return end
    properties.used_surface_area = properties.used_surface_area + area
end

--- Count the production of items which are stored but not allocated, so the total shows what more surface area would give
--- @param s_index number Surface index
--- @param name string
--- @param count number
--- @param quality_level number
local function count_unallocated_production(s_index, name, count, quality_level)
    local item = allowed_items[name]
    local vd = assert(config.global_surface and vlayer_data[1] or vlayer_data[s_index])
    local properties = vd.properties
    if item.production then
        properties.total_production = properties.total_production + item.production[quality_level] * count
    end
end

--- Store an item, it is allocated straight away when there is surface area for it
--- @param s_index number Surface index
--- @param name string
--- @param count number
--- @param quality_level number
function Vlayer.insert_item(s_index, name, count, quality_level)
    local item = assert(allowed_items[name], "Item not allowed in the vlayer: " .. name)
    local vd = assert(config.global_surface and vlayer_data[1] or vlayer_data[s_index])
    local storage = vd.storage
    if not storage.items[name] then storage.items[name] = {} end
    if not storage.items[name][quality_level] then storage.items[name][quality_level] = 0 end
    if not storage.unallocated[name] then storage.unallocated[name] = {} end
    if not storage.unallocated[name][quality_level] then storage.unallocated[name][quality_level] = 0 end
    storage.items[name][quality_level] = storage.items[name][quality_level] + count

    if config.unlimited_surface_area or item.required_area == 0 then
        allocate_item(s_index, name, count, quality_level)
        return
    end

    local properties = vd.properties
    local surplus_area = properties.total_surface_area - properties.used_surface_area
    local allocated = min(count, floor(surplus_area / item.required_area))
    if allocated > 0 then
        allocate_item(s_index, name, allocated, quality_level)
    end

    local unallocated = count - allocated
    if unallocated > 0 then
        storage.unallocated[name][quality_level] = storage.unallocated[name][quality_level] + unallocated
        count_unallocated_production(s_index, name, unallocated, quality_level)
    end
end

--- Take an item out, unallocated items go first and landfill can only go while nothing is using its area
--- @param s_index number Surface index
--- @param name string
--- @param count number
--- @param quality_level number
--- @return number # The count actually removed
function Vlayer.remove_item(s_index, name, count, quality_level)
    local item = assert(allowed_items[name], "Item not allowed in the vlayer: " .. name)
    local vd = assert(config.global_surface and vlayer_data[1] or vlayer_data[s_index])
    local storage = vd.storage
    local removed = 0

    if not config.unlimited_surface_area and item.required_area > 0 then
        removed = min(count, storage.unallocated[name][quality_level])
        storage.items[name][quality_level] = storage.items[name][quality_level] - removed
        storage.unallocated[name][quality_level] = storage.unallocated[name][quality_level] - removed
        count_unallocated_production(s_index, name, -removed, quality_level)
        count = count - removed
        if count == 0 then
            return removed
        end
    end

    local properties = vd.properties
    local deallocate = min(count, storage.items[name][quality_level])
    if item.surface_area and item.surface_area > 0 then
        local surplus_area = properties.total_surface_area - properties.used_surface_area
        deallocate = min(deallocate, floor(surplus_area / item.surface_area))
        if deallocate <= 0 then
            return removed
        end
    end

    storage.items[name][quality_level] = storage.items[name][quality_level] - deallocate
    allocate_item(s_index, name, -deallocate, quality_level)
    return removed + deallocate
end

--- Add or take energy, used by other modules which spend the stored energy
--- @param s_index number Surface index
--- @param energy number J, negative to take
--- @return number # J stored afterwards
function Vlayer.energy_changed(s_index, energy)
    local vd = assert(config.global_surface and vlayer_data[1] or vlayer_data[s_index])
    local storage = vd.storage
    storage.energy = storage.energy + energy
    return storage.energy
end

--- Get the statistics of the layer
--- @param s_index number Surface index
--- @return ExpScenario_Vlayer.Statistics
function Vlayer.get_statistics(s_index)
    local vd = assert(config.global_surface and vlayer_data[1] or vlayer_data[s_index])
    local properties = vd.properties
    local production = properties.production * mega
    local production_multiplier = get_production_multiplier(s_index)
    local sustained_multiplier = get_sustained_multiplier(s_index)
    local remaining_surface_area = get_remaining_surface_area(s_index)

    return {
        total_surface_area = properties.total_surface_area,
        used_surface_area = properties.used_surface_area,
        remaining_surface_area = remaining_surface_area,
        surface_area = properties.total_surface_area - remaining_surface_area,
        production_multiplier = production_multiplier,
        energy_max = production,
        energy_production = production * production_multiplier,
        energy_total_production = properties.total_production * sustained_multiplier * mega,
        energy_sustained = production * sustained_multiplier,
        energy_capacity = properties.capacity * mega,
        energy_storage = vd.storage.energy,
    }
end

--- Make an entity into an interface which players can not mine or damage
--- @param s_index number Surface index
--- @param interface LuaEntity
--- @param interface_type ExpScenario_Vlayer.InterfaceType
--- @param player LuaPlayer?
local function register_interface(s_index, interface, interface_type, player)
    local vd = assert(config.global_surface and vlayer_data[1] or vlayer_data[s_index])
    local interfaces = vd.interfaces[interface_type]
    interfaces[#interfaces + 1] = interface
    interface.last_user = player
    interface.destructible = false
    interface.minable_flag = false
end

--- Create an interface which powers the electric network it is placed in
--- @param surface LuaSurface
--- @param position MapPosition
--- @param player LuaPlayer?
--- @return LuaEntity? # Nil when the interface does not fit
function Vlayer.create_energy_interface(surface, position, player)
    if not surface.can_place_entity{ name = interface_names.energy, position = position } then
        return nil
    end

    local interface = assert(surface.create_entity{ name = interface_names.energy, position = position, force = "neutral" })
    register_interface(surface.index, interface, "energy", player)
    interface.operable = false
    interface.electric_buffer_size = 0
    interface.power_production = 0
    interface.power_usage = 0
    interface.energy = 0
    return interface
end

--- Create an interface which outputs the statistics and stored items as signals
--- @param surface LuaSurface
--- @param position MapPosition
--- @param player LuaPlayer?
--- @return LuaEntity
function Vlayer.create_circuit_interface(surface, position, player)
    local interface = assert(surface.create_entity{ name = interface_names.circuit, position = position, force = "neutral" })
    register_interface(surface.index, interface, "circuit", player)
    interface.combinator_description = circuit_description
    return interface
end

--- Create an interface which stores every allowed item put into it
--- @param surface LuaSurface
--- @param position MapPosition
--- @param player LuaPlayer?
--- @return LuaEntity
function Vlayer.create_input_interface(surface, position, player)
    local interface = assert(surface.create_entity{ name = interface_names.storage_input, position = position, force = "neutral" })
    register_interface(surface.index, interface, "storage_input", player)
    -- A filter nothing can match stops robots filling it with anything
    interface.storage_filter = { name = "deconstruction-planner", quality = "normal" }
    return interface
end

--- Create an interface which takes stored items out to fulfil its requests
--- @param surface LuaSurface
--- @param position MapPosition
--- @param player LuaPlayer?
--- @return LuaEntity
function Vlayer.create_output_interface(surface, position, player)
    local interface = assert(surface.create_entity{ name = interface_names.storage_output, position = position, force = "neutral" })
    register_interface(surface.index, interface, "storage_output", player)
    return interface
end

--- Remove an interface, anything it holds is dropped in a chest next to it and stored energy is kept
--- @param interface LuaEntity
--- @return ExpScenario_Vlayer.InterfaceType
function Vlayer.remove_interface(interface)
    local s_index = interface.surface.index
    local vd = assert(config.global_surface and vlayer_data[1] or vlayer_data[s_index])
    local storage = vd.storage
    local interfaces = vd.interfaces
    local interface_type = assert(interface_types[interface.name], "Entity is not a vlayer interface: " .. interface.name)
    if interface_type == "storage_input" or interface_type == "storage_output" then
        ExpUtil.transfer_inventory_to_surface{
            inventory = assert(interface.get_inventory(defines.inventory.chest)),
            surface = interface.surface,
            name = "iron-chest",
            allow_creation = true,
        }
    elseif interface_type == "energy" then
        storage.energy = storage.energy + interface.energy
    end

    table.remove_element(interfaces[interface_type], interface)
    interface.destroy()
    return interface_type
end

--- Forget interfaces which no longer exist
--- @param interfaces LuaEntity[]
local function prune_interfaces(interfaces)
    for index = #interfaces, 1, -1 do
        if not interfaces[index].valid then
            table.remove(interfaces, index)
        end
    end
end

--- Store the contents of the input interfaces
local function handle_input_interfaces()
    for s_index, prop in pairs(vlayer_data) do
        local interfaces = prop.interfaces.storage_input
        prune_interfaces(interfaces)
        for _, interface in ipairs(interfaces) do
            local inventory = assert(interface.get_inventory(defines.inventory.chest))
            for _, item in pairs(inventory.get_contents()) do
                local name = item.name
                local count = item.count
                local quality = item.quality
                if allowed_items[name] then
                    Vlayer.insert_item(s_index, name, count, quality_name_to_level[quality])
                    inventory.remove{ name = name, count = count, quality = quality }
                end
            end
        end
    end
end

--- Fill the requests of the output interfaces from storage
local function handle_output_interfaces()
    for s_index, prop in pairs(vlayer_data) do
        local interfaces = prop.interfaces.storage_output
        prune_interfaces(interfaces)
        for _, interface in ipairs(interfaces) do
            local inventory = assert(interface.get_inventory(defines.inventory.chest))
            for _, section in ipairs(assert(interface.get_logistic_sections()).sections) do
                for _, filter in pairs(section.filters) do
                    local name = filter.value and filter.value.name
                    local quality = filter.value and filter.value.quality
                    if name and allowed_items[name] then
                        local quality_level = quality_name_to_level[quality]
                        local wanted = min(assert(filter.min) - inventory.get_item_count(name), prop.storage.items[name][quality_level])
                        if wanted > 0 and inventory.can_insert{ name = name, count = wanted, quality = quality } then
                            local removed = Vlayer.remove_item(s_index, name, wanted, quality_level)
                            if removed > 0 then
                                inventory.insert{ name = name, count = removed, quality = quality }
                            end
                        end
                    end
                end
            end
        end
    end
end

--- Allocate waiting items in proportion to the surface area that has become available
local function handle_unallocated()
    if config.unlimited_surface_area then return end
    for s_index, prop in pairs(vlayer_data) do
        local unallocated_area = 0
        for name, qnc in pairs(prop.storage.unallocated) do
            for _, count in pairs(qnc) do
                unallocated_area = unallocated_area + allowed_items[name].required_area * count
            end
        end
        if unallocated_area > 0 then
            local properties = prop.properties
            local surplus_area = properties.total_surface_area - properties.used_surface_area
            for name, qnc in pairs(prop.storage.unallocated) do
                for quality, count in pairs(qnc) do
                    local allocated = min(count, floor(count * surplus_area / unallocated_area))
                    if allocated > 0 then
                        prop.storage.unallocated[name][quality] = count - allocated
                        allocate_item(s_index, name, allocated, quality)
                        count_unallocated_production(s_index, name, -allocated, quality)
                    end
                end
            end
        end
    end
end

--- Set the signals of the circuit interfaces to the statistics and stored items
local function handle_circuit_interfaces()
    for s_index, prop in pairs(vlayer_data) do
        local interfaces = prop.interfaces.circuit
        prune_interfaces(interfaces)
        if #interfaces > 0 then
            local stats = Vlayer.get_statistics(s_index)
            for _, interface in ipairs(interfaces) do
                local control = interface.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
                if control.sections_count == 0 then
                    control.add_section()
                end
                local section = assert(control.sections[1])

                -- Slots are cleared first because an item can not be set in two slots at once
                for index = section.filters_count, 1, -1 do
                    section.clear_slot(index)
                end

                local index = 1
                for stat_name, signal_name in pairs(circuit_signals) do
                    local value = stats[stat_name] --[[@as number]]
                    if stat_name:find("energy") then
                        value = value / mega
                    elseif stat_name == "production_multiplier" then
                        value = value * 10000
                    end
                    section.set_slot(index, { value = { type = "virtual", name = signal_name, quality = "normal" }, min = floor(value) })
                    index = index + 1
                end

                for name, qnc in pairs(prop.storage.items) do
                    for quality, count in pairs(qnc) do
                        if count > 0 then
                            section.set_slot(index, { value = { type = "item", name = name, quality = quality_level_to_name[quality] }, min = count })
                            index = index + 1
                        end
                    end
                end
            end
        end
    end
end

--- Produce energy, share it between the energy interfaces, and burn fuel when storage runs low
local function handle_energy_interfaces()
    for s_index, prop in pairs(vlayer_data) do
        local storage = prop.storage
        local properties = prop.properties
        local production = properties.production
        local min_input = min(properties.input_limit, production * get_production_multiplier(s_index))
        storage.energy = storage.energy + floor(min_input * mega * update_tick_energy / 60)

        local interfaces = prop.interfaces.energy
        prune_interfaces(interfaces)
        if #interfaces > 0 then
            local available_energy = storage.energy
            for _, interface in ipairs(interfaces) do
                available_energy = available_energy + interface.energy
            end

            local discharge_rate = 2 * (production + properties.output_limit * mega) / #interfaces
            local fill_to = min(discharge_rate, floor(available_energy / #interfaces))
            for _, interface in ipairs(interfaces) do
                interface.electric_buffer_size = max(discharge_rate, interface.energy) -- A smaller buffer would lose energy
                local delta = fill_to - interface.energy
                storage.energy = storage.energy - delta
                interface.energy = interface.energy + delta
            end
        end

        local capacity = properties.capacity * mega
        if not config.unlimited_capacity and storage.energy > capacity then
            storage.energy = capacity
        end
    end
end

--- Move items between the interfaces and storage
local function update_storage()
    handle_input_interfaces()
    handle_output_interfaces()
    handle_unallocated()
end

--- Update the signals and energy of the interfaces
local function update_energy()
    handle_circuit_interfaces()
    handle_energy_interfaces()
end

local e = defines.events

Vlayer.on_init = update_surface -- The default surface exists before on_surface_created can fire
Vlayer.events[e.on_surface_created] = function(event) update_surface(event.surface_index) end
Vlayer.events[e.on_surface_renamed] = function(event) update_surface(event.surface_index) end
Vlayer.events[e.on_surface_imported] = function(event) update_surface(event.surface_index) end
Vlayer.on_nth_tick[update_tick_storage] = update_storage
Vlayer.on_nth_tick[update_tick_energy] = update_energy

return feature:guard(Vlayer)
