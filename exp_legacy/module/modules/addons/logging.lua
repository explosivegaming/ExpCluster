--[[-- Addon Logging
    @addon Logging
]]

local Event = require 'utils.event' --- @dep utils.event
local config = require 'config.logging' --- @dep config.logging
local config_res = require 'config.research' --- @dep config.research

local function add_log(data)
	game.write_file(config.file_name, data, true, 0)
    game.write_file(config.file_name, '\n', true, 0)
end

Event.add(defines.events.on_rocket_launched, function(event)
    if event and event.rocket and event.rocket.force and event.rocket.force.rockets_launched then
        if event.rocket.force.rockets_launched >= config.rocket_launch_display_rate and event.rocket.force.rockets_launched % config.rocket_launch_display_rate == 0 then
            add_log('[ROCKET] ' .. event.rocket.force.rockets_launched .. ' rockets launched')

        elseif config.rocket_launch_display[event.rocket.force.rockets_launched] then
            add_log('[ROCKET] ' .. event.rocket.force.rockets_launched .. ' rockets launched')
        end
    end
end)

Event.add(defines.events.on_pre_player_died, function(event)
    if event and event.player_index then
        if event.cause then
            if event.cause.type and event.cause.type == 'character' and event.cause.player and event.cause.player.index then
                add_log('[DEATH] ' .. game.players[event.player_index].name .. ' died because of ' .. (game.players[event.cause.player.index].name or 'unknown reason'))

            else
                add_log('[DEATH] ' .. game.players[event.player_index].name .. ' died because of ' .. (event.cause.name or 'unknown reason'))
            end

        else
            add_log('[DEATH] ' .. game.players[event.player_index].name .. ' died because of unknown reason')
        end
    end
end)

Event.add(defines.events.on_research_finished, function(event)
    if event and event.research then
        if event.by_script then
            return
        end

        if (event.research.level and config_res.inf_res[event.research.name]) and (event.research.level >= config_res.inf_res[event.research.name]) then
            add_log({'logging.add-l', event.research.prototype.localised_name, event.research.level - 1})

        else
            add_log({'logging.add-n', event.research.prototype.localised_name})
        end
    end
end)

Event.add(defines.events.on_player_joined_game, function(event)
    if event and event.player_index then
        add_log('[JOIN] ' .. game.players[event.player_index].name .. ' joined the game')
    end
end)

Event.add(defines.events.on_player_left_game, function(event)
    if event and event.player_index then
        if event.reason then
            add_log('[LEAVE] ' .. game.players[event.player_index].name .. config.disconnect_reason[event.reason])

        else
            add_log('[LEAVE] ' .. game.players[event.player_index].name .. config.disconnect_reason[defines.disconnect_reason.quit])
        end
    end
end)
