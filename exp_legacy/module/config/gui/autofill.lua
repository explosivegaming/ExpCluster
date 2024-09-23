--- This file contains all the different settings for the autofill system and gui
-- @config Autofill

local table = require 'overrides.table' -- @dep overrides.table

local config = {
	-- General config
	icon = 'item/piercing-rounds-magazine', -- @setting icon that will be used for the toolbar
	categories = {
		ammo = 'ammo',
		fuel = 'fuel',
		shell = 'shell'
	},
	entities = {
		car = 'car',
		tank = 'tank',
		spidertron = 'spidertron',
		locomotive = 'locomotive',
		gun_turret = 'gun-turret',
		burner_mining_drill = 'burner-mining-drill',
		stone_furnace = 'stone-furnace',
		steel_furnace = 'steel-furnace'
	},
	default_entities = {}
}

local default_categories = {
	{
		category = config.categories.ammo,
		entity = {config.entities.car, config.entities.tank, config.entities.gun_turret},
		inv = {defines.inventory.car_ammo, defines.inventory.turret_ammo},
		items = {
			{ name = 'uranium-rounds-magazine', amount = 10, enabled = false },
			{ name = 'piercing-rounds-magazine', amount = 10, enabled = false },
			{ name = 'firearm-magazine', amount = 10, enabled = false },
		}
	},
	{
		category = config.categories.ammo,
		entity = {config.entities.tank},
		inv = {defines.inventory.car_ammo},
		items = {
			{ name = 'flamethrower-ammo', amount = 10, enabled = false },
		}
	},
	{
		category = config.categories.shell,
		entity = {config.entities.tank},
		inv = {defines.inventory.car_ammo},
		items = {
			{ name = 'cannon-shell', amount = 10, enabled = false },
			{ name = 'explosive-cannon-shell', amount = 10, enabled = false },
			{ name = 'uranium-cannon-shell', amount = 10, enabled = false },
			{ name = 'explosive-uranium-cannon-shell', amount = 10, enabled = false },
		}
	},
	{
		category = config.categories.ammo,
		entity = {config.entities.spidertron},
		inv = {defines.inventory.car_ammo},
		items = {
			{ name = 'rocket', amount = 10, enabled = false },
			{ name = 'explosive-rocket', amount = 10, enabled = false },
			{ name = 'atomic-bomb', amount = 10, enabled = false },
		}
	},
	{
		category = config.categories.fuel,
		entity = {config.entities.car, config.entities.tank, config.entities.locomotive, config.entities.burner_mining_drill, config.entities.stone_furnace, config.entities.steel_furnace},
		inv = {defines.inventory.fuel},
		items = {
			{ name = 'nuclear-fuel', amount = 10, enabled = false },
			{ name = 'rocket-fuel', amount = 10, enabled = false },
			{ name = 'solid-fuel', amount = 10, enabled = false },
			{ name = 'coal', amount = 10, enabled = false },
		}
	}
}

local function get_items_by_inv(entity, inv)
	local items = entity.items
	for _, category in pairs(default_categories) do
		if table.contains(category.entity, entity.entity) then
			if table.contains(category.inv, inv) then
				for _, item in pairs(category.items) do
					items[item.name] = {
						entity = entity.entity,
						category = category.category,
						inv = inv,
						name = item.name,
						amount = item.amount,
						enabled = item.enabled
					}
				end
			end
		end
	end
	return items
end

local function generate_default_setting(entity_name, inv, enabled)
	if not config.default_entities[entity_name] then
		config.default_entities[entity_name] = {
			entity = entity_name,
			enabled = enabled,
			items = {}
		}
	end
	get_items_by_inv(config.default_entities[entity_name], inv)
end

generate_default_setting(config.entities.car, defines.inventory.fuel, true)
generate_default_setting(config.entities.car, defines.inventory.car_ammo, true)

generate_default_setting(config.entities.locomotive, defines.inventory.fuel, true)

generate_default_setting(config.entities.tank, defines.inventory.fuel, true)
generate_default_setting(config.entities.tank, defines.inventory.car_ammo, true)

generate_default_setting(config.entities.spidertron, defines.inventory.car_ammo, true)

generate_default_setting(config.entities.gun_turret, defines.inventory.turret_ammo, true)

generate_default_setting(config.entities.burner_mining_drill, defines.inventory.fuel, true)

generate_default_setting(config.entities.stone_furnace, defines.inventory.fuel, true)

generate_default_setting(config.entities.steel_furnace, defines.inventory.fuel, true)

return config