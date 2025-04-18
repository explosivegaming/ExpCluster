--[[-- Commands - Waterfill
Adds a command that places shallow water
]]

local AABB = require("modules/exp_util/aabb")
local Commands = require("modules/exp_commands")
local Selection = require("modules.exp_legacy.modules.control.selection") --- @dep modules.control.selection
local SelectionName = "ExpCommand_Waterfill"

local planet = {
    ["nauvis"] = "water-mud",
    ["gleba"] = "water-mud",
    ["vulcanus"] = "lava",
    ["fulgora"] = "oil-ocean-shallow",
    ["aquilo"] = "ammoniacal-ocean"
}

--- Toggle player selection mode for artillery
Commands.new("waterfill", { "exp-commands_waterfill.description" })
    :register(function(player)
        if Selection.is_selecting(player, SelectionName) then
            Selection.stop(player)
            return Commands.status.success{ "exp-commands_waterfill.exit" }
        else
            local item_count_cliff = player.get_item_count("cliff-explosives")
            local item_count_craft = math.min(math.floor(player.get_item_count("explosives") / 10), player.get_item_count("barrel"), player.get_item_count("grenade"))
            local item_count_total = item_count_cliff + item_count_craft
            if item_count_total == 0 then
                return player.print{ "exp-commands_waterfill.requires-explosives" }
            else
                Selection.start(player, SelectionName)
                return player.print{ "exp-commands_waterfill.enter" }
            end
        end
    end)

--- When an area is selected to be converted to water
Selection.on_selection(SelectionName, function(event)
    --- @cast event EventData.on_player_selected_area
    local area = AABB.expand(event.area)
    local player = game.players[event.player_index]
    local surface = event.surface

    --[[
    if surface.planet and surface.planet ~= game.planets.nauvis then
        player.print({ "exp-commands_waterfill.nauvis-only" }, Commands.print_settings.error)
        return
    end
    ]]

    local area_size = (area.right_bottom.x - area.left_top.x) * (area.right_bottom.y - area.left_top.y)

    if area_size > 1000 then
        player.print({ "exp-commands_waterfill.area-too-large", 1000, area_size }, Commands.print_settings.error)
        return
    end

    local item_count_cliff = player.get_item_count("cliff-explosives")
    local item_count_craft = math.min(math.floor(player.get_item_count("explosives") / 10), player.get_item_count("barrel"), player.get_item_count("grenade"))
    local item_count_total = item_count_cliff + item_count_craft

    if item_count_total < area_size then
        player.print({ "exp-commands_waterfill.too-few-explosives", area_size, item_count_total }, Commands.print_settings.error)
        return
    end

    local tile_count = 0
    local tiles_to_make = {}
    local chest = surface.find_entities_filtered{ area = area, name = "steel-chest", force = player.force }
    local tile_to_apply = (surface.planet and planet[surface.planet]) or "water-mud"

    if #chest > 0 then
        for _, v in pairs(chest) do
            if v.get_inventory(defines.inventory.chest).is_empty() then
                tile_count = tile_count + 1
                tiles_to_make[tile_count] = {
                    name = tile_to_apply,
                    position = { math.floor(v.position.x), math.floor(v.position.y) },
                }
                v.destroy()
            end
        end

    else
        for x = area.left_top.x, area.right_bottom.x do
            for y = area.left_top.y, area.right_bottom.y do
                tile_count = tile_count + 1
                tiles_to_make[tile_count] = {
                    name = tile_to_apply,
                    position = { x, y },
                }
            end
        end
    end

    surface.set_tiles(tiles_to_make, true, "abort_on_collision", true, false, player, 0)
    local remaining_tiles = surface.count_tiles_filtered{ area = area, name = tile_to_apply }
    local t_diff = tile_count - remaining_tiles

    if item_count_cliff >= t_diff then
        player.remove_item{ name = "cliff-explosives", count = t_diff }
    else
        if item_count_cliff > 0 then
            player.remove_item{ name = "cliff-explosives", count = item_count_cliff }
        end
        local item_count_needed = t_diff - item_count_cliff
        if item_count_needed > 0 then
            player.remove_item{ name = "explosives", count = 10 * item_count_needed }
            player.remove_item{ name = "barrel", count = item_count_needed }
            player.remove_item{ name = "grenade", count = item_count_needed }
        end
    end

    if remaining_tiles > 0 then
        player.print({ "exp-commands_waterfill.part-complete", tile_count, remaining_tiles }, Commands.print_settings.default)
    else
        player.print({ "exp-commands_waterfill.complete", tile_count }, Commands.print_settings.default)
    end
end)
