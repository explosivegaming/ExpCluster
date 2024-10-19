--[[-- Command Module - Default data types
The default data types that are available to all commands

Adds parsers for:
    boolean
    string_options - options: array of strings
    string_key - map: table of string keys and any values
    string_max_length - maximum: number
    number
    integer
    number_range - minimum: number, maximum: number
    integer_range - minimum: number, maximum: number
    player
    player_online
    player_alive
    force
    surface
    color
]]

local ExpUtil = require("modules/exp_util")
local Commands = require("modules/exp_commands")
local add, parse = Commands.add_data_type, Commands.parse_input
local valid, invalid = Commands.status.success, Commands.status.invalid_input

--- A boolean value where true is one of: yes, y, true, 1
add("boolean", function(input)
    input = input:lower()
    if input == "yes"
    or input == "y"
    or input == "true"
    or input == "1" then
        return valid(true)
    else
        return valid(false)
    end
end)

--- A string, validation does nothing but it is a requirement
--- @type Commands.InputParser
add("string", function(input)
    return valid(input)
end)

--- A string from a set of options, takes one argument which is an array of options
--- @param options string[] The options which can be selected
--- @return Commands.InputParser
add("string_array", function(options)
    return function(input)
        local option = ExpUtil.auto_complete(options, input)
        if option == nil then
            return invalid{ "exp-commands-parse.string-options", table.concat(options, ", ") }
        else
            return valid(option)
        end
    end
end)

--- A string which is the key of a table, takes one argument which is an map of string keys to values
--- @param map { [string]: any } The options which can be selected
--- @return Commands.InputParser
add("string_key", function(map)
    return function(input)
        local option = ExpUtil.auto_complete(map, input, true)
        if option == nil then
            return invalid{ "exp-commands-parse.string-options", table.concat(table.get_keys(map), ", ") }
        else
            return valid(option)
        end
    end
end)

--- A string with a maximum length, takes one argument which is the maximum length of a string
--- @param maximum number The maximum length of the input
--- @return Commands.InputParser
add("string_max_length", function(maximum)
    return function(input)
        if input:len() > maximum then
            return invalid{ "exp-commands-parse.string-max-length", maximum }
        else
            return valid(input)
        end
    end
end)

--- A number
add("number", function(input)
    local number = tonumber(input)
    if number == nil then
        return invalid{ "exp-commands-parse.number" }
    else
        return valid(number)
    end
end)

--- An integer, number which has been floored
add("integer", function(input)
    local number = tonumber(input)
    if number == nil then
        return invalid{ "exp-commands-parse.number" }
    else
        return valid(math.floor(number))
    end
end)

--- A number in a given inclusive range
--- @param minimum number The minimum of the allowed range, inclusive
--- @param maximum number The maximum of the allowed range, inclusive
--- @return Commands.InputParser
add("number_range", function(minimum, maximum)
    local parser_number = Commands.types.number
    return function(input, player)
        local success, status, result = parse(input, player, parser_number)
        if not success then
            return status, result
        elseif result < minimum or result > maximum then
            return invalid{ "exp-commands-parse.number-range", minimum, maximum }
        else
            return valid(result)
        end
    end
end)

--- An integer in a given inclusive range
--- @param minimum number The minimum of the allowed range, inclusive
--- @param maximum number The maximum of the allowed range, inclusive
--- @return Commands.InputParser
add("integer_range", function(minimum, maximum)
    local parser_integer = Commands.types.integer
    return function(input, player)
        local success, status, result = parse(input, player, parser_integer)
        if not success then
            return status, result
        elseif result < minimum or result > maximum then
            return invalid{ "exp-commands-parse.number-range", minimum, maximum }
        else
            return valid(result)
        end
    end
end)

--- A player who has joined the game at least once
add("player", function(input)
    local player = game.get_player(input)
    if player == nil then
        return invalid{ "exp-commands-parse.player", input }
    else
        return valid(player)
    end
end)

--- A player who is online
add("player_online", function(input, player)
    local success, status, result = parse(input, player, Commands.types.player)
    --- @cast result LuaPlayer
    if not success then
        return status, result
    elseif result.connected == false then
        return invalid{ "exp-commands-parse.player-online" }
    else
        return valid(result)
    end
end)

--- A player who is online and alive
add("player_alive", function(input, player)
    local success, status, result = parse(input, player, Commands.types.player_online)
    --- @cast result LuaPlayer
    if not success then
        return status, result
    elseif result.character == nil or result.character.health <= 0 then
        return invalid{ "exp-commands-parse.player-alive" }
    else
        return valid(result)
    end
end)

--- A force within the game
add("force", function(input)
    local force = game.forces[input]
    if force == nil then
        return invalid{ "exp-commands-parse.force" }
    else
        return valid(force)
    end
end)

--- A surface within the game
add("surface", function(input)
    local surface = game.surfaces[input]
    if surface == nil then
        return invalid{ "exp-commands-parse.surface" }
    else
        return valid(surface)
    end
end)

--- A name of a color from the predefined list, too many colours to use string-key
add("color", function(input)
    local color = ExpUtil.auto_complete(Commands.color, input, true)
    if color == nil then
        return invalid{ "exp-commands-parse.color" }
    else
        return valid(color)
    end
end)
