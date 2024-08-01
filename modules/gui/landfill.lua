--[[-- Gui Module - Landfill
    - Landfill blueprint
    @gui Landfill
    @alias landfill_container
]]

local Gui = require 'expcore.gui' --- @dep expcore.gui
local Roles = require 'expcore.roles' --- @dep expcore.roles
local config = require 'config.landfill' --- @dep config.landfill

local landfill_container

local landfill_tile = 'landfill'
local rolling_stocks = {}

for name, _ in pairs(game.get_filtered_entity_prototypes({{filter = 'rolling-stock'}})) do
    rolling_stocks[name] = true
end

local function rotate_bounding_box(box)
    return {
        left_top = {
            x = -box.right_bottom.y,
            y = box.left_top.x
        },
        right_bottom = {
            x = -box.left_top.y,
            y = box.right_bottom.x
        }
    }
end

local function curve_flip_lr(oc)
	local nc = table.deepcopy(oc)

	for r=1, 8 do
		for c=1, 8 do
			nc[r][c] = oc[r][9 - c]
		end
	end

	return nc
end

local function curve_flip_d(oc)
	local nc = table.deepcopy(oc)

	for r=1, 8 do
		for c=1, 8 do
			nc[r][c] = oc[c][r]
		end
	end

	return nc
end

local curves = {}
curves[1] = config.default_curve
curves[6] = curve_flip_d(curves[1])
curves[3] = curve_flip_lr(curves[6])
curves[4] = curve_flip_d(curves[3])
curves[5] = curve_flip_lr(curves[4])
curves[2] = curve_flip_d(curves[5])
curves[7] = curve_flip_lr(curves[2])
curves[8] = curve_flip_d(curves[7])

local function curve_map(d)
	local n = {}
	local map = table.deepcopy(curves[d])
	local index = 1

	for r=1, 8 do
		for c=1, 8 do
			if map[r][c] == 1 then
				n[index] = {
                    ['x'] = c - 5,
                    ['y'] = r - 5
                }
				index = index + 1
			end
		end
	end

	return n
end

local function landfill_gui_add_landfill(blueprint)
    local entities = blueprint.get_blueprint_entities()


    local tile_index = 0
    local new_tiles = {}

    for _, ent in pairs(entities) do
        -- vehicle
		if not rolling_stocks[ent.name] then
            -- curved rail, special
            if 'curved-rail' ~= ent.name then
                local box = game.entity_prototypes[ent.name].collision_box or game.entity_prototypes[ent.name].selection_box

                if game.entity_prototypes[ent.name].collision_mask['ground-tile'] == nil then
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
                                name = landfill_tile,
                                position = {x, y}
                            }
                        end
                    end
                end

            -- curved rail
            else
                local dir = ent.direction or 8
                local curve_mask = curve_map(dir)

                for m=1, #curve_mask do
                    new_tiles[tile_index + 1] = {
                        name = landfill_tile,
                        position = {curve_mask[m].x + ent.position.x, curve_mask[m].y + ent.position.y}
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
                name = landfill_tile,
                position = {old_tile.position.x, old_tile.position.y}
            }

            tile_index = tile_index + 1
        end
    end

    return {tiles = new_tiles}
end

local function get_cursor_blueprint(player)
    local stack = player.cursor_stack

    if stack.valid_for_read then
        if stack.type ~= 'blueprint' then
            return false
        end

        if not stack or not stack.valid_for_read then
            return false
        end

        if stack.is_blueprint_setup() then
            return stack
        end
    end

    return false
end

--- A button to add landfill
-- @element landfill_gui_tile
local landfill_gui_tile =
Gui.element{
    type = 'button',
    name = Gui.unique_static_name,
    caption = {'landfill.tile'},
    tooltip = {'landfill.tile-tooltip'}
}:style{
    width = 160
}:on_click(function(player, _, _)
    if player.cursor_stack.valid_for_read then
        local blueprint = get_cursor_blueprint(player)

        if blueprint then
            local modified = landfill_gui_add_landfill(blueprint)

            if modified and next(modified.tiles) then
                blueprint.set_blueprint_tiles(modified.tiles)
            end
        end
    end
end)

--- The main container for the landfill gui
-- @element landfill_container
landfill_container =
Gui.element(function(definition, parent)
    -- local player = Gui.get_player_from_element(parent)
    local container = Gui.container(parent, definition.name, 160)

    landfill_gui_tile(container)
    return container.parent
end)
:static_name(Gui.unique_static_name)
:add_to_left_flow()

--- Button on the top flow used to toggle the task list container
-- @element toggle_left_element
Gui.left_toolbar_button('item/landfill', {'landfill.main-tooltip'}, landfill_container, function(player)
	return Roles.player_allowed(player, 'gui/landfill')
end)