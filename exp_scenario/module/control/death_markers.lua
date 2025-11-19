--[[-- Control - Death Markers
Makes markers on the map where places have died and reclaims items if not recovered
]]

local ExpUtil = require("modules/exp_util")
local Storage = require("modules/exp_util/storage")
local config = require("modules.exp_legacy.config.death_logger")

local map_tag_time_format = ExpUtil.format_time_factory{ format = "short", hours = true, minutes = true }

--- @class CorpseData
--- @field player LuaPlayer
--- @field corpse LuaEntity
--- @field tag LuaCustomChartTag?
--- @field created_at number

--- @type table<number, CorpseData>
local character_corpses = {}
Storage.register(character_corpses, function(tbl)
    character_corpses = tbl
end)

--- Creates a new death marker and saves it to the given death
--- @param corpse_data CorpseData
local function create_map_tag(corpse_data)
    local player = corpse_data.player
    local message = player.name .. " died"

    if config.include_time_of_death then
        local time = map_tag_time_format(corpse_data.created_at)
        message = message .. " at " .. time
    end

    corpse_data.tag = player.force.add_chart_tag(corpse_data.corpse.surface, {
        position = corpse_data.corpse.position,
        icon = config.map_icon,
        text = message,
    })
end

--- Checks that all map tags are present and valid, creating any that are missing
local function check_map_tags()
    for _, corpse_data in pairs(character_corpses) do
        if not corpse_data.tag or not corpse_data.tag.valid then
            create_map_tag(corpse_data)
        end
    end
end

-- when a player dies a new death is added to the records and a map marker is made
--- @param event EventData.on_player_died
local function on_player_died(event)
    local player = assert(game.get_player(event.player_index))
    local corpse = player.surface.find_entity("character-corpse", player.physical_position)
    if not corpse or not corpse.valid then return end

    local corpse_data = {
        player = player,
        corpse = corpse,
        created_at = event.tick,
    }

    local registration_number = script.register_on_object_destroyed(corpse)
    character_corpses[registration_number] = corpse_data

    -- Create a map marker
    if config.show_map_markers then
        create_map_tag(corpse_data)
    end

    -- Draw a light attached to the corpse with the player color
    if config.show_light_at_corpse then
        rendering.draw_light{
            sprite = "utility/light_medium",
            surface = player.surface,
            color = player.color,
            force = player.force,
            target = corpse,
        }
    end
end

--- Called to remove stale corpse data
--- @param event EventData.on_object_destroyed
local function on_object_destroyed(event)
    local corpse_data = character_corpses[event.registration_number]
    character_corpses[event.registration_number] = nil
    if not corpse_data then
        return
    end

    local tag = corpse_data.tag
    if tag and config.clean_map_markers then
        tag.destroy()
    end
end

--- Draw lines to the player corpse
--- @param event EventData.on_player_respawned
local function on_player_respawned(event)
    local index = event.player_index
    local player = assert(game.get_player(index))
    for _, corpse_data in pairs(character_corpses) do
        if corpse_data.player.index == index then
            local line_color = player.color
            line_color.a = .3
            rendering.draw_line{
                color = line_color,
                from = player.character,
                to = corpse_data.corpse,
                surface = player.surface,
                players = { index },
                draw_on_ground = true,
                dash_length = 1,
                gap_length = 1,
                width = 2,
            }
        end
    end
end

--- Collect all items from expired character corpses
--- @param event EventData.on_character_corpse_expired
local function on_character_corpse_expired(event)
    local corpse = event.corpse
    local inventory = assert(corpse.get_inventory(defines.inventory.character_corpse))
    ExpUtil.transfer_inventory_to_surface{
        inventory = inventory,
        surface = corpse.surface,
        name = "iron-chest",
        allow_creation = true,
    }
end

local on_nth_tick = {}
if config.show_map_markers then
    on_nth_tick[config.period_check_map_tags] = check_map_tags
end

local e = defines.events
local events = {
    [e.on_player_died] = on_player_died,
    [e.on_object_destroyed] = on_object_destroyed,
}

if config.show_line_to_corpse then
    events[e.on_player_respawned] = on_player_respawned
end

if config.collect_corpses then
    events[e.on_character_corpse_expired] = on_character_corpse_expired
end

return {
    on_nth_tick = on_nth_tick,
    events = events,
}
