--[[-- Control - Virtual Layer
Stores solar panels, accumulators and landfill in a virtual layer which produces power through interface entities
]]

local ExpUtil = require("modules/exp_util")
local Storage = require("modules/exp_util/storage")
local config = require("modules.exp_legacy.config.vlayer")

local floor = math.floor
local min = math.min
local max = math.max
local mega = 1000000

--- @alias ExpScenario_Vlayer.InterfaceType "energy" | "circuit" | "storage_input" | "storage_output"

--- @class ExpScenario_Vlayer.Interfaces
--- @field energy LuaEntity[]
--- @field circuit LuaEntity[]
--- @field storage_input LuaEntity[]
--- @field storage_output LuaEntity[]

--- @class ExpScenario_Vlayer.Properties
--- @field total_surface_area number Tiles provided by landfill
--- @field used_surface_area number Tiles taken by allocated items
--- @field total_production number MW of every solar panel stored, allocated or not
--- @field production number MW of the allocated solar panels
--- @field discharge number MW the allocated accumulators can discharge
--- @field capacity number MJ the allocated accumulators can hold

--- @class ExpScenario_Vlayer.PowerItem
--- @field value number J released by burning one
--- @field count number

--- @class ExpScenario_Vlayer.Storage
--- @field items table<string, number> Every stored item, allocated or not
--- @field unallocated table<string, number> Items waiting for surface area
--- @field power_items table<string, ExpScenario_Vlayer.PowerItem> Fuel burned when the stored energy is low
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

--- @class ExpScenario_Vlayer.Data
--- @field interfaces ExpScenario_Vlayer.Interfaces
--- @field properties ExpScenario_Vlayer.Properties
--- @field storage ExpScenario_Vlayer.Storage
--- @field surface LuaSurface | table The surface the day cycle is taken from, or a copy of the config settings

--- @class ExpScenario_Vlayer
local Vlayer = {
    --- @package
    events = {},
    --- @package
    on_nth_tick = {},
}

--- The properties of every allowed item, modded items are derived from their base game equivalent
local allowed_items = {} --- @type table<string, Vlayer.ItemProperties>
for name, properties in pairs(config.allowed_items) do
    allowed_items[name] = properties
end
for name, properties in pairs(config.modded_items) do
    local base = config.allowed_items[properties.base_game_equivalent]
    local multiplier = properties.multiplier
    allowed_items[name] = {
        starting_value = properties.starting_value or 0,
        required_area = base.required_area or 0,
        surface_area = (base.surface_area or 0) * multiplier,
        production = (base.production or 0) * multiplier,
        capacity = (base.capacity or 0) * multiplier,
    }
end

--- @type ExpScenario_Vlayer.Data
local vlayer_data = {
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
        discharge = 0,
        capacity = 0,
    },
    storage = {
        items = {},
        unallocated = {},
        power_items = {},
        energy = 0,
    },
    surface = table.deep_copy(config.surface),
}

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
--- @return table<string, number>
function Vlayer.get_items()
    return vlayer_data.storage.items
end

--- Get the items waiting for surface area keyed by name
--- @return table<string, number>
function Vlayer.get_unallocated_items()
    return vlayer_data.storage.unallocated
end

--- Get the items which contribute to the properties keyed by name
--- @return table<string, number>
function Vlayer.get_allocated_items()
    local allocated = {}
    local unallocated = vlayer_data.storage.unallocated
    for name, count in pairs(vlayer_data.storage.items) do
        allocated[name] = count - (unallocated[name] or 0)
    end
    return allocated
end

--- Get the interface entities of each type, do not modify
--- @return ExpScenario_Vlayer.Interfaces
function Vlayer.get_interfaces()
    return vlayer_data.interfaces
end

--- Get the signal each statistic is sent as on circuit interfaces
--- @return table<string, string>
function Vlayer.get_circuits()
    return circuit_signals
end

--- Surface area left once the unallocated items have taken what they need
--- @return number
local function get_remaining_surface_area()
    local properties = vlayer_data.properties
    local remaining = properties.total_surface_area - properties.used_surface_area
    for name, count in pairs(vlayer_data.storage.unallocated) do
        remaining = remaining - allowed_items[name].required_area * count
    end
    return remaining
end

--- Fraction of solar production available right now, from the darkness of a real surface or the config day cycle
--- @return number
local function get_production_multiplier()
    local surface = vlayer_data.surface
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
--- @return number
local function get_sustained_multiplier()
    local surface = vlayer_data.surface
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
--- @param name string
--- @param count number
local function allocate_item(name, count)
    local item = allowed_items[name]
    local properties = vlayer_data.properties
    if item.production then
        properties.production = properties.production + item.production * count
        properties.total_production = properties.total_production + item.production * count
    end
    if item.capacity then
        properties.capacity = properties.capacity + item.capacity * count
    end
    if item.discharge then
        properties.discharge = properties.discharge + item.discharge * count
    end
    if item.surface_area then
        properties.total_surface_area = properties.total_surface_area + item.surface_area * count
    end
    if item.required_area > 0 then
        properties.used_surface_area = properties.used_surface_area + item.required_area * count
    end
end

--- Count the production of items which are stored but not allocated, so the total shows what more surface area would give
--- @param name string
--- @param count number
local function count_unallocated_production(name, count)
    local item = allowed_items[name]
    if item.production then
        vlayer_data.properties.total_production = vlayer_data.properties.total_production + item.production * count
    end
end

for name, item in pairs(allowed_items) do
    vlayer_data.storage.items[name] = item.starting_value
    if item.required_area > 0 then
        vlayer_data.storage.unallocated[name] = 0
    end
    if item.power then
        vlayer_data.storage.power_items[name] = { value = assert(item.fuel_value) * mega, count = 0 }
    end
    allocate_item(name, item.starting_value)
end

--- Store an item, it is allocated straight away when there is surface area for it
--- @param name string
--- @param count number
function Vlayer.insert_item(name, count)
    local item = assert(allowed_items[name], "Item not allowed in the vlayer: " .. name)
    local storage = vlayer_data.storage
    storage.items[name] = storage.items[name] + count

    if config.unlimited_surface_area or item.required_area == 0 then
        allocate_item(name, count)
        return
    end

    local properties = vlayer_data.properties
    local surplus_area = properties.total_surface_area - properties.used_surface_area
    local allocated = min(count, floor(surplus_area / item.required_area))
    if allocated > 0 then
        allocate_item(name, allocated)
    end

    local unallocated = count - allocated
    storage.unallocated[name] = storage.unallocated[name] + unallocated
    count_unallocated_production(name, unallocated)
end

--- Take an item out, unallocated items go first and landfill can only go while nothing is using its area
--- @param name string
--- @param count number
--- @return number # The count actually removed
function Vlayer.remove_item(name, count)
    local item = assert(allowed_items[name], "Item not allowed in the vlayer: " .. name)
    local storage = vlayer_data.storage
    local properties = vlayer_data.properties
    local removed = 0

    if not config.unlimited_surface_area and item.required_area > 0 then
        removed = min(count, storage.unallocated[name])
        storage.items[name] = storage.items[name] - removed
        storage.unallocated[name] = storage.unallocated[name] - removed
        count_unallocated_production(name, -removed)
        count = count - removed
        if count == 0 then
            return removed
        end
    end

    local deallocate = min(count, storage.items[name])
    if item.surface_area and item.surface_area > 0 then
        local surplus_area = properties.total_surface_area - properties.used_surface_area
        deallocate = min(deallocate, floor(surplus_area / item.surface_area))
        if deallocate <= 0 then
            return removed
        end
    end

    storage.items[name] = storage.items[name] - deallocate
    allocate_item(name, -deallocate)
    return removed + deallocate
end

--- Add or take energy, used by other modules which spend the stored energy
--- @param energy number J, negative to take
--- @return number # J stored afterwards
function Vlayer.energy_changed(energy)
    local storage = vlayer_data.storage
    storage.energy = storage.energy + energy
    return storage.energy
end

--- Get the statistics of the layer
--- @return ExpScenario_Vlayer.Statistics
function Vlayer.get_statistics()
    local properties = vlayer_data.properties
    local production = properties.production * mega
    local production_multiplier = get_production_multiplier()
    local sustained_multiplier = get_sustained_multiplier()
    local remaining_surface_area = get_remaining_surface_area()

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
        energy_storage = vlayer_data.storage.energy,
    }
end

--- Make an entity into an interface which players can not mine or damage
--- @param interface LuaEntity
--- @param interface_type ExpScenario_Vlayer.InterfaceType
--- @param player LuaPlayer?
local function register_interface(interface, interface_type, player)
    local interfaces = vlayer_data.interfaces[interface_type]
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
    register_interface(interface, "energy", player)
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
    register_interface(interface, "circuit", player)
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
    register_interface(interface, "storage_input", player)
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
    register_interface(interface, "storage_output", player)
    return interface
end

--- Remove an interface, anything it holds is dropped in a chest next to it and stored energy is kept
--- @param interface LuaEntity
--- @return ExpScenario_Vlayer.InterfaceType
function Vlayer.remove_interface(interface)
    local interface_type = assert(interface_types[interface.name], "Entity is not a vlayer interface: " .. interface.name)
    if interface_type == "storage_input" or interface_type == "storage_output" then
        ExpUtil.transfer_inventory_to_surface{
            inventory = assert(interface.get_inventory(defines.inventory.chest)),
            surface = interface.surface,
            name = "iron-chest",
            allow_creation = true,
        }
    elseif interface_type == "energy" then
        vlayer_data.storage.energy = vlayer_data.storage.energy + interface.energy
    end

    table.remove_element(vlayer_data.interfaces[interface_type], interface)
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
    local interfaces = vlayer_data.interfaces.storage_input
    prune_interfaces(interfaces)
    for _, interface in ipairs(interfaces) do
        local inventory = assert(interface.get_inventory(defines.inventory.chest))
        for _, item in pairs(inventory.get_contents()) do
            local name = item.name
            if allowed_items[name] then
                -- Quality is not tracked, so higher quality is stored as extra normal items in batches of ten
                local quality_level = prototypes.quality[item.quality].level
                local removed, stored = 0, 0
                if quality_level == 0 then
                    removed, stored = item.count, item.count
                elseif item.count >= 10 then
                    local batches = floor(item.count / 10)
                    removed, stored = batches * 10, batches * (10 + quality_level * 3)
                end

                if removed > 0 then
                    local modded = config.modded_items[name]
                    if modded and config.modded_auto_downgrade then
                        Vlayer.insert_item(modded.base_game_equivalent, stored * modded.multiplier)
                    elseif vlayer_data.storage.power_items[name] then
                        local power_item = vlayer_data.storage.power_items[name]
                        power_item.count = power_item.count + stored
                    else
                        Vlayer.insert_item(name, stored)
                    end
                    inventory.remove{ name = name, count = removed, quality = item.quality }
                end
            end
        end
    end
end

--- Fill the requests of the output interfaces from storage
local function handle_output_interfaces()
    local interfaces = vlayer_data.interfaces.storage_output
    prune_interfaces(interfaces)
    for _, interface in ipairs(interfaces) do
        local inventory = assert(interface.get_inventory(defines.inventory.chest))
        for _, section in ipairs(assert(interface.get_logistic_sections()).sections) do
            for _, filter in pairs(section.filters) do
                local name = filter.value and filter.value.name
                if name and allowed_items[name] then
                    local wanted = min(assert(filter.min) - inventory.get_item_count(name), vlayer_data.storage.items[name])
                    if wanted > 0 and inventory.can_insert{ name = name, count = wanted } then
                        local removed = Vlayer.remove_item(name, wanted)
                        if removed > 0 then
                            inventory.insert{ name = name, count = removed, quality = "normal" }
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

    local unallocated_area = 0
    for name, count in pairs(vlayer_data.storage.unallocated) do
        unallocated_area = unallocated_area + allowed_items[name].required_area * count
    end
    if unallocated_area == 0 then return end

    local properties = vlayer_data.properties
    local surplus_area = properties.total_surface_area - properties.used_surface_area
    for name, count in pairs(vlayer_data.storage.unallocated) do
        local allocated = min(count, floor(count * surplus_area / unallocated_area))
        if allocated > 0 then
            vlayer_data.storage.unallocated[name] = count - allocated
            allocate_item(name, allocated)
            count_unallocated_production(name, -allocated)
        end
    end
end

--- Set the signals of the circuit interfaces to the statistics and stored items
local function handle_circuit_interfaces()
    local interfaces = vlayer_data.interfaces.circuit
    prune_interfaces(interfaces)
    if #interfaces == 0 then return end

    local stats = Vlayer.get_statistics()
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

        for name, count in pairs(vlayer_data.storage.items) do
            if count > 0 and prototypes.item[name] then
                section.set_slot(index, { value = { type = "item", name = name, quality = "normal" }, min = count })
                index = index + 1
            end
        end
    end
end

--- Produce energy, share it between the energy interfaces, and burn fuel when storage runs low
local function handle_energy_interfaces()
    local storage = vlayer_data.storage
    local properties = vlayer_data.properties
    local production = properties.production * mega * (config.update_tick_energy / 60)
    storage.energy = storage.energy + floor(production * get_production_multiplier())

    local interfaces = vlayer_data.interfaces.energy
    prune_interfaces(interfaces)
    if #interfaces > 0 then
        local available_energy = storage.energy
        for _, interface in ipairs(interfaces) do
            available_energy = available_energy + interface.energy
        end

        local discharge_rate = 2 * (production + properties.discharge * mega) / #interfaces
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
        return
    end

    for _, power_item in pairs(storage.power_items) do
        local max_burn = capacity / 2 - storage.energy
        if power_item.count > 0 and max_burn > 0 then
            local burn = min(power_item.count, floor(max_burn / power_item.value))
            storage.energy = storage.energy + burn * power_item.value
            power_item.count = power_item.count - burn
        end
    end
end

--- Take the day cycle from the mimic surface when it exists, otherwise from the config
local function update_surface()
    if config.mimic_surface then
        local surface = game.get_surface(config.mimic_surface)
        if surface then
            vlayer_data.surface = surface
            return
        end
    end

    -- The config copy never has an index, so this avoids replacing it every time a surface changes
    if not vlayer_data.surface.index then
        vlayer_data.surface = table.deep_copy(config.surface)
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
Vlayer.events[e.on_surface_created] = update_surface
Vlayer.events[e.on_surface_renamed] = update_surface
Vlayer.events[e.on_surface_imported] = update_surface
Vlayer.on_nth_tick[config.update_tick_storage] = update_storage
Vlayer.on_nth_tick[config.update_tick_energy] = update_energy

return Vlayer
