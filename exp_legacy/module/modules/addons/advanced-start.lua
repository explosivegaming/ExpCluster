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
        local p = player.position
        player.force.chart(player.surface, {{p.x-r, p.y-r}, {p.x+r, p.y+r}})
    end
    -- spawn items
    for item, callback in pairs(items) do
        if type(callback) == 'function' then
            local stats = player.force.item_production_statistics
            local made = stats.get_input_count(item)
            local success, count = pcall(callback, made, stats.get_input_count, player)
            count = math.floor(count)
            if success and count > 0 then
                player.insert{name=item, count=count}
            end
        end
    end

    if config.armor.enable then
        player.insert{name=config.armor.main, count=1}

        for _, item in pairs(config.armor.item) do
            player.insert{name=item.equipment, count=item.count}
        end
    end
end)

Event.on_init(function()
    remote.call('freeplay', 'set_created_items', {})
    remote.call('freeplay', 'set_chart_distance', 0)
    remote.call('freeplay', 'set_skip_intro', config.skip_intro)
    if config.research_queue_from_start then
        for _, force in pairs(game.forces) do
            --force.research_queue_enabled = true
        end
    end
    if not config.disable_base_game_silo_script then
        if config.skip_victory then
            remote.call('silo_script', 'set_no_victory', true)
        end
    end
end)