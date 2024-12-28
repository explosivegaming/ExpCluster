--[[-- Commands - Waterfill
Adds a command that places shallow water
]]

local AABB = require("modules/exp_util/aabb")
local Commands = require("modules/exp_commands")
local Selection = require("modules.exp_legacy.modules.control.selection") --- @dep modules.control.selection
local SelectionName = "ExpCommand_Waterfill"

--- Toggle player selection mode for artillery
Commands.new("waterfill", { "exp-commands_waterfill.description" })
    :register(function(player)
        if Selection.is_selecting(player, SelectionName) then
            Selection.stop(player)
            return Commands.status.success{ "exp-commands_waterfill.exit" }
        elseif player.get_item_count("cliff-explosives") == 0 then
            return Commands.status.error{ "exp-commands_waterfill.requires-explosives" }
        else
            Selection.start(player, SelectionName)
            return Commands.status.success{ "exp-commands_waterfill.enter" }
        end
    end)

--- When an area is selected to be converted to water
Selection.on_selection(SelectionName, function(event)
    --- @cast event EventData.on_player_selected_area
    local area = AABB.expand(event.area)
    local player = game.players[event.player_index]
    local surface = event.surface

    if surface.planet and surface.planet ~= game.planets.nauvis then
        player.print({ "exp-commands_waterfill.nauvis-only" }, Commands.print_settings.error)
        return
    end

    local area_size = (area.right_bottom.x - area.left_top.x) * (area.right_bottom.y - area.left_top.y)
    if area_size > 1000 then
        player.print({ "exp-commands_waterfill.area-too-large", 1000, area_size }, Commands.print_settings.error)
        return
    end

    local item_count = player.get_item_count("cliff-explosives")
    if item_count < area_size then
        player.print({ "exp-commands_waterfill.too-few-explosives", area_size, item_count }, Commands.print_settings.error)
        return
    end

    local tile_count = 0
    local tiles_to_make = {}
    for x = area.left_top.x, area.right_bottom.x do
        for y = area.left_top.y, area.right_bottom.y do
            tile_count = tile_count + 1
            tiles_to_make[tile_count] = {
                name = "water-mud",
                position = { x, y },
            }
        end
    end

    surface.set_tiles(tiles_to_make, true, "abort_on_collision", true, false, player, 0)
    local remaining_tiles = surface.count_tiles_filtered{ area = area, name = "water-mud" }
    player.remove_item{ name = "cliff-explosives", count = tile_count - remaining_tiles }

    if remaining_tiles > 0 then
        player.print({ "exp-commands_waterfill.part-complete", tile_count, remaining_tiles }, Commands.print_settings.default)
    else
        player.print({ "exp-commands_waterfill.complete", tile_count }, Commands.print_settings.default)
    end
end)
