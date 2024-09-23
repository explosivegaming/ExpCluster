--- Adds a waterfill
-- @commands Waterfill

local Commands = require 'expcore.commands' --- @dep expcore.commands
require 'config.expcore.command_general_parse'
local Selection = require 'modules.control.selection' --- @dep modules.control.selection
local SelectionConvertArea = 'WaterfillConvertArea'

--- Align an aabb to the grid by expanding it
local function aabb_align_expand(aabb)
    return {
        left_top = {x = math.floor(aabb.left_top.x), y = math.floor(aabb.left_top.y)},
        right_bottom = {x = math.ceil(aabb.right_bottom.x), y = math.ceil(aabb.right_bottom.y)}
    }
end

Commands.new_command('waterfill', {'expcom-waterfill.description'}, 'Change tile to water')
:register(function(player)
    local inv = player.get_main_inventory()

    if (inv.get_item_count('cliff-explosives')) == 0 then
        return player.print{'expcom-waterfill.waterfill-cliff'}
    end

    if Selection.is_selecting(player, SelectionConvertArea) then
        Selection.stop(player)
    else
        Selection.start(player, SelectionConvertArea)
        return Commands.success{'expcom-waterfill.entered-area-selection'}
    end

    return Commands.success
end)

--- When an area is selected to add protection to the area
Selection.on_selection(SelectionConvertArea, function(event)
    local area = aabb_align_expand(event.area)
    local player = game.get_player(event.player_index)

    if not player then
        return
    end

    local entities = player.surface.find_entities_filtered{area=area, name='steel-chest'}

    if #entities == 0 then
        player.print('No steel chest found')
        return
    end

    local tiles_to_make = {}
    local inv = player.get_main_inventory()

    if not inv then
        return
    end

    local clf_exp = inv.get_item_count('cliff-explosives')

    for _, entity in pairs(entities) do
        if clf_exp >= 1 then
            if entity.get_inventory(defines.inventory.chest).is_empty() then
                if (math.floor(player.position.x) ~= math.floor(entity.position.x)) or (math.floor(player.position.y) ~= math.floor(entity.position.y)) then
                    table.insert(tiles_to_make, {name='water-mud', position=entity.position})
                    entity.destroy()
                else
                    player.print{'expcom-waterfill.waterfill-distance'}
                end
            end

            clf_exp = clf_exp - 1
            inv.remove({name='cliff-explosives', count=1})
        else
            break
        end
    end

    event.surface.set_tiles(tiles_to_make)
end)
