--[[-- ExpUtil
Adds some commonly used functions used in many modules
]]

-- Make sure these are loaded first so locals below work
require("modules/exp_util/include/math")
require("modules/exp_util/include/table")

local type = type
local assert = assert
local getmetatable = getmetatable
local getinfo = debug.getinfo
local traceback = debug.traceback
local floor = math.floor
local round = math.round
local concat = table.concat
local inspect = table.inspect
local format_string = string.format
local table_to_json = helpers.table_to_json
local write_file = helpers.write_file

--- @class ExpUtil
local ExpUtil = {
    --- A large mapping of colour rgb values by their common name
    color = require("modules/exp_util/include/color"),
}

--- Raise an error if we are not in runtime
function ExpUtil.assert_not_runtime()
    assert(package.lifecycle ~= package.lifecycle_stage.runtime, "Can not be called during runtime")
end

--- Check the type of a value, also considers LuaObject.object_name and metatable.__class
--- Returns true when the check failed and an error should be raised
--- @param value any The value to check the type of
--- @param type_name string The type name the value should be
--- @return boolean failed True if the check failed and an error should be raised
--- @return string actual_type The actual type of the value 
local function check_type(value, type_name)
    local value_type = type(value) --[[@as string]]
    if value_type == "userdata" then
        if type_name == "userdata" then
            return false, value_type
        end
        value_type = value.object_name
    elseif value_type == "table" then
        if type_name == "table" then
            return false, value_type
        end
        local mt = getmetatable(value)
        if mt and mt.__class then
            value_type = mt.__class
        end
    end
    return value == nil or value_type ~= type_name, value_type
end

--- Get the name of a class or object, better than just using type
--- @param value any The value to get the class of
--- @return string # One of type, object_name, __class
function ExpUtil.get_class_name(value)
    local value_type = type(value) --[[@as string]]
    if value_type == "userdata" then
        return value.object_name
    elseif value_type == "table" then
        local mt = getmetatable(value)
        if mt and mt.__class then
            return mt.__class
        end
    end
    return value_type
end

local assert_type_fmt = "%s expected to be of type %s but got %s"
--- Raise an error if the type of a value is not as expected
--- @param value any The value to assert the type of
--- @param type_name string The name of the type that value is expected to be
--- @param value_name string? The name of the value being tested, this is included in the error message
function ExpUtil.assert_type(value, type_name, value_name)
    local failed, actual_type = check_type(value, type_name)
    if failed then
        error(assert_type_fmt:format(value_name or "Value", type_name, actual_type), 2)
    end
end

local assert_argument_fmt = "Bad argument #%d to %s; %s expected to be of type %s but got %s"
--- Raise an error if the type of any argument is not as expected, more performant than assert_argument_types, but requires more manual input
--- @param arg_value any The argument to assert the type of
--- @param type_name string The name of the type that value is expected to be
--- @param arg_index number The index of the argument being tested, this is included in the error message
--- @param arg_name string? The name of the argument being tested, this is included in the error message
function ExpUtil.assert_argument_type(arg_value, type_name, arg_index, arg_name)
    local failed, actual_type = check_type(arg_value, type_name)
    if failed then
        local func_name = getinfo(2, "n").name or "<anonymous>"
        error(assert_argument_fmt:format(arg_index, func_name, arg_name or "Argument", type_name, actual_type), 2)
    end
end

--- Write a luu table to a file as a json string, note the defaults are different to write_file
--- @param path string The path to write the json to
--- @param tbl table The table to write to file
--- @param overwrite boolean? When true the json replaces the full contents of the file
--- @param player_index number? The player's machine to write on, -1 means all, 0 is default means host only
--- @return nil
function ExpUtil.write_json(path, tbl, overwrite, player_index)
    if player_index == -1 then
        return write_file(path, table_to_json(tbl) .. "\n", not overwrite)
    end
    return write_file(path, table_to_json(tbl) .. "\n", not overwrite, player_index or 0)
end

--- Clear a file by replacing its contents with an empty string
--- @param path string The path to clear the contents of
--- @param player_index number? The player's machine to write on, -1 means all, 0 is default and means host only
--- @return nil
function ExpUtil.clear_file(path, player_index)
    if player_index == -1 then
        return write_file(path, "", false)
    end
    return write_file(path, "", false, player_index or 0)
end

--- Same as require but will return nil if the module does not exist, all other errors will propagate to the caller
--- @param module_path string The path to the module to require, same syntax as normal require
--- @return any # The contents of the module, or nil if the module does not exist or did not return a value
function ExpUtil.optional_require(module_path)
    local success, rtn = xpcall(require, traceback, module_path)
    if success then return rtn end
    if not rtn:find("no such file", 0, true) then
        error(rtn, 2)
    end
end

--- Returns a desync sale filepath for a given stack frame, default is the current file
--- @param level number? The level of the stack to get the file of, a value of 1 is the caller of this function
--- @return string # The relative filepath of the given stack frame
function ExpUtil.safe_file_path(level)
    local debug_info = getinfo((level or 1) + 1, "Sn")
    local safe_source = debug_info.source:find("@__level__")
    return safe_source == 1 and debug_info.short_src:sub(10, -5) or debug_info.source
end

--- Returns the name of your module, this assumes your module is stored within /modules (which it is for clustorio)
--- @param level number? The level of the stack to get the module of, a value of 1 is the caller of this function
--- @return string # The name of the module at the given stack frame
function ExpUtil.get_module_name(level)
    local file_within_module = getinfo((level or 1) + 1, "S").short_src:sub(18, -5)
    local next_slash = file_within_module:find("/")
    if next_slash then
        return file_within_module:sub(1, next_slash - 1)
    else
        return file_within_module
    end
end

--- Returns the name of a function in a safe and consistent format
--- @param func number | function The level of the stack to get the name of, a value of 1 is the caller of this function
--- @param raw boolean? When true there will not be any < > around the name
--- @return string # The name of the function at the given stack frame or provided as an argument
function ExpUtil.get_function_name(func, raw)
    local debug_info = getinfo(func, "Sn")
    local safe_source = debug_info.source:find("@__level__")
    local file_name = safe_source == 1 and debug_info.source:sub(12, -5) or debug_info.source
    local func_name = debug_info.name or debug_info.linedefined
    if raw then return file_name .. ":" .. func_name end
    return "<" .. file_name .. ":" .. func_name .. ">"
end

--- Attempt a simple autocomplete search from a set of options
--- @param options table The table representing the possible options which can be selected
--- @param input string The user input string which should be matched to an option
--- @param use_key boolean? When true the keys will be searched, when false the values will be searched
--- @param rtn_key boolean? When true the selected key will be returned, when false the selected value will be returned
--- @return any # The selected key or value which first matches the input text
function ExpUtil.auto_complete(options, input, use_key, rtn_key)
    input = input:lower()
    if use_key then
        for k, v in pairs(options) do
            if k:lower():find(input) then
                if rtn_key then return k else return v end
            end
        end
    else
        for k, v in pairs(options) do
            if v:lower():find(input) then
                if rtn_key then return k else return v end
            end
        end
    end
end

--- Formats any value into a safe representation, useful with inspect
--- @param value any The value to be formatted
--- @return LocalisedString # The formatted version of the value
--- @return boolean # True if value is a locale string, nil otherwise
function ExpUtil.safe_value(value)
    local _type = type(value)
    if _type == "table" then
        local v1 = value[1]
        local str = tostring(value)
        if type(v1) == "string" and not v1:find("%s")
        and (v1 == "" or v1 == "?" or v1:find(".+[.].+"))
        and #value <= 20 then
            return value, true -- locale string
        elseif str ~= "table" then
            return str, false -- has __tostring metamethod
        else -- plain table
            return value, false
        end
    elseif _type == "function" then -- function
        return "<function:" .. ExpUtil.get_function_name(value, true) .. ">", false
    elseif _type == "thread" or _type == "userdata" then -- unsafe value
        return tostring(value), false
    else -- already safe value
        return value, false
    end
end

--- @class Common.format_any_param
--- @field as_json boolean? If table values should be returned as json
--- @field max_line_count number? If table newline count exceeds provided then it will be inlined, if 0 then always inline
--- @field no_locale_strings boolean? If value is a locale string it will be treated like a normal table
--- @field depth number? The max depth to process tables to, the default is 5

--- Formats any value to be presented in a safe and human readable format
--- @param value any The value to be formatted
--- @param options Common.format_any_param? Options for the formatter
--- @return LocalisedString # The formatted version of the value
function ExpUtil.format_any(value, options)
    options = options or {}
    local formatted, is_locale_string = ExpUtil.safe_value(value)
    if type(formatted) == "table" and (not is_locale_string or options.no_locale_strings) then
        if options.as_json then
            local success, rtn = pcall(table_to_json, value)
            if success then return rtn end
        end
        if options.max_line_count ~= 0 then
            local rtn = inspect(value, { depth = options.depth or 5, indent = " ", newline = "\n", process = ExpUtil.safe_value })
            if options.max_line_count == nil or select(2, rtn:gsub("\n", "")) < options.max_line_count then return rtn end
        end
        return inspect(value, { depth = options.depth or 5, indent = "", newline = "", process = ExpUtil.safe_value })
    end
    return formatted
end

--- @alias Common.format_time_param_format "short" | "long" | "clock"

--- @class Common.format_time_param_units
--- @field days boolean? True if days are included
--- @field hours boolean? True if hours are included
--- @field minutes boolean? True if minutes are included
--- @field seconds boolean? True if seconds are included

--- Format a tick value into one of a selection of pre-defined formats (short, long, clock)
--- @param ticks number|nil The number of ticks which will be represented, can be any duration or time value
--- @param format Common.format_time_param_format format to display, must be one of: short, long, clock
--- @param units Common.format_time_param_units A table selecting which units should be displayed, options are: days, hours, minutes, seconds
--- @return string # The ticks formatted into a string of the desired format
function ExpUtil.format_time(ticks, format, units)
    --- @type string | number, string | number, string | number, string | number
    local rtn_days, rtn_hours, rtn_minutes, rtn_seconds = "--", "--", "--", "--"

    if ticks ~= nil then
        -- Calculate the values to be determine the display values
        local max_days, max_hours, max_minutes, max_seconds = ticks / 5184000, ticks / 216000, ticks / 3600, ticks / 60
        local days, hours = max_days, max_hours - floor(max_days) * 24
        local minutes, seconds = max_minutes - floor(max_hours) * 60, max_seconds - floor(max_minutes) * 60

        -- Calculate rhw units to be displayed
        rtn_days, rtn_hours, rtn_minutes, rtn_seconds = floor(days), floor(hours), floor(minutes), floor(seconds)
        if not units.days then rtn_hours = rtn_hours + rtn_days * 24 end
        if not units.hours then rtn_minutes = rtn_minutes + rtn_hours * 60 end
        if not units.minutes then rtn_seconds = rtn_seconds + rtn_minutes * 60 end
        --- @diagnostic enable: cast-local-type
    end

    local rtn = {}
    if format == "clock" then
        -- Example 12:34:56 or --:--:--
        if units.days then rtn[#rtn + 1] = rtn_days end
        if units.hours then rtn[#rtn + 1] = rtn_hours end
        if units.minutes then rtn[#rtn + 1] = rtn_minutes end
        if units.seconds then rtn[#rtn + 1] = rtn_seconds end
        return concat(rtn, ":")
    elseif format == "short" then
        -- Example 12d 34h 56m or --d --h --m
        if units.days then rtn[#rtn + 1] = rtn_days .. "d" end
        if units.hours then rtn[#rtn + 1] = rtn_hours .. "h" end
        if units.minutes then rtn[#rtn + 1] = rtn_minutes .. "m" end
        if units.seconds then rtn[#rtn + 1] = rtn_seconds .. "s" end
        return concat(rtn, " ")
    else
        -- Example 12 days, 34 hours, and 56 minutes or -- days, -- hours, and -- minutes
        if units.days then rtn[#rtn + 1] = rtn_days .. " days" end
        if units.hours then rtn[#rtn + 1] = rtn_hours .. " hours" end
        if units.minutes then rtn[#rtn + 1] = rtn_minutes .. " minutes" end
        if units.seconds then rtn[#rtn + 1] = rtn_seconds .. " seconds" end
        rtn[#rtn] = "and " .. rtn[#rtn]
        return concat(rtn, ", ")
    end
end

--- Format a tick value into one of a selection of pre-defined formats (short, long, clock)
--- @param ticks number|nil The number of ticks which will be represented, can be any duration or time value
--- @param format Common.format_time_param_format format to display, must be one of: short, long, clock
--- @param units Common.format_time_param_units A table selecting which units should be displayed, options are: days, hours, minutes, seconds
--- @return LocalisedString # The ticks formatted into a string of the desired format
function ExpUtil.format_time_locale(ticks, format, units)
    --- @type string | number, string | number, string | number, string | number
    local rtn_days, rtn_hours, rtn_minutes, rtn_seconds = "--", "--", "--", "--"

    if ticks ~= nil then
        -- Calculate the values to be determine the display values
        local max_days, max_hours, max_minutes, max_seconds = ticks / 5184000, ticks / 216000, ticks / 3600, ticks / 60
        local days, hours = max_days, max_hours - floor(max_days) * 24
        local minutes, seconds = max_minutes - floor(max_hours) * 60, max_seconds - floor(max_minutes) * 60

        -- Calculate rhw units to be displayed
        rtn_days, rtn_hours, rtn_minutes, rtn_seconds = floor(days), floor(hours), floor(minutes), floor(seconds)
        if not units.days then rtn_hours = rtn_hours + rtn_days * 24 end
        if not units.hours then rtn_minutes = rtn_minutes + rtn_hours * 60 end
        if not units.minutes then rtn_seconds = rtn_seconds + rtn_minutes * 60 end
    end

    local rtn = {}
    local join = ", " --- @type LocalisedString
    if format == "clock" then
        -- Example 12:34:56 or --:--:--
        if units.days then rtn[#rtn + 1] = rtn_days end
        if units.hours then rtn[#rtn + 1] = rtn_hours end
        if units.minutes then rtn[#rtn + 1] = rtn_minutes end
        if units.seconds then rtn[#rtn + 1] = rtn_seconds end
        join = { "colon" }
    elseif format == "short" then
        -- Example 12d 34h 56m or --d --h --m
        if units.days then rtn[#rtn + 1] = { "?", { "time-symbol-days-short", rtn_days }, rtn_days .. "d" } end
        if units.hours then rtn[#rtn + 1] = { "time-symbol-hours-short", rtn_hours } end
        if units.minutes then rtn[#rtn + 1] = { "time-symbol-minutes-short", rtn_minutes } end
        if units.seconds then rtn[#rtn + 1] = { "time-symbol-seconds-short", rtn_seconds } end
        join = " "
    else
        -- Example 12 days, 34 hours, and 56 minutes or -- days, -- hours, and -- minutes
        if units.days then rtn[#rtn + 1] = { "days", rtn_days } end
        if units.hours then rtn[#rtn + 1] = { "hours", rtn_hours } end
        if units.minutes then rtn[#rtn + 1] = { "minutes", rtn_minutes } end
        if units.seconds then rtn[#rtn + 1] = { "seconds", rtn_seconds } end
        rtn[#rtn] = { "", { "and" }, " ", rtn[#rtn] }
    end

    --- @type LocalisedString
    local joined = { "" }
    for k, v in ipairs(rtn) do
        joined[2 * k] = v
        joined[2 * k + 1] = join
    end

    return joined
end

--- @class Common.format_time_factory_param: Common.format_time_param_units
--- @field format Common.format_time_param_format The format to use
--- @field coefficient number? If present will multiply the input by this amount before formatting

--- Create a formatter to format a tick value into one of a selection of pre-defined formats (short, long, clock)
--- @param options Common.format_time_factory_param
--- @return fun(ticks: number|nil): string
function ExpUtil.format_time_factory(options)
    local formatter, format, coefficient = ExpUtil.format_time, options.format, options.coefficient
    if coefficient then
        return function(ticks) return formatter(ticks and ticks * coefficient or nil, format, options) end
    end
    return function(ticks) return formatter(ticks, format, options) end
end

--- Create a formatter to format a tick value into one of a selection of pre-defined formats (short, long, clock)
--- @param options Common.format_time_factory_param
--- @return fun(ticks: number|nil): LocalisedString
function ExpUtil.format_time_factory_locale(options)
    local formatter, format, coefficient = ExpUtil.format_time_locale, options.format, options.coefficient
    if coefficient then
        return function(ticks) return formatter(ticks and ticks * coefficient or nil, format, options) end
    end
    return function(ticks) return formatter(ticks, format, options) end
end

--- @class Common.get_or_create_storage_cache
--- @field entities LuaEntity[] Array of found entities matching the search
--- @field current number The current index within the entity array
--- @field count number The number of entities found

--- @class Common.get_or_create_storage_param: EntitySearchFilters
--- @field item ItemStackIdentification The item stack that must be insertable
--- @field surface LuaSurface The surface to search for targets on
--- @field allow_creation boolean? If new entities can be create to store the items
--- @field cache Common.get_or_create_storage_cache? Internal search cache passed between subsequent calls
--- @field name? EntityID Entity to be created if allow_creation is true
--- @field force? ForceID Force of the created entity, defaults to 'neutral'

--- Find, or optionally create, a storage entity which a stack can be inserted into
--- @param options Common.get_or_create_storage_param
--- @return LuaEntity
function ExpUtil.get_storage_for_stack(options)
    local surface = assert(options.surface, "A surface must be provided")
    local item = assert(options.item, "An item stack must be provided")

    -- Perform a search if on has not been done already
    local cache = options.cache
    if not cache then
        local entities = surface.find_entities_filtered(options)
        cache = {
            entities = entities,
            count = #entities,
            current = 0,
        }
        options.cache = cache
    end

    -- Find a valid entity from the search results
    local current, count, entities = cache.current, cache.count, cache.entities
    for i = 1, cache.count do
        local entity = entities[((current + i - 1) % count) + 1]
        if entity and entity.can_insert(item) then
            cache.current = current + 1
            return entity
        end
    end

    -- No entity was found so one needs to be created
    assert(options.allow_creation, "Unable to find valid entity, consider enabling allow_creation")
    assert(options.name, "Name must be provided to allow creation of new entities")

    local position
    if options.position then
        position = surface.find_non_colliding_position(options.name, options.position, options.radius or 0, 1, true)
    elseif options.area then
        position = surface.find_non_colliding_position_in_box(options.name, options.area, 1, true)
    else
        position = surface.find_non_colliding_position(options.name, { 0, 0 }, 0, 1, true)
    end
    assert(position, "Failed to find valid location")

    local entity = surface.create_entity{ name = options.name, position = position, force = options.force or "neutral" }
    assert(entity, "Failed to create a new entity")

    cache.count = count + 1
    entities[count] = entity
    return entity
end

--- @class Common.copy_items_to_surface_param: Common.get_or_create_storage_param
--- @field items ItemStackIdentification[] | LuaInventory The item stacks to copy
--- @field item ItemStackIdentification? Overwritten internally

--- Insert a copy of the given items into the found entities. If no entities are found then they will be created if possible.
--- @param options Common.copy_items_to_surface_param
--- @return LuaEntity # The last entity inserted into
function ExpUtil.copy_items_to_surface(options)
    local entity
    for item_index = 1, #options.items do
        options.item = options.items[item_index]
        entity = ExpUtil.get_storage_for_stack(options)
        entity.insert(options.item)
    end
    return entity
end

--- @class Common.move_items_to_surface_param: Common.get_or_create_storage_param
--- @field items LuaItemStack[] The item stacks to move
--- @field item ItemStackIdentification? Overwritten internally

--- Insert a copy of the given items into the found entities. If no entities are found then they will be created if possible.
--- @param options Common.move_items_to_surface_param
--- @return LuaEntity # The last entity inserted into
function ExpUtil.move_items_to_surface(options)
    local entity
    for item_index = 1, #options.items do
        options.item = options.items[item_index]
        entity = ExpUtil.get_storage_for_stack(options)
        entity.insert(options.item)
        options.item.clear()
    end
    return entity
end

--- @class Common.transfer_inventory_to_surface_param: Common.copy_items_to_surface_param
--- @field inventory LuaInventory The inventory to transfer
--- @field items (ItemStackIdentification[] | LuaInventory)? Overwritten internally

--- Move the given inventory into the found entities. If no entities are found then they will be created if possible.
--- @param options Common.transfer_inventory_to_surface_param
--- @return LuaEntity # The last entity inserted into
function ExpUtil.transfer_inventory_to_surface(options)
    options.items = options.inventory
    local entity = ExpUtil.copy_items_to_surface(options)
    options.inventory.clear()
    return entity
end

--- Create an enum table from a set of strings, can use custom indexes to change base
--- @param values string[]
--- @return table<string | number, string | number>
function ExpUtil.enum(values)
    local enum = {}

    local index = 0 -- Real index within values
    local offset = 0 -- Offset from base for next index
    local base = 0 -- Start point for offset
    for k, v in pairs(values) do
        index = index + 1
        if k ~= index then
            offset = 0
            base = k
        end
        enum[base + offset] = v
        offset = offset + 1
    end

    for k, v in pairs(enum) do
        if type(k) == "number" then
            enum[v] = k
        end
    end

    return enum
end

--- Returns a string for a number with comma separators
--- @param n number
--- @return string
function ExpUtil.comma_value(n) -- credit http://richard.warburton.it
    local left, num, right = string.match(n, "^([^%d]*%d)(%d*)(.-)$")
    return left .. (num:reverse():gsub("(%d%d%d)", "%1, "):reverse()) .. right
end

--- Returns a message formatted for game chat using rich text colour tags
--- @param message string
--- @param color Color
--- @return string
function ExpUtil.format_rich_text_color(message, color)
    return format_string(
        "[color=%s,%s,%s]%s[/color]",
        round(color.r or color[1] or 0, 3),
        round(color.g or color[2] or 0, 3),
        round(color.b or color[3] or 0, 3),
        message
    )
end

--- Returns a message formatted for game chat using rich text colour tags
--- @param message LocalisedString
--- @param color Color
--- @return LocalisedString
function ExpUtil.format_rich_text_color_locale(message, color)
    return {
        "rich-text-color-tag",
        round(color.r or color[1] or 0, 3),
        round(color.g or color[2] or 0, 3),
        round(color.b or color[3] or 0, 3),
        message
    }
end

--- Formats a players name using rich text color
--- @param player PlayerIdentification?
--- @return string
function ExpUtil.format_player_name(player)
    local valid_player = type(player) == "userdata" and player or game.get_player(player --[[@as string|number]]) --[[@as LuaPlayer?]]
    local player_name = valid_player and valid_player.name or "<Server>"
    local player_chat_colour = valid_player and valid_player.chat_color or ExpUtil.color.white
    return ExpUtil.format_rich_text_color(player_name, player_chat_colour)
end

--- Formats a players name using rich text color
--- @param player PlayerIdentification?
--- @return LocalisedString
function ExpUtil.format_player_name_locale(player)
    local valid_player = type(player) == "userdata" and player or game.get_player(player --[[@as string|number]]) --[[@as LuaPlayer?]]
    local player_name = valid_player and valid_player.name or "<Server>"
    local player_chat_colour = valid_player and valid_player.chat_color or ExpUtil.color.white
    return ExpUtil.format_rich_text_color_locale(player_name, player_chat_colour)
end

--- Teleport a player to a position on a surface
--- @param player LuaPlayer Player to teleport
--- @param surface LuaSurface Destination surface
--- @param position MapPosition Destination position
--- @param vehicle_behaviour "allow"|"disallow"|"dismount"? How to handle players who are in a vehicle, default is dismount
--- @return boolean # True if teleported successfully
function ExpUtil.teleport_player(player, surface, position, vehicle_behaviour)
    local found_position = surface.find_non_colliding_position("character", position, 32, 1)

    -- Return false if no new position
    if not found_position then
        return false
    end

    -- Check if the player is in a vehicle
    local vehicle = player.vehicle
    if not vehicle then
        return player.teleport(found_position, surface)
    end

    -- Handle different vehicle behaviour
    if vehicle_behaviour == "disallow" then
        return false
    elseif vehicle_behaviour == "dismount" then
        player.driving = false
        return player.teleport(found_position, surface)
    end

    -- Teleport the vehicle, or the player if that fails
    local vehicle_position = surface.find_non_colliding_position(vehicle.name, position, 32, 1)
    if not vehicle_position or not vehicle.teleport(vehicle_position, surface) then
        player.driving = false
        return player.teleport(found_position, surface)
    end

    return true
end

return ExpUtil
