--[[-- Util Module - Common
- Adds some commonly used functions used in many modules
@core Common
@alias Common
]]

local assert = assert
--local getlocal = debug.getlocal
--local getupvalue = debug.getupvalue
local getinfo = debug.getinfo
local traceback = debug.traceback
local floor = math.floor
local concat = table.concat

local Common = {
    --- A large mapping of colour rgb values by their common name
    color = require 'modules.exp_util.include.color'
}

--- Raise an error if we are not in runtime
function Common.assert_not_runtime()
    assert(package.lifecycle ~= package.lifecycle_stage.runtime, "Can not be called during runtime")
end

--[[local assert_not_closure_fmt = "Can not be called with the closure %s at runtime"
--- Raise an error if a function is a closure and we are in runtime
-- @tparam function func The function to assert is not a closure if we are in runtime
function Common.assert_not_closure(func)
    assert(package.lifecycle ~= package.lifecycle_stage.runtime, "Can not be called during runtime")
    local info = getinfo(2, "nu")
    for i = 1, info.nups do
        if getupvalue(func, i) ~= "_ENV" then
            error(assert_not_closure_fmt:format(info.name or "<anonymous>"))
        end
    end
end]]

local assert_type_fmt = "%s expected to be of type %s but got %s"
--- Raise an error if the type of a value is not as expected
-- @param value The value to assert the type of
-- @tparam string type_name The name of the type that value is expected to be
-- @tparam[opt=Value] string value_name The name of the value being tested, this is included in the error message
function Common.assert_type(value, type_name, value_name)
    if value == nil or type(value) ~= type_name then
        error(assert_type_fmt:format(value_name or "Value", type_name, type(value)), 2)
    end
end

local assert_argument_fmt = "Bad argument #%d to %s; %s expected to be of type %s but got %s"
--[[--- Raise an error if the type of any argument is not as expected, can be costly, for frequent callers see assert_argument_type
-- @tparam string ... The type for each argument of the calling function
function Common.assert_argument_types(...)
    local arg_types = {...}
    local info = getinfo(2, "nu")
    for arg_index = 1, info.nparams do
        local arg_name, arg_value = getlocal(2, arg_index)
        if arg_types[arg_index] and (arg_value == nil or type(arg_value) ~= arg_types[arg_index]) then
            error(assert_argument_fmt:format(arg_index, info.name or "<anonymous>", arg_name, arg_types[arg_index]), 2)
        end
    end
end]]

--- Raise an error if the type of any argument is not as expected, more performant than assert_argument_types, but requires more manual input
-- @param arg_value The argument to assert the type of
-- @tparam string type_name The name of the type that value is expected to be
-- @tparam number arg_index The index of the argument being tested, this is included in the error message
-- @tparam[opt=Argument] string arg_name The name of the argument being tested, this is included in the error message
function Common.assert_argument_type(arg_value, type_name, arg_index, arg_name)
    if arg_value == nil or type(arg_value) ~= type_name then
        local func_name = getinfo(2, "n").name or "<anonymous>"
        error(assert_argument_fmt:format(arg_index, func_name, arg_name or "Argument", type_name), 2)
    end
end

--- Write a luu table to a file as a json string, note the defaults are different to game.write_file
-- @tparam string path The path to write the json to
-- @tparam table value The table to write to file
-- @tparam[opt=false] boolean overwrite When true the json replaces the full contents of the file
-- @tparam[opt=0] number player_index The player's machine to write on, -1 means all, 0 means host only
function Common.write_json(path, tbl, overwrite, player_index)
    if player_index == -1 then
        return game.write_file(path, game.table_to_json(tbl).."\n", not overwrite)
    end
    return game.write_file(path, game.table_to_json(tbl).."\n", not overwrite, player_index or 0)
end

--- Clear a file by replacing its contents with an empty string
-- @tparam string path The path to clear the contents of
-- @tparam[opt=0] number player_index The player's machine to write on, -1 means all, 0 means host only
function Common.clear_file(path, player_index)
    if player_index == -1 then
        return game.write_file(path, "", false)
    end
    return game.write_file(path, "", false, player_index or 0)
end

--- Same as require but will return nil if the module does not exist, all other errors will propagate to the caller
-- @tparam string module_path The path to the module to require, same syntax as normal require
-- @return The contents of the module, or nil if the module does not exist or did not return a value
function Common.optional_require(module_path)
    local success, rtn = xpcall(require, traceback, module_path)
    if success then return rtn end
    if not rtn:find("not found; no such file", 0, true) then
        error(rtn, 2)
    end
end

--- Returns a desync sale filepath for a given stack frame, default is the current file
-- @tparam number level The level of the stack to get the file of, a value of 1 is the caller of this function
-- @treturn string The relative filepath of the given stack frame
function Common.safe_file_path(level)
    level = level or 1
    return getinfo(level+1, 'S').source:match('^.+/currently%-playing/(.+)$'):sub(1, -5)
end

--- Returns the name of your module, this assumes your module is stored within /modules (which it is for clustorio)
-- @tparam[opt=1] number level The level of the stack to get the module of, a value of 1 is the caller of this function
-- @treturn string The name of the module at the given stack frame
function Common.get_module_name(level)
    local file_within_module = getinfo((level or 1)+1, 'S').source:match('^.+/currently%-playing/modules/(.+)$'):sub(1, -5)
    local next_slash = file_within_module:find("/")
    if next_slash then
        return file_within_module:sub(1, next_slash-1)
    else
        return file_within_module
    end
end

--- Returns the name of a function in a safe and consistent format
-- @tparam number|function func The level of the stack to get the name of, a value of 1 is the caller of this function
-- @tparam boolean raw When true there will not be any < > around the name
-- @treturn string The name of the function at the given stack frame or provided as an argument
function Common.get_function_name(func, raw)
	local debug_info = getinfo(func, "Sn")
	local safe_source = debug_info.source:match('^.+/currently%-playing/(.+)$')
    local file_name = safe_source and safe_source:sub(1, -5) or debug_info.source
    local func_name = debug_info.name or debug_info.linedefined
	if raw then return file_name .. ":" .. func_name end
	return "<" .. file_name .. ":" .. func_name .. ">"
end

--- Attempt a simple autocomplete search from a set of options
-- @tparam table options The table representing the possible options which can be selected
-- @tparam string input The user input string which should be matched to an option
-- @tparam[opt=false] boolean use_key When true the keys will be searched, when false the values will be searched
-- @tparam[opt=false] boolean rtn_key When true the selected key will be returned, when false the selected value will be returned
-- @return The selected key or value which first matches the input text
function Common.auto_complete(options, input, use_key, rtn_key)
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

--- Formats any value into a safe representation, useful with table.insert
-- @param value The value to be formated
-- @return The formated version of the value
-- @return True if value is a locale string, nil otherwise
function Common.safe_value(value)
	if type(value) == "table" or type(value) == "userdata" then
        if type(value.__self) == "userdata" or type(value) == "userdata" then
			local success, rtn = pcall(function() -- some userdata doesnt contain "valid"
				if value.valid then -- userdata
					return "<userdata:"..value.object_name..">"
				else -- invalid userdata
					return "<userdata:"..value.object_name..":invalid>"
				end
			end)
			return success and rtn or "<userdata:"..value.object_name..">"
        elseif type(value[1]) == "string" and string.find(value[1], ".+[.].+") and not string.find(value[1], "%s") then
            return value, true -- locale string
        elseif tostring(value) ~= "table" then
            return tostring(value) -- has __tostring metamethod
		else -- plain table
            return value
        end
    elseif type(value) == "function" then -- function
        return "<function:"..Common.get_function_name(value, true)..">"
    else -- not: table, userdata, or function
        return tostring(value)
    end
end

--- Formats any value to be presented in a safe and human readable format
-- @param value The value to be formated
-- @param[opt] tableAsJson If table values should be returned as json
-- @param[opt] maxLineCount If table newline count exceeds provided then it will be inlined
-- @return The formated version of the value
function Common.format_any(value, tableAsJson, maxLineCount)
	local formatted, is_locale_string = Common.safe_value(value)
    if type(formatted) == "table" and not is_locale_string then
		if tableAsJson then
			local success, rtn = pcall(game.table_to_json, value)
			if success then return rtn end
		end
        local rtn = table.inspect(value, {depth=5, indent=' ', newline='\n', process=Common.safe_value})
		if maxLineCount == nil or select(2, rtn:gsub("\n", "")) < maxLineCount then return rtn end
		return table.inspect(value, {depth=5, indent='', newline='', process=Common.safe_value})
	end
	return formatted
end

--- Format a tick value into one of a selection of pre-defined formats (short, long, clock)
-- @tparam number ticks The number of ticks which will be represented, can be any duration or time value
-- @tparam string format The format to display, must be one of: short, long, clock
-- @tparam[opt] table units A table selecting which units should be displayed, options are: days, hours, minutes, seconds
-- @treturn string The ticks formatted into a string of the desired format
function Common.format_time(ticks, format, units)
    units = units or { days = false, hours = true, minutes = true, seconds = false }
    local rtn_days, rtn_hours, rtn_minutes, rtn_seconds = "--", "--", "--", "--"

    if ticks ~= nil then
        -- Calculate the values to be determine the display values
        local max_days, max_hours, max_minutes, max_seconds = ticks/5184000, ticks/216000, ticks/3600, ticks/60
        local days, hours = max_days, max_hours-floor(max_days)*24
        local minutes, seconds = max_minutes-floor(max_hours)*60, max_seconds-floor(max_minutes)*60

        -- Calculate rhw units to be displayed
        rtn_days, rtn_hours, rtn_minutes, rtn_seconds = floor(days), floor(hours), floor(minutes), floor(seconds)
        if not units.days then rtn_hours = rtn_hours + rtn_days*24 end
        if not units.hours then rtn_minutes = rtn_minutes + rtn_hours*60 end
        if not units.minutes then rtn_seconds = rtn_seconds + rtn_minutes*60 end
    end

    local rtn = {}
    if format == "clock" then
        -- Example 12:34:56 or --:--:--
        if units.days then rtn[#rtn+1] = rtn_days end
        if units.hours then rtn[#rtn+1] = rtn_hours end
        if units.minutes then rtn[#rtn+1] = rtn_minutes end
        if units.seconds then rtn[#rtn+1] = rtn_seconds end
        return concat(rtn, ":")
    elseif format == "short" then
        -- Example 12d 34h 56m or --d --h --m
        if units.days then rtn[#rtn+1] = rtn_days.."d" end
        if units.hours then rtn[#rtn+1] = rtn_hours.."h" end
        if units.minutes then rtn[#rtn+1] = rtn_minutes.."m" end
        if units.seconds then rtn[#rtn+1] = rtn_seconds.."s" end
        return concat(rtn, " ")
    else
        -- Example 12 days, 34 hours, and 56 minutes or -- days, -- hours, and -- minutes
        if units.days then rtn[#rtn+1] = rtn_days.." days" end
        if units.hours then rtn[#rtn+1] = rtn_hours.." hours" end
        if units.minutes then rtn[#rtn+1] = rtn_minutes.." minutes" end
        if units.seconds then rtn[#rtn+1] = rtn_seconds.." seconds" end
        rtn[#rtn] = "and "..rtn[#rtn]
        return concat(rtn, ", ")
    end
end

--- Format a tick value into one of a selection of pre-defined formats (short, long, clock)
-- @tparam number ticks The number of ticks which will be represented, can be any duration or time value
-- @tparam string format The format to display, must be one of: short, long, clock
-- @tparam[opt] table units A table selecting which units should be displayed, options are: days, hours, minutes, seconds
-- @treturn LocaleString The ticks formatted into a LocaleString of the desired format
function Common.format_locale_time(ticks, format, units)
    units = units or { days = false, hours = true, minutes = true, seconds = false }
    local rtn_days, rtn_hours, rtn_minutes, rtn_seconds = "--", "--", "--", "--"

    if ticks ~= nil then
        -- Calculate the values to be determine the display values
        local max_days, max_hours, max_minutes, max_seconds = ticks/5184000, ticks/216000, ticks/3600, ticks/60
        local days, hours = max_days, max_hours-floor(max_days)*24
        local minutes, seconds = max_minutes-floor(max_hours)*60, max_seconds-floor(max_minutes)*60

        -- Calculate rhw units to be displayed
        rtn_days, rtn_hours, rtn_minutes, rtn_seconds = floor(days), floor(hours), floor(minutes), floor(seconds)
        if not units.days then rtn_hours = rtn_hours + rtn_days*24 end
        if not units.hours then rtn_minutes = rtn_minutes + rtn_hours*60 end
        if not units.minutes then rtn_seconds = rtn_seconds + rtn_minutes*60 end
    end

    local rtn = {}
    local join = ", "
    if format == "clock" then
        -- Example 12:34:56 or --:--:--
        if units.days then rtn[#rtn+1] = rtn_days end
        if units.hours then rtn[#rtn+1] = rtn_hours end
        if units.minutes then rtn[#rtn+1] = rtn_minutes end
        if units.seconds then rtn[#rtn+1] = rtn_seconds end
        join = { "colon" }
    elseif format == "short" then
        -- Example 12d 34h 56m or --d --h --m
        if units.days then rtn[#rtn+1] = {"?", {"time-symbol-days-short", rtn_days}, rtn_days.."d"} end
        if units.hours then rtn[#rtn+1] = {"time-symbol-hours-short", rtn_hours} end
        if units.minutes then rtn[#rtn+1] = {"time-symbol-minutes-short", rtn_minutes} end
        if units.seconds then rtn[#rtn+1] = {"time-symbol-seconds-short", rtn_seconds} end
        join = " "
    else
        -- Example 12 days, 34 hours, and 56 minutes or -- days, -- hours, and -- minutes
        if units.days then rtn[#rtn+1] = {"days", rtn_days} end
        if units.hours then rtn[#rtn+1] = {"hours", rtn_hours} end
        if units.minutes then rtn[#rtn+1] = {"minutes", rtn_minutes} end
        if units.seconds then rtn[#rtn+1] = {"seconds", rtn_seconds} end
        rtn[#rtn] = {"", { "and" }, " ", rtn[#rtn]}
    end

    local joined = { "" }
    for k, v in ipairs(rtn) do
        joined[2*k] = v
        joined[2*k+1] = join
    end
    return joined
end

--- Insert a copy of the given items into the found / created entities. If no entities are found then they will be created if possible.
-- @tparam table items The items which are to be inserted into the entities, an array of LuaItemStack
-- @tparam LuaSurface surface The surface which will be searched to find the entities
-- @tparam table options A table of various optional options similar to find_entities_filtered
-- position + radius or area can be used to define a search area on the surface
-- type can be used to find all entities of a given type, such as a chest
-- name can be used to further specify which entity to insert into, this field is required if entity creation is desired
-- allow_creation is a boolean which when true will allow the function to create new entities in order to insert all items
-- force is the force which new entities will be created to, the default is the neutral force
-- @treturn LuaEntity the last entity that had items inserted into it
function Common.insert_item_stacks(items, surface, options)
    local entities = surface.find_entities_filtered(options)
    local count, current, last_entity = #entities, 0, nil

    for _, item in ipairs(items) do
        if item.valid_for_read then
            local inserted = false

            -- Attempt to insert the items
            for i = 1, count do
                local entity = entities[((current+i-1)%count)+1]
                if entity.can_insert(item) then
                    last_entity = entity
                    current = current + 1
                    entity.insert(item)
                    inserted = true
                end
            end

            -- If it was not inserted then a new entity is needed
            if not inserted then
                if not options.allow_creation then error("Unable to insert items into a valid entity, consider enabling allow_creation") end
                if options.name == nil then error("Name must be provided to allow creation of new entities") end

                local position
                if options.position then
                    position = surface.find_non_colliding_position(options.name, options.position, options.radius, 1, true)
                elseif options.area then
                    position = surface.find_non_colliding_position_in_box(options.name, options.area, 1, true)
                else
                    position = surface.find_non_colliding_position(options.name, {0,0}, 0, 1, true)
                end
                last_entity = surface.create_entity{name = options.name, position = position, force = options.force or "neutral"}

                count = count + 1
                entities[count] = last_entity
                last_entity.insert(item)
            end
        end
    end

    return last_entity
end

--- Move the given items into the found / created entities. If no entities are found then they will be created if possible.
-- @tparam table items The items which are to be inserted into the entities, an array of LuaItemStack
-- @tparam LuaSurface surface The surface which will be searched to find the entities
-- @tparam table options A table of various optional options similar to find_entities_filtered
-- position + radius or area can be used to define a search area on the surface
-- type can be used to find all entities of a given type, such as a chest
-- name can be used to further specify which entity to insert into, this field is required if entity creation is desired
-- allow_creation is a boolean which when true will allow the function to create new entities in order to insert all items
-- @treturn LuaEntity the last entity that had items inserted into it
function Common.transfer_item_stacks(inventory, surface, options)
    Common.insert_item_stacks(inventory, surface, options)
    inventory.clear()
end

return Common
