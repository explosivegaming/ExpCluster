--[[-- Command Module - Default data types
The default data types that are available to all commands

@usage Adds parsers for:
    boolean
    string-options - options: array of strings
    string-key - map: table of string keys and any values
    string-max-length - maximum: number
    number
    integer
    number-range - minimum: number, maximum: number
    integer-range - minimum: number, maximum: number
    player
    player-online
    player-alive
    force
    surface
    color
]]

local ExpUtil = require("modules/exp_util")
local Commands = require("modules/exp_commands")
local add, parse = Commands.add_data_type, Commands.parse_data_type
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
add("string", function(input)
    return valid(input)
end)

--- A string from a set of options, takes one argument which is an array of options
add("string-options", function(input, _, options)
    local option = ExpUtil.auto_complete(options, input)
    if option == nil then
        return invalid{ "exp-commands-parse.string-options", table.concat(options, ", ") }
    else
        return valid(option)
    end
end)

--- A string which is the key of a table, takes one argument which is an map of string keys to values
add("string-key", function(input, _, map)
    local option = ExpUtil.auto_complete(map, input, true)
    if option == nil then
        return invalid{ "exp-commands-parse.string-options", table.concat(table.get_keys(map), ", ") }
    else
        return valid(option)
    end
end)

--- A string with a maximum length, takes one argument which is the maximum length of a string
add("string-max-length", function(input, _, maximum)
    if input:len() > maximum then
        return invalid{ "exp-commands-parse.string-max-length", maximum }
    else
        return valid(input)
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
add("number-range", function(input, _, minimum, maximum)
    local success, status, number = parse("number", input)
    if not success then
        return status, number
    elseif number < minimum or number > maximum then
        return invalid{ "exp-commands-parse.number-range", minimum, maximum }
    else
        return valid(number)
    end
end)

--- An integer in a given inclusive range
add("integer-range", function(input, _, minimum, maximum)
    local success, status, number = parse("integer", input)
    if not success then
        return status, number
    elseif number < minimum or number > maximum then
        return invalid{ "exp-commands-parse.number-range", minimum, maximum }
    else
        return valid(number)
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
add("player-online", function(input)
    local success, status, player = parse("player", input)
    if not success then
        return status, player
    elseif player.connected == false then
        return invalid{ "exp-commands-parse.player-online" }
    else
        return valid(player)
    end
end)

--- A player who is online and alive
add("player-alive", function(input)
    local success, status, player = parse("player-online", input)
    if not success then
        return status, player
    elseif player.character == nil or player.character.health <= 0 then
        return invalid{ "exp-commands-parse.player-alive" }
    else
        return valid(player)
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
