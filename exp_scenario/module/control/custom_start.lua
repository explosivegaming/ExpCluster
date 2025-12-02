--[[-- Control - Custom Start
Changes the starting script and the items given on first join depending on factory production levels
]]

local config = require("modules.exp_legacy.config.advanced_start")
local floor = math.floor

--- Give a player their starting items
--- @param player LuaPlayer
local function give_starting_items(player)
    local get_prod_stats = player.force.get_item_production_statistics(player.physical_surface)
    local get_input_count = get_prod_stats.get_input_count
    local insert_param = { name = "", count = 0 }
    local insert = player.insert
    for item_name, insert_amount in pairs(config.items) do
        insert_param.name = item_name
        if type(insert_amount) == "function" then
            local count = insert_amount(get_input_count(item_name), get_input_count, player)
            if count >= 1 then
                insert_param.count = floor(count)
                insert(insert_param)
            end
        elseif insert_amount >= 1 then
            insert_param.count = floor(insert_amount)
            insert(insert_param)
        end
    end
end

--- Calls remote interfaces to configure the base game scenarios
local function on_init()
    game.forces.player.friendly_fire = config.friendly_fire
    game.map_settings.enemy_expansion.enabled = config.enemy_expansion
    if remote.interfaces["freeplay"] then
        remote.call("freeplay", "set_created_items", {})
        remote.call("freeplay", "set_disable_crashsite", config.disable_crashsite)
        remote.call("freeplay", "set_skip_intro", config.skip_intro)
        remote.call("freeplay", "set_chart_distance", config.chart_radius)
    end
    if remote.interfaces["silo_script"] then
        remote.call("silo_script", "set_no_victory", config.skip_victory)
    end
    if remote.interfaces["space_finish_script"] then
        remote.call("space_finish_script", "set_no_victory", config.skip_victory)
    end
end

--- Give a player starting items when they first join
--- @param event EventData.on_player_created
local function on_player_created(event)
    -- We can't trust on_init to work for clusterio
    if event.player_index == 1 then on_init() end
    give_starting_items(assert(game.get_player(event.player_index)))
end

local e = defines.events

return {
    on_init = on_init,
    events = {
        [e.on_player_created] = on_player_created,
    },
    give_starting_items = give_starting_items,
}
