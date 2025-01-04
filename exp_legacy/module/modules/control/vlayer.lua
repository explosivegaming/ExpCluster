--[[-- Control Module - vlayer
    - Adds a virtual layer to store power to save space.
    @control vlayer
    @alias vlayer
]]

local ExpUtil = require("modules/exp_util")
local Storage = require("modules/exp_util/storage")
local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event
local config = require("modules.exp_legacy.config.vlayer") --- @dep config.vlayer

local mega = 1000000

local vlayer = {}
local vlayer_data = {
    entity_interfaces = {
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
        power_items = {},
        energy = 0,
        unallocated = {},
    },
    surface = table.deep_copy(config.surface),
}

Storage.register(vlayer_data, function(tbl)
    vlayer_data = tbl
end)

for name, properties in pairs(config.allowed_items) do
    properties.modded = false

    if properties.power then
        vlayer_data.storage.power_items[name] = {
            value = properties.fuel_value * 1000000,
            count = 0,
        }
    end
end

-- For all modded items, create a config for them
for item_name, properties in pairs(config.modded_items) do
    local base_properties = config.allowed_items[properties.base_game_equivalent]
    local m = properties.multiplier

    config.allowed_items[item_name] = {
        starting_value = properties.starting_value or 0,
        required_area = base_properties.required_area or 0,
        surface_area = (base_properties.surface_area or 0) * m,
        production = (base_properties.production or 0) * m,
        capacity = (base_properties.capacity or 0) * m,
        modded = true,
    }
end

--- Get all items in storage, do not modify
-- @treturn table a dictionary of all items stored in the vlayer
function vlayer.get_items()
    return vlayer_data.storage.items
end

--- Get all unallocated items in storage
-- @treturn table a dictionary of all unallocated items stored in the vlayer
function vlayer.get_unallocated_items()
    return vlayer_data.storage.unallocated
end

--- Get all allocated items in storage
-- @treturn table a dictionary of all allocated items stored in the vlayer
function vlayer.get_allocated_items()
    local r = {}

    for k, v in pairs(vlayer_data.storage.items) do
        r[k] = v

        if vlayer_data.storage.unallocated[k] then
            r[k] = r[k] - vlayer_data.storage.unallocated[k]
        end
    end

    return r
end

--- Get the actual defecit of land
local function get_actual_land_defecit()
    local n = vlayer_data.properties.total_surface_area - vlayer_data.properties.used_surface_area

    for k, v in pairs(vlayer.get_unallocated_items()) do
        n = n - (config.allowed_items[k].required_area * v)
    end

    return n
end

--- Get interface counts
-- @treturn table a dictionary of the vlayer interface counts
function vlayer.get_interface_counts()
    local interfaces = vlayer_data.entity_interfaces

    return {
        energy = #interfaces.energy,
        circuit = #interfaces.circuit,
        storage_input = #interfaces.storage_input,
        storage_output = #interfaces.storage_output,
    }
end

--- Get interfaces
-- @treturn table a dictionary of the vlayer interfaces
function vlayer.get_interfaces()
    local interfaces = vlayer_data.entity_interfaces

    return {
        energy = interfaces.energy,
        circuit = interfaces.circuit,
        storage_input = interfaces.storage_input,
        storage_output = interfaces.storage_output,
    }
end

--[[
    25,000 / 416 s
    昼      208秒   ソーラー効率100%
    夕方    83秒    1秒ごとにソーラー発電量が約1.2%ずつ下がり、やがて0%になる
    夜      41秒    ソーラー発電量が0%になる
    朝方    83秒    1秒ごとにソーラー発電量が約1.2%ずつ上がり、やがて100%になる

    (surface.dawn)      0.75    18,750   Day         12,500  208s
                        0.00    0       Noon
    (surface.dusk)      0.25    6,250    Sunset      5,000   83s
    (surface.evening)   0.45    11,250   Night       2,500   41s
    (surface.morning)   0.55    13,750   Sunrise     5,000   83s
]]

--- Get the power multiplier based on the surface time
local function get_production_multiplier()
    local mul = vlayer_data.surface.solar_power_multiplier
    local surface = vlayer_data.surface

    if surface.always_day then
        -- Surface is always day, so full production is used
        return mul
    end

    if surface.darkness then
        -- We are using a real surface, our config does not contain "darkness"
        local brightness = 1 - surface.darkness

        if brightness >= surface.min_brightness then
            return mul * (brightness - surface.min_brightness) / (1 - surface.min_brightness)
        else
            return 0
        end
    end

    -- Caused by using a set config rather than a surface
    local tick = game.tick % surface.ticks_per_day
    local daytime = tick / surface.ticks_per_day
    surface.daytime = daytime

    if daytime <= surface.dusk then -- Noon to Sunset
        return mul
    elseif daytime <= surface.evening then -- Sunset to Night
        return mul * (1 - ((daytime - surface.dusk) / (surface.evening - surface.dusk)))
    elseif daytime <= surface.morning then -- Night to Sunrise
        return 0
    elseif daytime <= surface.dawn then -- Sunrise to Morning
        return mul * ((surface.daytime - surface.morning) / (surface.dawn - surface.morning))
    else -- Morning to Noon
        return mul
    end
end

--- Get the sustained power multiplier, this needs improving
local function get_sustained_multiplier()
    local mul = vlayer_data.surface.solar_power_multiplier
    local surface = vlayer_data.surface

    if surface.always_day then
        -- Surface is always day, so full production is used
        return mul
    end

    -- For nauvis vanilla: 208s + (1/2 x (83s + 83s))
    local day_duration = 1 - surface.dawn + surface.dusk
    local sunset_duration = surface.evening - surface.dusk
    local sunrise_duration = surface.dawn - surface.morning

    return mul * (day_duration + (0.5 * (sunset_duration + sunrise_duration)))
end

--- Internal, Allocate items in the vlayer, this will increase the property values of the vlayer such as production and capacity
-- Does not increment item storage, so should not be called before insert_item unless during init
-- Does not validate area requirements, so checks must be performed before calling this function
-- Accepts negative count for deallocating items
-- @tparam string item_name The name of the item to allocate
-- @tparam number count The count of the item to allocate
function vlayer.allocate_item(item_name, count)
    local item_properties = config.allowed_items[item_name]
    assert(item_properties, "Item not allowed in vlayer: " .. tostring(item_name))

    if item_properties.production then
        local nc = item_properties.production * count
        vlayer_data.properties.production = vlayer_data.properties.production + nc
        vlayer_data.properties.total_production = vlayer_data.properties.total_production + nc
    end

    if item_properties.capacity then
        vlayer_data.properties.capacity = vlayer_data.properties.capacity + item_properties.capacity * count
    end

    if item_properties.discharge then
        vlayer_data.properties.discharge = vlayer_data.properties.discharge + item_properties.discharge * count
    end

    if item_properties.surface_area then
        vlayer_data.properties.total_surface_area = vlayer_data.properties.total_surface_area + item_properties.surface_area * count
    end

    if item_properties.required_area and item_properties.required_area > 0 then
        vlayer_data.properties.used_surface_area = vlayer_data.properties.used_surface_area + item_properties.required_area * count
    end
end

function vlayer.unable_alloc_item_pwr_calc(item_name, count)
    local item_properties = config.allowed_items[item_name]

    if item_properties.production then
        vlayer_data.properties.total_production = vlayer_data.properties.total_production + item_properties.production * count
    end
end

-- For all allowed items, setup their starting values, default 0
for item_name, properties in pairs(config.allowed_items) do
    vlayer_data.storage.items[item_name] = properties.starting_value or 0

    if properties.required_area and properties.required_area > 0 then
        vlayer_data.storage.unallocated[item_name] = 0
    end

    vlayer.allocate_item(item_name, properties.starting_value)
end

--- Insert an item into the vlayer, this will increment its count in storage and allocate it if possible
-- @tparam string item_name The name of the item to insert
-- @tparam number count The count of the item to insert
function vlayer.insert_item(item_name, count)
    local item_properties = config.allowed_items[item_name]
    assert(item_properties, "Item not allowed in vlayer: " .. tostring(item_name))
    vlayer_data.storage.items[item_name] = vlayer_data.storage.items[item_name] + count

    if not config.unlimited_surface_area and item_properties.required_area and item_properties.required_area > 0 then
        -- Calculate how many can be allocated
        local surplus_area = vlayer_data.properties.total_surface_area - vlayer_data.properties.used_surface_area
        local allocate_count = math.min(count, math.floor(surplus_area / item_properties.required_area))

        if allocate_count > 0 then
            vlayer.allocate_item(item_name, allocate_count)
        end

        local unallocated = count - allocate_count
        vlayer_data.storage.unallocated[item_name] = vlayer_data.storage.unallocated[item_name] + unallocated
        vlayer.unable_alloc_item_pwr_calc(item_name, unallocated)
    else
        vlayer.allocate_item(item_name, count)
    end
end

--- Remove an item from the vlayer, this will decrement its count in storage and prioritise unallocated items over deallocation
-- Can not always fulfil the remove request for items which provide surface area, therefore returns the amount actually removed
-- @tparam string item_name The name of the item to remove
-- @tparam number count The count of the item to remove
-- @treturn number The count of the item actually removed
function vlayer.remove_item(item_name, count)
    local item_properties = config.allowed_items[item_name]
    assert(item_properties, "Item not allowed in vlayer: " .. tostring(item_name))
    local remove_unallocated = 0

    if not config.unlimited_surface_area and item_properties.required_area and item_properties.required_area > 0 then
        -- Remove from the unallocated storage first
        remove_unallocated = math.min(count, vlayer_data.storage.unallocated[item_name])

        if remove_unallocated > 0 then
            vlayer_data.storage.items[item_name] = vlayer_data.storage.items[item_name] - count
            vlayer_data.storage.unallocated[item_name] = vlayer_data.storage.unallocated[item_name] - count
        end

        -- Check if any more items need to be removed
        count = count - remove_unallocated

        if count == 0 then
            return remove_unallocated
        end
    end

    -- Calculate the amount to remove based on items in storage
    local remove_count = math.min(count, vlayer_data.storage.items[item_name])

    if item_properties.surface_area and item_properties.surface_area > 0 then
        -- If the item provides surface area then it has additional limitations
        local surplus_area = vlayer_data.properties.total_surface_area - vlayer_data.properties.used_surface_area
        remove_count = math.min(remove_count, math.floor(surplus_area / item_properties.surface_area))

        if remove_count <= 0 then
            return remove_unallocated
        end
    end

    -- Remove the item from allocated storage
    vlayer_data.storage.items[item_name] = vlayer_data.storage.items[item_name] - remove_count
    vlayer.allocate_item(item_name, -remove_count)

    return remove_unallocated + remove_count
end

--- Create a new storage input interface
-- @tparam LuaSurface surface The surface to place the interface onto
-- @tparam MapPosition position The position on the surface to place the interface at
-- @tparam[opt] LuaPlayer player The player to show as the last user of the interface
-- @treturn LuaEntity The entity that was created for the interface
function vlayer.create_input_interface(surface, position, circuit, last_user)
    local interface = surface.create_entity{ name = "storage-chest", position = position, force = "neutral" }
    table.insert(vlayer_data.entity_interfaces.storage_input, interface)

    if last_user then
        interface.last_user = last_user
    end

    if circuit then
        for k, _ in pairs(circuit) do
            for _, v in pairs(circuit[k]) do
                interface.connect_neighbour{ wire = defines.wire_type[k], target_entity = v }
            end
        end
    end

    interface.destructible = false
    interface.minable = false
    interface.operable = true

    return interface
end

--- Handle all input interfaces, will take their contents and insert it into the vlayer storage
local function handle_input_interfaces()
    for index, interface in pairs(vlayer_data.entity_interfaces.storage_input) do
        if not interface.valid then
            vlayer_data.entity_interfaces.storage_input[index] = nil
        else
            local inventory = interface.get_inventory(defines.inventory.chest)

            for name, count in pairs(inventory.get_contents()) do
                if config.allowed_items[name] then
                    if config.allowed_items[name].modded then
                        if config.modded_auto_downgrade then
                            vlayer.insert_item(config.modded_items[name].base_game_equivalent, count * config.modded_items[name].multiplier)
                        else
                            vlayer.insert_item(name, count)
                        end
                    else
                        if vlayer_data.storage.power_items[name] then
                            vlayer_data.storage.power_items[name].count = vlayer_data.storage.power_items[name].count + count
                        else
                            vlayer.insert_item(name, count)
                        end
                    end

                    inventory.remove{ name = name, count = count }
                end
            end
        end
    end
end

--- Create a new storage output interface
-- @tparam LuaSurface surface The surface to place the interface onto
-- @tparam MapPosition position The position on the surface to place the interface at
-- @tparam[opt] LuaPlayer player The player to show as the last user of the interface
-- @treturn LuaEntity The entity that was created for the interface
function vlayer.create_output_interface(surface, position, circuit, last_user)
    local interface = surface.create_entity{ name = "requester-chest", position = position, force = "neutral" }
    table.insert(vlayer_data.entity_interfaces.storage_output, interface)

    if last_user then
        interface.last_user = last_user
    end

    if circuit then
        for k, _ in pairs(circuit) do
            for _, v in pairs(circuit[k]) do
                interface.connect_neighbour{ wire = defines.wire_type[k], target_entity = v }
            end
        end
    end

    interface.destructible = false
    interface.minable = false
    interface.operable = true

    return interface
end

--- Handle all output interfaces, will take their requests and remove it from the vlayer storage
local function handle_output_interfaces()
    for index, interface in pairs(vlayer_data.entity_interfaces.storage_output) do
        if not interface.valid then
            vlayer_data.entity_interfaces.storage_output[index] = nil
        else
            local inventory = interface.get_inventory(defines.inventory.chest)

            for i = 1, interface.request_slot_count do
                local request = interface.get_request_slot(i)

                if request and config.allowed_items[request.name] then
                    local current_amount = inventory.get_item_count(request.name)
                    local request_amount = math.min(request.count - current_amount, vlayer_data.storage.items[request.name])

                    if request_amount > 0 and inventory.can_insert{ name = request.name, count = request_amount } then
                        local removed_item_count = vlayer.remove_item(request.name, request_amount)

                        if removed_item_count > 0 then
                            inventory.insert{ name = request.name, count = removed_item_count }
                        end
                    end
                end
            end
        end
    end
end

--- Handle the unallocated items because more surface area may have been added
local function handle_unallocated()
    -- unallocated cant happen when its unlimited
    if config.unlimited_surface_area then
        return
    end

    -- Get the total unallocated area so items can be allocated in equal amounts
    local unallocated_area = 0

    for item_name, count in pairs(vlayer_data.storage.unallocated) do
        local item_properties = config.allowed_items[item_name]
        unallocated_area = unallocated_area + item_properties.required_area * count
    end

    if unallocated_area == 0 then
        return
    end

    -- Allocate items in an equal distribution
    local surplus_area = vlayer_data.properties.total_surface_area - vlayer_data.properties.used_surface_area

    for item_name, count in pairs(vlayer_data.storage.unallocated) do
        local allocation_count = math.min(count, math.floor(count * surplus_area / unallocated_area))

        if allocation_count > 0 then
            vlayer_data.storage.unallocated[item_name] = vlayer_data.storage.unallocated[item_name] - allocation_count
            vlayer.allocate_item(item_name, allocation_count)
            vlayer.unable_alloc_item_pwr_calc(item_name, -allocation_count)
        end
    end
end

--- Get the statistics for the vlayer
function vlayer.get_statistics()
    local vdp = vlayer_data.properties.production * mega
    local gdm = get_production_multiplier()
    local gsm = get_sustained_multiplier()
    local gald = get_actual_land_defecit()

    return {
        total_surface_area = vlayer_data.properties.total_surface_area,
        used_surface_area = vlayer_data.properties.used_surface_area,
        remaining_surface_area = gald,
        surface_area = vlayer_data.properties.total_surface_area - gald,
        production_multiplier = gdm,
        energy_max = vdp,
        energy_production = vdp * gdm,
        energy_total_production = vlayer_data.properties.total_production * gsm * mega,
        energy_sustained = vdp * gsm,
        energy_capacity = vlayer_data.properties.capacity * mega,
        energy_storage = vlayer_data.storage.energy,
        day_time = math.floor(vlayer_data.surface.daytime * vlayer_data.surface.ticks_per_day),
        day_length = vlayer_data.surface.ticks_per_day,
        tick = game.tick,
    }
end

--- add or reduce vlayer power
function vlayer.energy_changed(power)
    vlayer_data.storage.energy = vlayer_data.storage.energy + power
end

--- Circuit signals used for the statistics
function vlayer.get_circuits()
    return {
        total_surface_area = "signal-A",
        used_surface_area = "signal-U",
        remaining_surface_area = "signal-R",
        production_multiplier = "signal-M",
        energy_production = "signal-P",
        energy_sustained = "signal-S",
        energy_capacity = "signal-C",
        energy_storage = "signal-E",
        day_time = "signal-D",
        day_length = "signal-L",
        tick = "signal-T",
    }
end

--- Create a new circuit interface
-- @tparam LuaSurface surface The surface to place the interface onto
-- @tparam MapPosition position The position on the surface to place the interface at
-- @tparam[opt] LuaPlayer player The player to show as the last user of the interface
-- @treturn LuaEntity The entity that was created for the interface
function vlayer.create_circuit_interface(surface, position, circuit, last_user)
    local interface = surface.create_entity{ name = "constant-combinator", position = position, force = "neutral" }
    table.insert(vlayer_data.entity_interfaces.circuit, interface)

    if last_user then
        interface.last_user = last_user
    end

    if circuit then
        for k, _ in pairs(circuit) do
            for _, v in pairs(circuit[k]) do
                interface.connect_neighbour{ wire = defines.wire_type[k], target_entity = v }
            end
        end
    end

    interface.destructible = false
    interface.minable = false
    interface.operable = true

    return interface
end

--- Handle all circuit interfaces, updating their signals to match the vlayer statistics
local function handle_circuit_interfaces()
    local stats = vlayer.get_statistics()

    for index, interface in pairs(vlayer_data.entity_interfaces.circuit) do
        if not interface.valid then
            vlayer_data.entity_interfaces.circuit[index] = nil
        else
            local circuit_oc = interface.get_or_create_control_behavior()
            local max_signals = circuit_oc.signals_count
            local signal_index = 1
            local circuit = vlayer.get_circuits()

            -- Set the virtual signals based on the vlayer stats
            for stat_name, signal_name in pairs(circuit) do
                if stat_name:find("energy") then
                    circuit_oc.set_signal(signal_index, { signal = { type = "virtual", name = signal_name }, count = math.floor(stats[stat_name] / mega) })
                elseif stat_name == "production_multiplier" then
                    circuit_oc.set_signal(signal_index, { signal = { type = "virtual", name = signal_name }, count = math.floor(stats[stat_name] * 10000) })
                else
                    circuit_oc.set_signal(signal_index, { signal = { type = "virtual", name = signal_name }, count = math.floor(stats[stat_name]) })
                end

                signal_index = signal_index + 1
            end

            -- Set the item signals based on stored items
            for item_name, count in pairs(vlayer_data.storage.items) do
                if prototypes.item[item_name] and count > 0 then
                    circuit_oc.set_signal(signal_index, { signal = { type = "item", name = item_name }, count = count })
                    signal_index = signal_index + 1
                    if signal_index > max_signals then
                        return -- No more signals can be added
                    end
                end
            end

            -- Clear remaining signals to prevent outdated values being present (caused by count > 0 check)
            for clear_index = signal_index, max_signals do
                if not circuit_oc.get_signal(clear_index).signal then
                    break -- There are no more signals to clear
                end

                circuit_oc.set_signal(clear_index, nil)
            end
        end
    end
end

--- Create a new energy interface
-- @tparam LuaSurface surface The surface to place the interface onto
-- @tparam MapPosition position The position on the surface to place the interface at
-- @tparam[opt] LuaPlayer player The player to show as the last user of the interface
-- @treturn LuaEntity The entity that was created for the interface, or nil if it could not be created
function vlayer.create_energy_interface(surface, position, last_user)
    if not surface.can_place_entity{ name = "electric-energy-interface", position = position } then
        return nil
    end

    local interface = surface.create_entity{ name = "electric-energy-interface", position = position, force = "neutral" }
    table.insert(vlayer_data.entity_interfaces.energy, interface)

    if last_user then
        interface.last_user = last_user
    end

    interface.destructible = false
    interface.minable = false
    interface.operable = false
    interface.electric_buffer_size = 0
    interface.power_production = 0
    interface.power_usage = 0
    interface.energy = 0

    return interface
end

--- Handle all energy interfaces as well as the energy storage
local function handle_energy_interfaces()
    -- Add the newly produced power
    local production = vlayer_data.properties.production * mega * (config.update_tick_energy / 60)
    vlayer_data.storage.energy = vlayer_data.storage.energy + math.floor(production * get_production_multiplier())

    -- Calculate how much power is present in the network, that is storage + all interfaces
    if #vlayer_data.entity_interfaces.energy > 0 then
        local available_energy = vlayer_data.storage.energy

        for index, interface in pairs(vlayer_data.entity_interfaces.energy) do
            if not interface.valid then
                vlayer_data.entity_interfaces.energy[index] = nil
            else
                available_energy = available_energy + interface.energy
            end
        end

        -- Distribute the energy between all interfaces
        local discharge_rate = 2 * (production + vlayer_data.properties.discharge * mega) / #vlayer_data.entity_interfaces.energy
        local fill_to = math.min(discharge_rate, math.floor(available_energy / #vlayer_data.entity_interfaces.energy))

        for _, interface in pairs(vlayer_data.entity_interfaces.energy) do
            interface.electric_buffer_size = math.max(discharge_rate, interface.energy) -- prevent energy loss
            local delta = fill_to - interface.energy -- positive means storage to interface
            vlayer_data.storage.energy = vlayer_data.storage.energy - delta
            interface.energy = interface.energy + delta
        end
    end

    -- Cap the stored energy to the allowed capacity
    if not config.unlimited_capacity and vlayer_data.storage.energy > vlayer_data.properties.capacity * mega then
        vlayer_data.storage.energy = vlayer_data.properties.capacity * mega

        -- burn the trash to produce power
    elseif vlayer_data.storage.power_items then
        for k, v in pairs(vlayer_data.storage.power_items) do
            local max_burning = (vlayer_data.properties.capacity * mega / 2) - vlayer_data.storage.energy

            if v.count > 0 and max_burning > 0 then
                local to_burn = math.min(v.count, math.floor(max_burning / v.value))

                vlayer_data.storage.energy = vlayer_data.storage.energy + (to_burn * v.value)
                vlayer_data.storage.power_items[k].count = vlayer_data.storage.power_items[k].count - to_burn
            end
        end
    end
end

--- Remove the entity interface using the given position
-- @tparam LuaSurface surface The surface to search for an interface on
-- @tparam MapPosition position The position of the item
-- @treturn string The type of interface that was removed, or nil if no interface was found
-- @treturn MapPosition The position the interface was at, or nil if no interface was found
function vlayer.remove_interface(surface, position)
    local entities = surface.find_entities_filtered{
        name = { "storage-chest", "requester-chest", "constant-combinator", "electric-energy-interface" },
        force = "neutral",
        position = position,
        radius = 2,
        limit = 1,
    }

    -- Get the details which will be returned
    if #entities == 0 then
        return nil, nil
    end

    local interface = entities[1]
    local name = interface.name
    local pos = interface.position

    -- Return the type of interface removed and do some clean up
    if name == "storage-chest" then
        local inventory = assert(interface.get_inventory(defines.inventory.chest))
        ExpUtil.transfer_inventory_to_surface{
            inventory = inventory,
            surface = interface.surface,
            name = "iron-chest",
            allow_creation = true,
        }
        table.remove_element(vlayer_data.entity_interfaces.storage_input, interface)
        interface.destroy()

        return "storage-input", pos
    elseif name == "requester-chest" then
        local inventory = assert(interface.get_inventory(defines.inventory.chest))
        ExpUtil.transfer_inventory_to_surface{
            inventory = inventory,
            surface = interface.surface,
            name = "iron-chest",
            allow_creation = true,
        }
        table.remove_element(vlayer_data.entity_interfaces.storage_output, interface)
        interface.destroy()

        return "storage-output", pos
    elseif name == "constant-combinator" then
        table.remove_element(vlayer_data.entity_interfaces.circuit, interface)
        interface.destroy()

        return "circuit", pos
    elseif name == "electric-energy-interface" then
        vlayer_data.storage.energy = vlayer_data.storage.energy + interface.energy
        table.remove_element(vlayer_data.entity_interfaces.energy, interface)
        interface.destroy()

        return "energy", pos
    end
end

local function on_surface_event()
    if config.mimic_surface then
        local surface = game.get_surface(config.mimic_surface)

        if surface then
            vlayer_data.surface = surface
            return
        end
    end

    if not vlayer_data.surface.index then
        -- Our fake surface data never has an index, we test for this to avoid unneeded copies from the config
        vlayer_data.surface = table.deep_copy(config.surface)
    end
end

--- Handle all storage IO and attempt allocation of unallocated items
Event.on_nth_tick(config.update_tick_storage, function(_)
    handle_input_interfaces()
    handle_output_interfaces()
    handle_unallocated()
end)

--- Handle all energy and circuit updates
Event.on_nth_tick(config.update_tick_energy, function(_)
    handle_circuit_interfaces()
    handle_energy_interfaces()
end)

Event.add(defines.events.on_surface_created, on_surface_event)
Event.add(defines.events.on_surface_renamed, on_surface_event)
Event.add(defines.events.on_surface_imported, on_surface_event)
Event.on_init(on_surface_event) -- Default surface always exists, does not trigger on_surface_created

return vlayer
