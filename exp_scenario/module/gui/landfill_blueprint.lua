--[[-- Gui - Landfill Blueprint
Adds a button to the toolbar which adds landfill to the held blueprint
]]

local Gui = require("modules/exp_gui")
local Roles = require("modules/exp_legacy/expcore/roles")

--- @param box BoundingBox
local function rotate_bounding_box(box)
    box.left_top.x, box.left_top.y, box.right_bottom.x, box.right_bottom.y
    = -box.right_bottom.y, box.left_top.x, -box.left_top.y, box.right_bottom.x
end

local function curve_flip_lr(oc)
    local nc = table.deep_copy(oc)

    for r = 1, 8 do
        for c = 1, 8 do
            nc[r][c] = oc[r][9 - c]
        end
    end

    return nc
end

local function curve_flip_d(oc)
    local nc = table.deep_copy(oc)

    for r = 1, 8 do
        for c = 1, 8 do
            nc[r][c] = oc[c][r]
        end
    end

    return nc
end

local curve_masks = {} do
    local curves = { {
        { 0, 0, 0, 0, 0, 1, 0, 0 },
        { 0, 0, 0, 0, 1, 1, 1, 0 },
        { 0, 0, 0, 1, 1, 1, 1, 0 },
        { 0, 0, 0, 1, 1, 1, 0, 0 },
        { 0, 0, 1, 1, 1, 0, 0, 0 },
        { 0, 0, 1, 1, 1, 0, 0, 0 },
        { 0, 0, 1, 1, 0, 0, 0, 0 },
        { 0, 0, 1, 1, 0, 0, 0, 0 },
    } }

    curves[6] = curve_flip_d(curves[1])
    curves[3] = curve_flip_lr(curves[6])
    curves[4] = curve_flip_d(curves[3])
    curves[5] = curve_flip_lr(curves[4])
    curves[2] = curve_flip_d(curves[5])
    curves[7] = curve_flip_lr(curves[2])
    curves[8] = curve_flip_d(curves[7])

    for i, map in ipairs(curves) do
        local index = 0
        local mask = {}
        curve_masks[i] = mask

        for row = 1, 8 do
            for col = 1, 8 do
                if map[row][col] == 1 then
                    index = index + 1
                    mask[index] = {
                        x = col - 5,
                        y = row - 5,
                    }
                end
            end
        end
    end
end

local rolling_stocks = {}
for name, _ in pairs(prototypes.get_entity_filtered{ { filter = "rolling-stock" } }) do
    rolling_stocks[name] = true
end

--- @param blueprint LuaItemStack
--- @return table
local function landfill_gui_add_landfill(blueprint)
    local entities = assert(blueprint.get_blueprint_entities())
    local tile_index = 0
    local new_tiles = {}

    for _, entity in pairs(entities) do
        if rolling_stocks[entity.name] or entity.name == "offshore-pump" then
            goto continue
        end

        if entity.name == "curved-rail" then
            -- Curved rail
            local curve_mask = curve_masks[entity.direction or 8]
            for _, offset in ipairs(curve_mask) do
                tile_index = tile_index + 1
                new_tiles[tile_index] = {
                    name = "landfill",
                    position = { entity.position.x + offset.x, entity.position.y + offset.y },
                }
            end
        else
            -- Any other entity
            local proto = prototypes.entity[entity.name]
            if proto.collision_mask["ground-tile"] ~= nil then
                goto continue
            end

            -- Rotate the collision box to be north facing
            local box = proto.collision_box or proto.selection_box
            if entity.direction then
                if entity.direction ~= defines.direction.north then
                    rotate_bounding_box(box)
                    if entity.direction ~= defines.direction.east then
                        rotate_bounding_box(box)
                        if entity.direction ~= defines.direction.south then
                            rotate_bounding_box(box)
                        end
                    end
                end
            end

            -- Add the landfill
            for y = math.floor(entity.position.y + box.left_top.y), math.floor(entity.position.y + box.right_bottom.y), 1 do
                for x = math.floor(entity.position.x + box.left_top.x), math.floor(entity.position.x + box.right_bottom.x), 1 do
                    tile_index = tile_index + 1
                    new_tiles[tile_index] = {
                        name = "landfill",
                        position = { x, y },
                    }
                end
            end
        end

        ::continue::
    end

    local old_tiles = blueprint.get_blueprint_tiles()

    if old_tiles then
        for _, old_tile in pairs(old_tiles) do
            tile_index = tile_index + 1
            new_tiles[tile_index] = {
                name = "landfill",
                position = old_tile.position,
            }
        end
    end

    return { tiles = new_tiles }
end

--- Add the toolbar button
Gui.toolbar.create_button{
    name = "trigger_landfill_blueprint",
    sprite = "item/landfill",
    tooltip = { "exp-gui_landfill-blueprint.tooltip-main" },
    visible = function(player, element)
        return Roles.player_allowed(player, "gui/landfill")
    end
}:on_click(function(def, player, element)
    local stack = player.cursor_stack
    if stack and stack.valid_for_read and stack.type == "blueprint" and stack.is_blueprint_setup() then
        local modified = landfill_gui_add_landfill(stack)
        if modified and next(modified.tiles) then
            stack.set_blueprint_tiles(modified.tiles)
        end
    else
        player.print{ "exp-gui_landfill-blueprint.error-no-blueprint" }
    end
end)

return {}
