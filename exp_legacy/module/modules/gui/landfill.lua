--[[-- Gui Module - Landfill
    - Landfill blueprint
    @gui Landfill
    @alias landfill_container
]]

local Gui = require("modules/exp_gui")
local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event
local Roles = require("modules.exp_legacy.expcore.roles") --- @dep expcore.roles

local rolling_stocks = {}

local function landfill_init()
    for name, _ in pairs(prototypes.get_entity_filtered{ { filter = "rolling-stock" } }) do
        rolling_stocks[name] = true
    end
end

local function rotate_bounding_box(box)
    return {
        left_top = {
            x = -box.right_bottom.y,
            y = box.left_top.x,
        },
        right_bottom = {
            x = -box.left_top.y,
            y = box.right_bottom.x,
        },
    }
end

local function curve_flip_lr(oc)
    local nc = table.deepcopy(oc)

    for r = 1, 8 do
        for c = 1, 8 do
            nc[r][c] = oc[r][9 - c]
        end
    end

    return nc
end

local function curve_flip_d(oc)
    local nc = table.deepcopy(oc)

    for r = 1, 8 do
        for c = 1, 8 do
            nc[r][c] = oc[c][r]
        end
    end

    return nc
end

local curves = {}

curves[1] = {
    { 0, 0, 0, 0, 0, 1, 0, 0 },
    { 0, 0, 0, 0, 1, 1, 1, 0 },
    { 0, 0, 0, 1, 1, 1, 1, 0 },
    { 0, 0, 0, 1, 1, 1, 0, 0 },
    { 0, 0, 1, 1, 1, 0, 0, 0 },
    { 0, 0, 1, 1, 1, 0, 0, 0 },
    { 0, 0, 1, 1, 0, 0, 0, 0 },
    { 0, 0, 1, 1, 0, 0, 0, 0 },
}
curves[6] = curve_flip_d(curves[1])
curves[3] = curve_flip_lr(curves[6])
curves[4] = curve_flip_d(curves[3])
curves[5] = curve_flip_lr(curves[4])
curves[2] = curve_flip_d(curves[5])
curves[7] = curve_flip_lr(curves[2])
curves[8] = curve_flip_d(curves[7])

local curve_n = {}

for i, map in ipairs(curves) do
    curve_n[i] = {}
    local index = 1

    for r = 1, 8 do
        for c = 1, 8 do
            if map[r][c] == 1 then
                curve_n[i][index] = {
                    ["x"] = c - 5,
                    ["y"] = r - 5,
                }

                index = index + 1
            end
        end
    end
end

--- @param blueprint LuaItemStack
--- @return table
local function landfill_gui_add_landfill(blueprint)
    local entities = assert(blueprint.get_blueprint_entities())
    local tile_index = 0
    local new_tiles = {}

    for _, ent in pairs(entities) do
        -- vehicle
        if not (rolling_stocks[ent.name] or ent.name == "offshore-pump") then
            -- curved rail, special
            if ent.name ~= "curved-rail" then
                local proto = prototypes.entity[ent.name]
                local box = proto.collision_box or proto.selection_box

                if proto.collision_mask["ground-tile"] == nil then
                    if ent.direction then
                        if ent.direction ~= defines.direction.north then
                            box = rotate_bounding_box(box)

                            if ent.direction ~= defines.direction.east then
                                box = rotate_bounding_box(box)

                                if ent.direction ~= defines.direction.south then
                                    box = rotate_bounding_box(box)
                                end
                            end
                        end
                    end

                    for y = math.floor(ent.position.y + box.left_top.y), math.floor(ent.position.y + box.right_bottom.y), 1 do
                        for x = math.floor(ent.position.x + box.left_top.x), math.floor(ent.position.x + box.right_bottom.x), 1 do
                            tile_index = tile_index + 1
                            new_tiles[tile_index] = {
                                name = "landfill",
                                position = { x, y },
                            }
                        end
                    end
                end

                -- curved rail
            else
                local curve_mask = curve_n[ent.direction or 8]

                for m = 1, #curve_mask do
                    new_tiles[tile_index + 1] = {
                        name = "landfill",
                        position = { curve_mask[m].x + ent.position.x, curve_mask[m].y + ent.position.y },
                    }

                    tile_index = tile_index + 1
                end
            end
        end
    end

    local old_tiles = blueprint.get_blueprint_tiles()

    if old_tiles then
        for _, old_tile in pairs(old_tiles) do
            new_tiles[tile_index + 1] = {
                name = "landfill",
                position = { old_tile.position.x, old_tile.position.y },
            }

            tile_index = tile_index + 1
        end
    end

    return { tiles = new_tiles }
end

--- Add the toolbar button
Gui.toolbar.create_button{
    name = "landfill",
    sprite = "item/landfill",
    tooltip = { "landfill.main-tooltip" },
    visible = function(player, element)
        return Roles.player_allowed(player, "gui/landfill")
    end
}:on_click(function(def, player, element)
    if player.cursor_stack and player.cursor_stack.valid_for_read then
        if player.cursor_stack.type == "blueprint" and player.cursor_stack.is_blueprint_setup() then
            local modified = landfill_gui_add_landfill(player.cursor_stack)

            if modified and next(modified.tiles) then
                player.cursor_stack.set_blueprint_tiles(modified.tiles)
            end
        end
    else
        player.print{ "landfill.cursor-none" }
    end
end)

Event.add(defines.events.on_player_joined_game, landfill_init)
