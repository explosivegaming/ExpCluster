--[[-- Commands - Waterfill
Adds a command that places shallow water
]]

local AABB = require("modules/exp_util/aabb")
local Commands = require("modules/exp_commands")

local Selection = require("modules/exp_util/selection")
local SelectArea = Selection.connect("ExpCommand_Waterfill")

local planet = {
    ["nauvis"] = "water-mud",
    ["gleba"] = "wetland-blue-slime",
    ["vulcanus"] = "lava",
    ["fulgora"] = "oil-ocean-shallow",
    ["aquilo"] = "ammoniacal-ocean"
}

--- @class ExpCommand_Waterfill.commands
local commands = {}

--- Toggle player selection mode for artillery
--- @class ExpCommands_Waterfill.commands.waterfill: ExpCommand
--- @overload fun(player: LuaPlayer)
commands.waterfill = Commands.new("waterfill", { "exp-commands_waterfill.description" })
    :register(function(player)
        if SelectArea:stop(player) then
            return Commands.status.success{ "exp-commands_waterfill.exit" }
        end
        local item_count_cliff = player.get_item_count("cliff-explosives")
        local item_count_craft = math.min(math.floor(player.get_item_count("explosives") / 10), player.get_item_count("barrel"), player.get_item_count("grenade"))
        local item_count_total = item_count_cliff + item_count_craft
        if item_count_total == 0 then
            return Commands.status.error{ "exp-commands_waterfill.requires-explosives" }
        else
            SelectArea:start(player)
            return Commands.status.success{ "exp-commands_waterfill.enter" }
        end
    end) --[[ @as any ]]

--- When an area is selected to be converted to water
SelectArea:on_selection(function(event)
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

    local tile_count = 0
    local failed_tiles = 0
    local tiles_to_make = {}
    local chests = surface.find_entities_filtered{ area = area, name = "steel-chest", force = player.force }
    local tile_to_apply = (surface.planet and planet[surface.planet]) or "water-mud"

    if #chests > 0 then
        for _, chest in pairs(chests) do
            tile_count = tile_count + 1
            if chest.get_inventory(defines.inventory.chest).is_empty() and tile_count <= item_count_total then
                tiles_to_make[tile_count] = { name = tile_to_apply, position = { chest.position.x, chest.position.y } }
                chest.destroy()
            else
                failed_tiles = failed_tiles + 1
            end
        end

    else
        if item_count_total < area_size then
            player.print({ "exp-commands_waterfill.too-few-explosives", area_size, item_count_total }, Commands.print_settings.error)
            return
        end

        for x = area.left_top.x, area.right_bottom.x do
            for y = area.left_top.y, area.right_bottom.y do
                tile_count = tile_count + 1
                tiles_to_make[tile_count] = { name = tile_to_apply, position = { x, y } }
            end
        end

        failed_tiles = surface.count_tiles_filtered{ area = area, name = tile_to_apply }
    end

    surface.set_tiles(tiles_to_make, true, "abort_on_collision", true, false, player, 0)
    local tiles_made = tile_count - failed_tiles
    assert(tiles_made >= 0)

    if item_count_cliff >= tiles_made then
        player.remove_item{ name = "cliff-explosives", count = tiles_made }
    else
        if item_count_cliff > 0 then
            player.remove_item{ name = "cliff-explosives", count = item_count_cliff }
        end
        local item_count_needed = tiles_made - item_count_cliff
        if item_count_needed > 0 then
            player.remove_item{ name = "explosives", count = 10 * item_count_needed }
            player.remove_item{ name = "barrel", count = item_count_needed }
            player.remove_item{ name = "grenade", count = item_count_needed }
        end
    end

    if failed_tiles > 0 then
        player.print({ "exp-commands_waterfill.part-complete", tile_count, failed_tiles }, Commands.print_settings.default)
    else
        player.print({ "exp-commands_waterfill.complete", tile_count }, Commands.print_settings.default)
    end
end)

return {
    commands = commands,
}
