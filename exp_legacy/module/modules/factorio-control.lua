local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event
local Storage = require("modules/exp_util/storage")
local config = require("modules.exp_legacy.config.advanced_start") --- @dep config.advanced_start
local use_silo_script = not config.disable_base_game_silo_script

local util = require("util")
local silo_script
if use_silo_script then
    silo_script = require("silo-script")
end

local global = {}
Storage.register(global, function(tbl)
    global = tbl
end)

local created_items = function()
    return
    {
        ["iron-plate"] = 8,
        ["wood"] = 1,
        ["pistol"] = 1,
        ["firearm-magazine"] = 10,
        ["burner-mining-drill"] = 1,
        ["stone-furnace"] = 1,
    }
end

local respawn_items = function()
    return
    {
        ["pistol"] = 1,
        ["firearm-magazine"] = 10,
    }
end

if use_silo_script then
    for k, v in pairs(silo_script.get_events()) do
        Event.add(k, v)
    end
end

Event.add(defines.events.on_player_created, function(event)
    local player = game.players[event.player_index]
    --- @diagnostic disable-next-line param-type-mismatch
    util.insert_safe(player, global.created_items)

    local r = global.chart_distance or 200
    player.force.chart(player.physical_surface, {
        { player.physical_position.x - r, player.physical_position.y - r },
        { player.physical_position.x + r, player.physical_position.y + r }
    })

    if not global.skip_intro then
        if game.is_multiplayer() then
            player.print{ "msg-intro" }
        else
            game.show_message_dialog{ text = { "msg-intro" } }
        end
    end

    if use_silo_script then
        silo_script.on_event(event)
    end
end)

Event.add(defines.events.on_player_respawned, function(event)
    local player = game.players[event.player_index]
    --- @diagnostic disable-next-line param-type-mismatch
    util.insert_safe(player, global.respawn_items)
    if use_silo_script then
        silo_script.on_event(event)
    end
end)

if use_silo_script then
    Event.on_load(function()
        silo_script.on_load()
    end)
end

Event.on_init(function()
    global.created_items = created_items()
    global.respawn_items = respawn_items()
    if use_silo_script then
        silo_script.on_init()
    end
end)

if use_silo_script then
    silo_script.add_remote_interface()
    silo_script.add_commands()
end

remote.add_interface("freeplay",
    {
        get_created_items = function()
            return global.created_items
        end,
        set_created_items = function(map)
            global.created_items = map
        end,
        get_respawn_items = function()
            return global.respawn_items
        end,
        set_respawn_items = function(map)
            global.respawn_items = map
        end,
        set_skip_intro = function(bool)
            global.skip_intro = bool
        end,
        set_chart_distance = function(value)
            global.chart_distance = tonumber(value)
        end,
        set_disable_crashsite = function()
        end,
        get_ship_items = function()
            return {}
        end,
        set_ship_items = function()
            return
        end,
        get_debris_items = function()
            return {}
        end,
        set_debris_items = function()
            return
        end,
    })
