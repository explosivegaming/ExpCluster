--[[-- Commands Module - Home
    - Adds a command that allows setting and teleporting to your home position
    @commands Home
]]

local Commands = require 'expcore.commands' --- @dep expcore.commands
local Global = require 'utils.global' --- @dep utils.global
require 'config.expcore.command_general_parse'

local homes = {}
Global.register(homes, function(tbl)
    homes = tbl
end)

local function teleport(player, position)
    local surface = player.surface
    local pos = surface.find_non_colliding_position('character', position, 32, 1)
    if not position then return false end
    if player.driving then player.driving = false end -- kicks a player out a vehicle if in one
    player.teleport(pos, surface)
    return true
end

local function floor_pos(position)
    return {
        x=math.floor(position.x),
        y=math.floor(position.y)
    }
end

--- Teleports you to your home location
-- @command home
Commands.new_command('home', {'expcom-home.description-home'}, 'Teleports you to your home location')
:register(function(player)
    local home = homes[player.index]
    if not home or not home[1] then
        return Commands.error{'expcom-home.no-home'}
    end
    local rtn = floor_pos(player.position)
    teleport(player, home[1])
    home[2] = rtn
    Commands.print{'expcom-home.return-set', rtn.x, rtn.y}
end)

--- Sets your home location to your current position
-- @command home-set
Commands.new_command('home-set', {'expcom-home.description-home-set'}, 'Sets your home location to your current position')
:register(function(player)
    local home = homes[player.index]
    if not home then
        home = {}
        homes[player.index] = home
    end
    local pos = floor_pos(player.position)
    home[1] = pos
    Commands.print{'expcom-home.home-set', pos.x, pos.y}
end)

--- Returns your current home location
-- @command home-get
Commands.new_command('home-get', {'expcom-home.description-home-get'}, 'Returns your current home location')
:register(function(player)
    local home = homes[player.index]
    if not home or not home[1] then
        return Commands.error{'expcom-home.no-home'}
    end
    local pos = home[1]
    Commands.print{'expcom-home.home-get', pos.x, pos.y}
end)

--- Teleports you to previous location
-- @command return
Commands.new_command('return', {'expcom-home.description-return'}, 'Teleports you to previous location')
:register(function(player)
    local home = homes[player.index]
    if not home or not home[2] then
        return Commands.error{'expcom-home.no-return'}
    end
    local rtn = floor_pos(player.position)
    teleport(player, home[2])
    home[2] = rtn
    Commands.print{'expcom-home.return-set', rtn.x, rtn.y}
end)
