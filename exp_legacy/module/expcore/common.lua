--[[-- Core Module - Common
- Adds some commonly used functions used in many modules
@core Common
@alias Common
]]

local Colours = require 'utils.color_presets' --- @dep utils.color_presets
local Game = require 'utils.game' --- @dep utils.game

local Common = {}

--- Type Checking.
-- @section typeCheck

--[[-- Asserts the argument is of type test_type
@tparam any value the value to be tested
@tparam[opt=nil] string test_type the type to test for if not given then it tests for nil
@treturn boolean is v of type test_type

@usage-- Check for a string value
local is_string = type_check(value, 'string')

@usage-- Check for a nil value
local is_nil = type_check(value)

]]
function Common.type_check(value, test_type)
    return test_type and value and type(value) == test_type or not test_type and not value or false
end

--[[-- Raises an error if the value is of the wrong type
@tparam any value the value that you want to test the type of
@tparam string test_type the type that the value should be
@tparam string error_message the error message that is returned
@tparam number level the level to call the error on (level = 1 is the caller)
@treturn boolean true if no error was called

@usage-- Raise error if value is not a number
type_error(value, 'number', 'Value must be a number')

]]
function Common.type_error(value, test_type, error_message, level)
    level = level and level+1 or 2
    return Common.type_check(value, test_type) or error(error_message, level)
end

--[[-- Asserts the argument is one of type test_types
@param value the variable to check
@param test_types the type as a table of strings
@treturn boolean true if value is one of test_types

@usage-- Check for a string or table
local is_string_or_table = multi_type_check(value, {'string', 'table'})

]]
function Common.multi_type_check(value, test_types)
    local vtype = type(value)
    for _, arg_type in ipairs(test_types) do
        if vtype == arg_type then
            return true
        end
    end
    return false
end

--[[-- Raises an error if the value is of the wrong type
@tparam any value the value that you want to test the type of
@tparam table test_types the type as a table of strings
@tparam string error_message the error message that is returned
@tparam number level the level to call the error on (level = 1 is the caller)
@treturn boolean true if no error was called

@usage-- Raise error if value is not a string or table
multi_type_error('foo', {'string', 'table'}, 'Value must be a string or table')

]]
function Common.multi_type_error(value, test_types, error_message, level)
    level = level and level+1 or 2
    return Common.mult_type_check(value, test_types) or error(error_message, level)
end

--[[-- Raises an error when the value is the incorrect type, uses a consistent error message format
@tparam any value the value that you want to test the type of
@tparam string test_type the type that the value should be
@tparam number param_number the number param it is
@tparam[opt] string param_name the name of the param
@treturn boolean true if no error was raised

@usage-- Output: "Bad argument #2 to "<anon>"; argument is of type string expected number"
validate_argument_type(value, 'number', 2)

@usage-- Output: "Bad argument #2 to "<anon>"; "repeat_count" is of type string expected number"
validate_argument_type(value, 'number', 2, 'repeat_count')

]]
function Common.validate_argument_type(value, test_type, param_number, param_name)
    if not Common.test_type(value, test_type) then
        local function_name = debug.getinfo(2, 'n').name or '<anon>'
        local error_message
        if param_name then
            error_message = string.format('Bad argument #%d to %q; %q is of type %s expected %s', param_number, function_name, param_name, type(value), test_type)
        else
            error_message = string.format('Bad argument #%d to %q; argument is of type %s expected %s', param_number, function_name, type(value), test_type)
        end
        return error(error_message, 3)
    end
    return true
end

--[[-- Raises an error when the value is the incorrect type, uses a consistent error message format
@tparam any value the value that you want to test the type of
@tparam string test_types the types that the value should be
@tparam number param_number the number param it is
@tparam[opt] string param_name the name of the param
@treturn boolean true if no error was raised

@usage-- Output: "Bad argument #2 to "<anon>"; argument is of type number expected string or table"
validate_argument_type(value, {'string', 'table'}, 2)

@usage-- Output: "Bad argument #2 to "<anon>"; "player" is of type number expected string or table"
validate_argument_type(value, {'string', 'table'}, 2, 'player')

]]
function Common.validate_argument_multi_type(value, test_types, param_number, param_name)
    if not Common.multi_type_check(value, test_types) then
        local function_name = debug.getinfo(2, 'n').name or '<anon>'
        local error_message
        if param_name then
            error_message = string.format('Bad argument #%2d to %q; %q is of type %s expected %s', param_number, function_name, param_name, type(value), table.concat(test_types, ' or '))
        else
            error_message = string.format('Bad argument #%2d to %q; argument is of type %s expected %s', param_number, function_name, type(value), table.concat(test_types, ' or '))
        end
        return error(error_message, 3)
    end
    return true
end

--- Will raise an error if called during runtime
-- @usage error_if_runtime()
function Common.error_if_runtime()
    if _LIFECYCLE == 8 then
        local function_name = debug.getinfo(2, 'n').name or '<anon>'
        error(function_name..' can not be called during runtime', 3)
    end
end

--- Will raise an error if the function is a closure
-- @usage error_if_runetime_closure(func)
function Common.error_if_runetime_closure(func)
    if _LIFECYCLE == 8 and Debug.is_closure(func) then
        local function_name = debug.getinfo(2, 'n').name or '<anon>'
        error(function_name..' can not be called during runtime with a closure', 3)
    end
end

--- Value Returns.
-- @section valueReturns

--[[-- Tests if a string contains a given substring.
@tparam string s the string to check for the substring
@tparam string contains the substring to test for
@treturn boolean true if the substring was found in the string

@usage-- Test if a string contains a sub string
local found = string_contains(str, 'foo')

]]
function Common.string_contains(s, contains)
    return s and string.find(s, contains) ~= nil
end

--[[-- Used to resolve a value that could also be a function returning that value
@tparam any value the value which you want to test is not nil and if it is a function then call the function
@treturn any the value given or returned by value if it is a function

@usage-- Default value handling
-- if default value is not a function then it is returned
-- if default value is a function then it is called with the first argument being self
local value = Common.resolve_value(self.defaut_value, self)

]]
function Common.resolve_value(value, ...)
    return value and type(value) == 'function' and value(...) or value
end

--- Converts a varible into its boolean value, nil and false return false
-- @treturn boolean the boolean form of the varible
-- @usage local bool = cast_bool(var)
function Common.cast_bool(var)
    return var and true or false
end

--- Returns either the second or third argument based on the first argument
-- @usage ternary(input_string == 'test', 'Input is test', 'Input is not test')
function Common.ternary(c, t, f)
    return c and t or f
end

--- Returns a string for a number with comma seperators
-- @usage comma_value(input_number)
function Common.comma_value(n) -- credit http://richard.warburton.it
    local left, num, right = string.match(n, '^([^%d]*%d)(%d*)(.-)$')
    return left .. (num:reverse():gsub('(%d%d%d)', '%1, '):reverse()) .. right
end

--[[-- Sets a table element to value while also returning value.
@tparam table tbl to change the element of
@tparam string key the key to set the value of
@tparam any value the value to set the key as
@treturn any the value that was set

@usage-- Set and return value
local value = set_and_return(players, player.name, player.online_time)

]]
function Common.set_and_return(tbl, key, value)
    tbl[key] = value
    return value
end

--[[-- Writes a table object to a file in json format
@tparam string path the path of the file to write include / to use dir
@tparam table tbl the table that will be converted to a json string and wrote to file

@usage-- Write a lua table as a json to script-outpt/dump
write_json('dump', tbl)

]]
function Common.write_json(path, tbl)
    game.write_file(path, game.table_to_json(tbl)..'\n', true, 0)
end

--[[-- Calls a require that will not error if the file is not found
@usage local file = opt_require('file.not.present') -- will not cause any error
@tparam string path the path that you want to require
@return the returns from that file or nil, error if not loaded

@usage-- Require a file without causing errors, for when a file might not exist
local Module = opt_require 'expcore.common'

]]
function Common.opt_require(path)
    local success, rtn = pcall(require, path)
    if success then return rtn
    else return nil, rtn end
end

--[[-- Returns a desync safe file path for the current file
@tparam[opt=0] number offset the offset in the stack to get, 0 is current file
@treturn string the file path

@usage-- Get the current file path
local file_path = get_file_path()

]]
function Common.get_file_path(offset)
    offset = offset or 0
    return debug.getinfo(offset+2, 'S').source:match('^.+/currently%-playing/(.+)$'):sub(1, -5)
end

--[[-- Converts a table to an enum
@tparam table tbl table the that will be converted
@treturn table the new table that acts like an enum

@usage-- Make an enum
local colors = enum{
    'red',
    'green',
    'blue'
}

]]
function Common.enum(tbl)
    local rtn = {}
    for k, v in pairs(tbl) do
        if type(k) ~= 'number' then
            rtn[v]=k
        end
    end
    for k, v in pairs(tbl) do
        if type(k) == 'number' then
            table.insert(rtn, v)
        end
    end
    for k, v in pairs(rtn) do
        rtn[v]=k
    end
    return rtn
end

--[[-- Returns the closest match to the input
@tparam table options table a of options for the auto complete
@tparam string input string the input that will be completed
@tparam[opt=false] boolean use_key when true the keys of options will be used as the options
@tparam[opt=false] boolean rtn_key when true the the key will be returned rather than the value
@return the list item found that matches the input

@usage-- Get the element that includes "foo"
local value = auto_complete(tbl, "foo")

@usage-- Get the element with a key that includes "foo"
local value = auto_complete(tbl, "foo", true)

@usage-- Get the key with that includes "foo"
local key = auto_complete(tbl, "foo", true, true)

]]
function Common.auto_complete(options, input, use_key, rtn_key)
    if type(input) ~= 'string' then return end
    input = input:lower()
    for key, value in pairs(options) do
        local check = use_key and key or value
        if Common.string_contains(string.lower(check), input) then
            return rtn_key and key or value
        end
    end
end

--- Formatting.
-- @section formatting

--[[-- Returns a valid string with the name of the actor of a command.
@tparam string player_name the name of the player to use rather than server, used only if game.player is nil
@treturn string the name of the current actor

@usage-- Get the current actor
local player_name = get_actor()

]]
function Common.get_actor(player_name)
    return game.player and game.player.name or player_name or '<server>'
end

--[[-- Returns a message with valid chat tags to change its colour
@tparam string message the message that will be in the output
@tparam table color a color which contains r, g, b as its keys
@treturn string the message with the color tags included

@usage-- Use factorio tags to color a chat message
local message = format_chat_colour('Hello, World!', { r=355, g=100, b=100 })

]]
function Common.format_chat_colour(message, color)
    color = color or Colours.white
    local color_tag = '[color='..math.round(color.r, 3)..', '..math.round(color.g, 3)..', '..math.round(color.b, 3)..']'
    return string.format('%s%s[/color]', color_tag, message)
end

--[[-- Returns a message with valid chat tags to change its colour, using localization
@tparam ?string|table message the message that will be in the output
@tparam table color a color which contains r, g, b as its keys
@treturn table the message with the color tags included

@usage-- Use factorio tags and locale strings to color a chat message
local message = format_chat_colour_localized('Hello, World!', { r=355, g=100, b=100 })

]]
function Common.format_chat_colour_localized(message, color)
    color = color or Colours.white
    color = math.round(color.r, 3)..', '..math.round(color.g, 3)..', '..math.round(color.b, 3)
    return {'color-tag', color, message}
end

--[[-- Returns the players name in the players color
@tparam LuaPlayer player the player to use the name and color of
@tparam[opt=false] boolean raw_string when true a string is returned rather than a localized string
@treturn table the players name with tags for the players color

@usage-- Format a players name using the players color as a string
local message = format_chat_player_name(game.player, true)

]]
function Common.format_chat_player_name(player, raw_string)
    player = Game.get_player_from_any(player)
    local player_name = player and player.name or '<Server>'
    local player_chat_colour = player and player.chat_color or Colours.white
    if raw_string then
        return Common.format_chat_colour(player_name, player_chat_colour)
    else
        return Common.format_chat_colour_localized(player_name, player_chat_colour)
    end
end

--[[-- Will return a value of any type to the player/server console, allows colour for in-game players
@tparam any value a value of any type that will be returned to the player or console
@tparam[opt=defines.colour.white] ?defines.color|string colour the colour of the text for the player, ignored when printing to console
@tparam[opt=game.player] LuaPlayer player  the player that return will go to, if no game.player then returns to server

@usage-- Return a value to the current actor, rcon included
player_return('Hello, World!')

@usage-- Return a value to the current actor, with color
player_return('Hello, World!', 'green')

@usage-- Return to a player other than the current
player_return('Hello, World!', nil, player)

]]
function Common.player_return(value, colour, player)
    colour = Common.type_check(colour, 'table') and colour or Colours[colour] ~= Colours.white and Colours[colour] or Colours.white
    player = player or game.player
    -- converts the value to a string
    local returnAsString
    if Common.type_check(value, 'table') or type(value) == 'userdata' then
        if Common.type_check(value.__self, 'userdata') or type(value) == 'userdata' then
            -- value is userdata
            returnAsString = 'Cant Display Userdata'
        elseif Common.type_check(value[1], 'string') and string.find(value[1], '.+[.].+') and not string.find(value[1], '%s') then
            -- value is a locale string
            returnAsString = value
        elseif getmetatable(value) ~= nil and not tostring(value):find('table: 0x') then
            -- value has a tostring meta method
            returnAsString = tostring(value)
        else
            -- value is a table
            returnAsString = table.inspect(value, {depth=5, indent=' ', newline='\n'})
        end
    elseif Common.type_check(value, 'function') then
        -- value is a function
        returnAsString = 'Cant Display Functions'
    else returnAsString = tostring(value) end
    -- returns to the player or the server
    if player then
        -- allows any valid player identifier to be used
        player = Game.get_player_from_any(player)
        if not player then error('Invalid Player given to player_return', 2) end
        -- plays a nice sound that is different to normal message sound
        player.play_sound{path='utility/scenario_message'}
        player.print(returnAsString, colour)
    else rcon.print(returnAsString) end
end

--[[-- Formats tick into a clean format, denominations from highest to lowest
-- time will use : separates
-- when a denomination is false it will overflow into the next one
@tparam number ticks the number of ticks that represents a time
@tparam table options table a of options to use for the format
@treturn string a locale string that can be used

@usage-- Output: "0h 5m"
local time = format_time(18000, { hours=true, minutes=true, string=true })

@usage-- Output: "0 hours and 5 minutes"
local time = format_time(18000, { hours=true, minutes=true, string=true, long=true })

@usage-- Output: "00:05:00"
local time = format_time(18000, { hours=true, minutes=true, seconds=true, string=true })

@usage-- Output: "--:--:--"
local time = format_time(18000, { hours=true, minutes=true, seconds=true, string=true, null=true })

]]
function Common.format_time(ticks, options)
    -- Sets up the options
    options = options or {
        days=false,
        hours=true,
        minutes=true,
        seconds=false,
        long=false,
        time=false,
        string=false,
        null=false
    }
    -- Basic numbers that are used in calculations
    local max_days, max_hours, max_minutes, max_seconds = ticks/5184000, ticks/216000, ticks/3600, ticks/60
    local days, hours = max_days, max_hours-math.floor(max_days)*24
    local minutes, seconds = max_minutes-math.floor(max_hours)*60, max_seconds-math.floor(max_minutes)*60
    -- Handles overflow of disabled denominations
    local rtn_days, rtn_hours, rtn_minutes, rtn_seconds = math.floor(days), math.floor(hours), math.floor(minutes), math.floor(seconds)
    if not options.days then
        rtn_hours = rtn_hours + rtn_days*24
    end
    if not options.hours then
        rtn_minutes = rtn_minutes + rtn_hours*60
    end
    if not options.minutes then
        rtn_seconds = rtn_seconds + rtn_minutes*60
    end
    -- Creates the null time format, does not work with long
    if options.null and not options.long then
        rtn_days='--'
        rtn_hours='--'
        rtn_minutes='--'
        rtn_seconds='--'
    end
    -- Format options
    local suffix = 'time-symbol-'
    local suffix_2 = '-short'
    if options.long then
        suffix = ''
        suffix_2 = ''
    end
    local div = options.string and ' ' or 'time-format.simple-format-tagged'
    if options.time then
        div = options.string and ':' or 'time-format.simple-format-div'
        suffix = false
    end
    -- Adds formatting
    if suffix ~= false then
        if options.string then
            -- format it as a string
            local long = suffix == ''
            rtn_days = long and rtn_days..' days' or rtn_days..'d'
            rtn_hours = long and rtn_hours..' hours' or rtn_hours..'h'
            rtn_minutes = long and rtn_minutes..' minutes' or rtn_minutes..'m'
            rtn_seconds = long and rtn_seconds..' seconds' or rtn_seconds..'s'
        else
            rtn_days = {suffix..'days'..suffix_2, rtn_days}
            rtn_hours = {suffix..'hours'..suffix_2, rtn_hours}
            rtn_minutes = {suffix..'minutes'..suffix_2, rtn_minutes}
            rtn_seconds = {suffix..'seconds'..suffix_2, rtn_seconds}
        end
    elseif not options.null then
        -- weather string or not it has same format
        rtn_days = string.format('%02d', rtn_days)
        rtn_hours = string.format('%02d', rtn_hours)
        rtn_minutes = string.format('%02d', rtn_minutes)
        rtn_seconds = string.format('%02d', rtn_seconds)
    end
    -- The final return is construed
    local rtn
    local append = function(dom, value)
        if dom and options.string then
            rtn = rtn and rtn..div..value or value
        elseif dom then
            rtn = rtn and {div, rtn, value} or value
        end
    end
    append(options.days, rtn_days)
    append(options.hours, rtn_hours)
    append(options.minutes, rtn_minutes)
    append(options.seconds, rtn_seconds)
    return rtn
end

--- Factorio.
-- @section factorio

--[[-- Copies items to the position and stores them in the closest entity of the type given
-- Copies the items by prototype name, but keeps them in the original inventory
@tparam table items items which are to be added to the chests, an array of LuaItemStack
@tparam[opt=navies] LuaSurface surface the surface that the items will be copied to
@tparam[opt={0, 0}] table position the position that the items will be copied to {x=100, y=100}
@tparam[opt=32] number radius the radius in which the items are allowed to be placed
@tparam[opt=iron-chest] string chest_type the chest type that the items should be copied into
@treturn LuaEntity the last chest that had items inserted into it

@usage-- Copy all the items in a players inventory and place them in chests at {0, 0}
copy_items_stack(game.player.get_main_inventory().get_contents())

]]
function Common.copy_items_stack(items, surface, position, radius, chest_type)
	chest_type = chest_type or 'iron-chest'
	surface = surface or game.surfaces[1]
	if position and type(position) ~= 'table' then return end
	if type(items) ~= 'table' then return end
	-- Finds all entities of the given type
	local p = position or {x=0, y=0}
	local r = radius or 32
	local entities = surface.find_entities_filtered{area={{p.x-r, p.y-r}, {p.x+r, p.y+r}}, name=chest_type} or {}
	local count = #entities
	local current = 1
	-- Makes a new empty chest when it is needed
	local function make_new_chest()
			local pos = surface.find_non_colliding_position(chest_type, position, 32, 1)
			local chest = surface.create_entity{name=chest_type, position=pos, force='neutral'}
			table.insert(entities, chest)
			count = count + 1
			return chest
	end
	-- Function used to round robin the items into all chests
	local function next_chest(item)
			local chest = entities[current]
			if count == 0 then return make_new_chest() end
			if chest.get_inventory(defines.inventory.chest).can_insert(item) then
					-- If the item can be inserted then the chest is returned
					current = current+1
					if current > count then current = 1 end
					return chest
			else
					-- Other wise it is removed from the list
					table.remove(entities, current)
					count = count - 1
			end
	end
	-- Inserts the items into the chests
	local last_chest
	for i=1,#items do
			local item = items[i]
			if item.valid_for_read then
				local chest = next_chest(item)
				if not chest or not chest.valid then return error(string.format('Cant move item %s to %s{%s, %s} no valid chest in radius', item.name, surface.name, p.x, p.y)) end
				chest.insert(item)
				last_chest = chest
			end
	end
	return last_chest
end

--[[-- Moves items to the position and stores them in the closest entity of the type given
-- Differs from move_items by accepting a table of LuaItemStack and transferring them into the inventory - not copying
@tparam table items items which are to be added to the chests, an array of LuaItemStack
@tparam[opt=navies] LuaSurface surface the surface that the items will be moved to
@tparam[opt={0, 0}] table position the position that the items will be moved to {x=100, y=100}
@tparam[opt=32] number radius the radius in which the items are allowed to be placed
@tparam[opt=iron-chest] string chest_type the chest type that the items should be moved into
@treturn LuaEntity the last chest that had items inserted into it

@usage-- Copy all the items in a players inventory and place them in chests at {0, 0}
move_items_stack(game.player.get_main_inventory())

]]
function Common.move_items_stack(items, surface, position, radius, chest_type)
	chest_type = chest_type or 'steel-chest'
	surface = surface or game.surfaces[1]

	if position and type(position) ~= 'table' then
        return
    end

	if type(items) ~= 'table' then
        return
    end

	-- Finds all entities of the given type
	local p = position or {x=0, y=0}
	local r = radius or 32
	local entities = surface.find_entities_filtered{area={{p.x - r, p.y - r}, {p.x + r, p.y + r}}, name={chest_type, 'iron-chest'}} or {}
	local count = #entities
	local current = 0
    local last_entity = nil

    -- ipairs does not work on LuaInventory
    for i = 1, #items do
        local item = items[i]
        if item.valid_for_read then
            local inserted = false

            -- Attempt to insert the items
            for j = 1, count do
                local entity = entities[((current + j - 1) % count) + 1]

                if entity.can_insert(item) then
                    last_entity = entity
                    current = current + 1
                    entity.insert(item)
                    inserted = true
                    break
                end
            end

            -- If it was not inserted then a new entity is needed
            if not inserted then
                --[[
                if not options.allow_creation then
                    error('Unable to insert items into a valid entity, consider enabling allow_creation')
                end

                if options.name == nil then
                    error('Name must be provided to allow creation of new entities')
                end

                if options.position then
                    pos = surface.find_non_colliding_position(chest_type, p, r, 1, true)

                elseif options.area then
                    pos = surface.find_non_colliding_position_in_box(chest_type, options.area, 1, true)

                else
                    pos = surface.find_non_colliding_position(chest_type, {0,0}, 0, 1, true)
                end
                ]]

                local pos = surface.find_non_colliding_position(chest_type, p, r, 1, true)
                last_entity = surface.create_entity{name=chest_type, position=pos, force='neutral'}

                count = count + 1
                entities[count] = last_entity

                last_entity.insert(item)
            end
        end
    end

    --[[
	-- Makes a new empty chest when it is needed
	local function make_new_chest()
		local pos = surface.find_non_colliding_position(chest_type, position, 32, 1)
		local chest = surface.create_entity{name=chest_type, position=pos, force='neutral'}
		table.insert(entities, chest)
		count = count + 1

		return chest
	end

	-- Function used to round robin the items into all chests
	local function next_chest(item)
		local chest = entities[current]

		if count == 0 then
            return make_new_chest()
        end

		if chest.get_inventory(defines.inventory.chest).can_insert(item) then
			-- If the item can be inserted then the chest is returned
			current = current + 1
			if current > count then
                current = 1
            end

			return chest

		else
			-- Other wise it is removed from the list
			table.remove(entities, current)
		    count = count - 1
		end
	end

	-- Inserts the items into the chests
	local last_chest

	for i=1,#items do
		local item = items[i]

        if item.valid_for_read then
			local chest = next_chest(item)

			if not chest or not chest.valid then
                return error(string.format('Cant move item %s to %s{%s, %s} no valid chest in radius', item.name, surface.name, p.x, p.y))
            end

			local empty_stack = chest.get_inventory(defines.inventory.chest).find_empty_stack(item.name)

            if not empty_stack then
                return error(string.format('Cant move item %s to %s{%s, %s} no valid chest in radius', item.name, surface.name, p.x, p.y))
            end

			empty_stack.transfer_stack(item)
			last_chest = chest
		end
	end
    return last_chest
    ]]

    return last_entity
end

--[[-- Prints a colored value on a location, color is based on the value.
nb: src is below but the gradent has been edited
https://github.com/Refactorio/RedMew/blob/9184b2940f311d8c9c891e83429fc57ec7e0c4a2/map_gen/maps/diggy/debug.lua#L31
@tparam number value the value to show must be between -1 and 1, scale can be used to achive this
@tparam LuaSurface surface the surface to palce the value on
@tparam table position {x, y} the possition to palce the value at
@tparam[opt=1] number scale how much to scale the colours by
@tparam[opt=0] number offset the offset in the +x +y direction
@tparam[opt=false] boolean immutable if immutable, only set, never do a surface lookup, values never change

@usage-- Place a 0 at {0, 0}
print_grid_value(0, game.player.surface, { x=0, y=0 })

]]
function Common.print_grid_value(value, surface, position, scale, offset, immutable)
    local is_string = type(value) == 'string'
    local color = Colours.white
    local text = value

    if type(immutable) ~= 'boolean' then
        immutable = false
    end

    if not is_string then
        scale = scale or 1
        offset = offset or 0
        position = {x = position.x + offset, y = position.y + offset}
        local r = math.clamp(-value/scale, 0, 1)
        local g = math.clamp(1-math.abs(value)/scale, 0, 1)
        local b = math.clamp(value/scale, 0, 1)

        color = { r = r, g = g, b = b}

        -- round at precision of 2
        text = math.floor(100 * value) * 0.01

        if (0 == text) then
            text = '0.00'
        end
    end

    if not immutable then
        local text_entity = surface.find_entity('flying-text', position)

        if text_entity then
            text_entity.text = text
            text_entity.color = color
            return
        end
    end

    surface.create_entity{
        name = 'flying-text',
        color = color,
        text = text,
        position = position
    }.active = false
end

--[[-- Clears all flying text entities on a surface
@tparam LuaSurface surface the surface to clear

@usage-- Remove all flying text on the surface
clear_flying_text(game.player.surface)

]]
function Common.clear_flying_text(surface)
    local entities = surface.find_entities_filtered{name ='flying-text'}
    for _, entity in pairs(entities) do
        if entity and entity.valid then
            entity.destroy()
        end
    end
end

return Common
