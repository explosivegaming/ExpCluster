--- Adds a better method of player starting items based on production levels.
-- @addon Advanced-Start

local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event
local config = require("modules.exp_legacy.config.advanced_start") --- @dep config.advanced_start
local items = config.items

Event.add(defines.events.on_player_created, function(event)
    local player = game.players[event.player_index]
    -- game init settings
    if event.player_index == 1 then
        player.force.friendly_fire = config.friendly_fire
        game.map_settings.enemy_expansion.enabled = config.enemy_expansion
        local r = config.chart_radius
        local p = player.physical_position
        player.force.chart(player.physical_surface, { { p.x - r, p.y - r }, { p.x + r, p.y + r } })
    end
    -- spawn items
    for item, callback in pairs(items) do
        if type(callback) == "function" then
            local stats = player.force.get_item_production_statistics(player.physical_surface)
            local made = stats.get_input_count(item)
            local success, count = pcall(callback, made, stats.get_input_count, player)
            count = math.floor(count)
            if success and count > 0 then
                player.insert{ name = item, count = count }
            end
        else
            player.insert{ name = item, count = callback }
        end
    end
end)

Event.on_init(function()
    if remote.interfaces["freeplay"] then
        remote.call("freeplay", "set_created_items", {})
        --remote.call("freeplay", "set_respawn_items", {})
        remote.call("freeplay", "set_chart_distance", 0)
        remote.call("freeplay", "set_disable_crashsite", true)
        remote.call("freeplay", "set_skip_intro", config.skip_intro)
    end
    if remote.interfaces["silo_script"] then
        remote.call("silo_script", "set_no_victory", config.skip_victory)
    end
    if remote.interfaces["space_finish_script"] then
        remote.call("space_finish_script", "set_no_victory", config.skip_victory)
    end
end)
