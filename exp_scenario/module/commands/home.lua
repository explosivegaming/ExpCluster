--[[-- Commands - Home
Adds a command that allows setting and teleporting to your home position
]]

local ExpUtil = require("modules/exp_util")
local teleport = ExpUtil.teleport_player

local Commands = require("modules/exp_commands")
local Storage = require("modules/exp_util/storage")

--- @type table<number, table<number, [MapPosition?, MapPosition?]>>
local homes = {} -- homes[player_index][surface_index] = { home_pos, return_pos }
Storage.register(homes, function(tbl)
    homes = tbl
end)

--- Align a position to the grid
--- @param position MapPosition The position to align
--- @return MapPosition, MapPosition
local function align_to_grid(position)
    return {
        x = math.floor(position.x) + math.sign(position.x) * 0.5,
        y = math.floor(position.y) + math.sign(position.x) * 0.5,
    }, {
        x = math.floor(position.x),
        y = math.floor(position.y),
    }
end

--- Teleports you to your home location on the current surface
Commands.new("home", { "exp-commands_home.description-home" })
    :add_flags{ "character_only" }
    :register(function(player)
        local surface = player.surface

        local player_homes = homes[player.index]
        if not player_homes then
            return Commands.status.error{ "exp-commands_home.no-home", surface.localised_name }
        end

        local player_home = player_homes[surface.index]
        if not player_home or not player_home[1] then
            return Commands.status.error{ "exp-commands_home.no-home", surface.localised_name }
        end

        local return_position, floor_position = align_to_grid(player.position)
        teleport(player, surface, player_home[1])
        player_home[2] = return_position
        return Commands.status.success{ "exp-commands_home.return-set", surface.localised_name, floor_position.x, floor_position.y }
    end)

--- Teleports you to your previous location on the current surface
Commands.new("return", { "exp-commands_home.description-return" })
    :add_flags{ "character_only" }
    :register(function(player)
        local surface = player.surface

        local player_homes = homes[player.index]
        if not player_homes then
            return Commands.status.error{ "exp-commands_home.no-return", surface.localised_name }
        end

        local player_home = player_homes[surface.index]
        if not player_home or not player_home[2] then
            return Commands.status.error{ "exp-commands_home.no-return", surface.localised_name }
        end

        local return_position, floor_position = align_to_grid(player.position)
        teleport(player, surface, player_home[2])
        player_home[2] = return_position
        return Commands.status.success{ "exp-commands_home.return-set", surface.localised_name, floor_position.x, floor_position.y }
    end)

--- Sets your home location on your current surface to your current position
Commands.new("set-home", { "exp-commands_home.description-set" })
    :add_flags{ "character_only" }
    :register(function(player)
        local home_position, floor_position = align_to_grid(player.position)
        local surface = player.surface

        local player_homes = homes[player.index]
        if not player_homes then
            homes[player.index] = {
                [surface.index] = { home_position, nil }
            }
            return Commands.status.success{ "exp-commands_home.home-set", surface.localised_name, floor_position.x, floor_position.y }
        end

        local player_home = player_homes[surface.index]
        if not player_home then
            player_homes[surface.index] = { home_position, nil }
            return Commands.status.success{ "exp-commands_home.home-set", surface.localised_name, floor_position.x, floor_position.y }
        end

        player_home[1] = home_position
        return Commands.status.success{ "exp-commands_home.home-set", surface.localised_name, floor_position.x, floor_position.y }
    end)

--- Gets your home location on your current surface, is allowed in remote view
Commands.new("get-home", { "exp-commands_home.description-get" })
    :register(function(player)
        local surface = player.surface

        local player_homes = homes[player.index]
        if not player_homes then
            return Commands.status.error{ "exp-commands_home.no-home", surface.localised_name }
        end

        local player_home = player_homes[surface.index]
        if not player_home or not player_home[1] then
            return Commands.status.error{ "exp-commands_home.no-home", surface.localised_name }
        end

        local _, floor_position = align_to_grid(player_home[1])
        return Commands.status.success{ "exp-commands_home.home-get", surface.localised_name, floor_position.x, floor_position.y }
    end)
