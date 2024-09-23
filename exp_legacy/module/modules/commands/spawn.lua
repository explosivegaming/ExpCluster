--[[-- Commands Module - Spawn
    - Adds a command that allows players to teleport to their spawn point
    @commands Spawn
]]

local Commands = require 'expcore.commands' --- @dep expcore.commands
local Roles = require 'expcore.roles' --- @dep expcore.roles

local function teleport(player)
    local surface = player.surface
    local spawn = player.force.get_spawn_position(surface)
    local position = surface.find_non_colliding_position('character', spawn, 32, 1)
    -- return false if no new position
    if not position then
        return false
    end
    if player.vehicle then
        -- Teleport the entity
        local entity = player.vehicle
        local goto_position = surface.find_non_colliding_position(entity.name, position, 32, 1)
        -- Surface teleport can only be done for players and cars at the moment. (with surface as an peramitor it gives this error)
        if entity.type == "car" then
            entity.teleport(goto_position, surface)
        elseif surface.index == entity.surface.index then
            -- Try teleport the entity
            if not entity.teleport(goto_position) then
                player.driving = false
                player.teleport(position, surface)
            end
        end
    else
        -- Teleport the player
        player.teleport(position, surface)
    end

    return true
end

--- Teleport to spawn
-- @command go-to-spawn
-- @tparam[opt=self] LuaPlayer player the player to teleport to their spawn point
Commands.new_command('go-to-spawn', {'expcom-spawn.description'}, 'Teleport to spawn')
:add_param('player', true, 'player-role-alive')
:set_defaults{
    player=function(player)
        if player.connected and player.character and player.character.health > 0 then
            return player
        end
    end
}
:add_alias('spawn', 'tp-spawn')
:register(function(player, action_player)
    if not action_player then
        return Commands.error{'expcom-spawn.unavailable'}

    elseif action_player == player then
        if not teleport(player) then
            return Commands.error{'expcom-spawn.unavailable'}
        end

    elseif Roles.player_allowed(player, 'command/go-to-spawn/always') then
        if not teleport(action_player) then
            return Commands.error{'expcom-spawn.unavailable'}
        end

    else
        return Commands.error{'expcore-commands.unauthorized'}
    end
end)
