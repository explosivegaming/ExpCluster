--[[-- This file contains some common command param parse functions;
this file is less of a config and more of a requirement but you may wish to change how some behave;
as such you need to be confident with lua but you edit this config file;
use Commands.add_parse('name',function(input, player, reject) end) to add a parse;
see ./expcore/commands.lua for more details
@config Commands-Parse
@usage Adds Parses:
    boolean
    string-options - options: array
    string-max-length - max_length: number
    number
    integer
    number-range - range_min: number, range_max: number
    integer-range - range_min: number, range_max: number
    player
    player-online
    player-alive
    force
    surface
]]

local Commands = require 'expcore.commands' --- @dep expcore.commands

-- luacheck:ignore 212/player
Commands.add_parse('boolean',function(input, player)
    if not input then return end -- nil check
    input = input:lower()
    if input == 'yes'
    or input == 'y'
    or input == 'true'
    or input == '1' then
        return true
    else
        return false
    end
end)

Commands.add_parse('string-options',function(input, player, reject, options)
    if not input then return end -- nil check
    local option = _C.auto_complete(options, input)
    return option or reject{'expcore-commands.reject-string-options', table.concat(options, ', ')}
end)

Commands.add_parse('string-max-length',function(input, player, reject, max_length)
    if not input then return end -- nil check
    local length = input:len()
    if length > max_length then
        return reject{'expcore-commands.reject-string-max-length',max_length}
    else
        return input
    end
end)

Commands.add_parse('number',function(input, player, reject)
    if not input then return end -- nil check
    local number = tonumber(input)
    if not number then
        return reject{'expcore-commands.reject-number'}
    else
        return number
    end
end)

Commands.add_parse('integer',function(input, player, reject)
    if not input then return end -- nil check
    local number = tonumber(input)
    if not number then
        return reject{'expcore-commands.reject-number'}
    else
        return math.floor(number)
    end
end)

Commands.add_parse('number-range',function(input, player, reject, range_min, range_max)
    local number = Commands.parse('number',input, player, reject)
    if not number then return end -- nil check
    if number < range_min or number > range_max then
        return reject{'expcore-commands.reject-number-range',range_min, range_max}
    else
        return number
    end
end)

Commands.add_parse('integer-range',function(input, player, reject, range_min, range_max)
    local number = Commands.parse('integer',input, player, reject)
    if not number then return end -- nil check
    if number < range_min or number > range_max then
        return reject{'expcore-commands.reject-number-range',range_min, range_max}
    else
        return number
    end
end)

Commands.add_parse('player',function(input, player, reject)
    if not input then return end -- nil check
    local input_player = game.players[input]
    if not input_player then
        return reject{'expcore-commands.reject-player',input}
    else
        return input_player
    end
end)

Commands.add_parse('player-online',function(input, player, reject)
    local input_player = Commands.parse('player',input, player, reject)
    if not input_player then return end -- nil check
    if not input_player.connected then
        return reject{'expcore-commands.reject-player-online'}
    else
        return input_player
    end
end)

Commands.add_parse('player-alive',function(input, player, reject)
    local input_player = Commands.parse('player-online',input, player, reject)
    if not input_player then return end -- nil check
    if not input_player.character or not input_player.character.health or input_player.character.health <= 0 then
        return reject{'expcore-commands.reject-player-alive'}
    else
        return input_player
    end
end)

Commands.add_parse('force',function(input, player, reject)
    if not input then return end -- nil check
    local force = game.forces[input]
    if not force then
        return reject{'expcore-commands.reject-force'}
    else
        return force
    end
end)

Commands.add_parse('surface',function(input, player, reject)
    if not input then return end
    local surface = game.surfaces[input]
    if not surface then
        return reject{'expcore-commands.reject-surface'}
    else
        return surface
    end
end)