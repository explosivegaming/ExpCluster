
--[[-- Command Types - Roles
The data types that are used with exp_roles
A lower role index indicates it is more privileged

Adds parsers for:
    role
    lower_role
    lower_role_player
    lower_role_player_online
    lower_role_player_alive
]]

local Commands = require("modules/exp_commands")
local add, parse = Commands.add_data_type, Commands.parse_input
local valid, invalid = Commands.status.success, Commands.status.invalid_input

local Roles = require("modules.exp_legacy.expcore.roles")
local highest_role = Roles.get_player_highest_role

local types = {} --- @class Commands.types

--- A role defined by exp roles
types.role = add("role", Commands.types.key_of(Roles.config.roles))

--- A role which is lower than the players highest role
types.lower_role =
    add("lower_role", function(input, player)
        local success, status, result = parse(input, player, types.role)
        if not success then return status, result end
        --- @cast result any TODO role is not a defined type

        local player_highest = highest_role(player)
        if player_highest.index >= result.index then
            return invalid{ "exp-commands-parse_role.lower-role" }
        else
            return valid(result)
        end
    end)

--- A player who is of a lower role than the executing player
types.lower_role_player =
    add("lower_role_player", function(input, player)
        local success, status, result = parse(input, player, Commands.types.player)
        if not success then return status, result end
        --- @cast result LuaPlayer

        local other_highest = highest_role(result)
        local player_highest = highest_role(player)
        if player_highest.index >= other_highest.index then
            return invalid{ "exp-commands-parse_role.lower-role-player" }
        else
            return valid(result)
        end
    end)

--- A player who is of a lower role than the executing player
types.lower_role_player_online =
    add("lower_role_player_online", function(input, player)
        local success, status, result = parse(input, player, Commands.types.player_online)
        if not success then return status, result end
        --- @cast result LuaPlayer

        local other_highest = highest_role(result)
        local player_highest = highest_role(player)
        if player_highest.index >= other_highest.index then
            return invalid{ "exp-commands-parse_role.lower-role-player" }
        else
            return valid(result)
        end
    end)

--- A player who is of a lower role than the executing player
types.lower_role_player_alive =
    add("lower_role_player_alive", function(input, player)
        local success, status, result = parse(input, player, Commands.types.player_alive)
        if not success then return status, result end
        --- @cast result LuaPlayer

        local other_highest = highest_role(result)
        local player_highest = highest_role(player)
        if player_highest.index >= other_highest.index then
            return invalid{ "exp-commands-parse_role.lower-role-player" }
        else
            return valid(result)
        end
    end)

return types
