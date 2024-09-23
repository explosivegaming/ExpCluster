local Event = require("utils.event")
local general = require("modules.graftorio.general")
local config = require("config.graftorio")

local lib = {}

lib.collect_production = function()
	for _, force in pairs(game.forces) do
		---@class ItemStats
		---@field count number

		---@class ProductionStatistics
		---@field item_input table<string, ItemStats>
		---@field item_output table<string, ItemStats>
		---@field fluid_input table<string, ItemStats>
		---@field fluid_output table<string, ItemStats>
		---@field kill_input table<string, ItemStats>
		---@field kill_output table<string, ItemStats>
		---@field build_input table<string, ItemStats>
		---@field build_output table<string, ItemStats>
		local stats = {
			item_input = {},
			item_output = {},
			fluid_input = {},
			fluid_output = {},
			kill_input = {},
			kill_output = {},
			build_input = {},
			build_output = {},
		}

		for name, count in pairs(force.item_production_statistics.input_counts) do
			local itemstats = stats.item_input[name] or {}
			itemstats.count = count
			stats.item_input[name] = itemstats
		end
		for name, count in pairs(force.item_production_statistics.output_counts) do
			local itemstats = stats.item_output[name] or {}
			itemstats.count = count
			stats.item_output[name] = itemstats
		end

		for name, count in pairs(force.fluid_production_statistics.input_counts) do
			local fluidstats = stats.fluid_input[name] or {}
			fluidstats.count = count
			stats.fluid_input[name] = fluidstats
		end
		for name, count in pairs(force.fluid_production_statistics.output_counts) do
			local fluidstats = stats.fluid_output[name] or {}
			fluidstats.count = count
			stats.fluid_output[name] = fluidstats
		end

		for name, count in pairs(force.kill_count_statistics.input_counts) do
			local killstats = stats.kill_input[name] or {}
			killstats.count = count
			stats.kill_input[name] = killstats
		end
		for name, count in pairs(force.kill_count_statistics.output_counts) do
			local killstats = stats.kill_output[name] or {}
			killstats.count = count
			stats.kill_output[name] = killstats
		end

		for name, count in pairs(force.entity_build_count_statistics.input_counts) do
			local buildstats = stats.build_input[name] or {}
			buildstats.count = count
			stats.build_input[name] = buildstats
		end
		for name, count in pairs(force.entity_build_count_statistics.output_counts) do
			local buildstats = stats.build_output[name] or {}
			buildstats.count = count
			stats.build_output[name] = buildstats
		end

		general.data.output[force.name].production = stats
	end
end

lib.collect_loginet = function()
	for _, force in pairs(game.forces) do
		---@class RobotStatistics
		---@field all_construction_robots uint
		---@field available_construction_robot uint
		---@field all_logistic_robots uint
		---@field available_logistic_robots uint
		---@field charging_robot_count uint
		---@field to_charge_robot_count uint
		---@field items table<string, uint>
		---@field pickups table<string, uint>
		---@field deliveries table<string, uint>
		local stats = {
			all_construction_robots = 0,
			available_construction_robots = 0,

			all_logistic_robots = 0,
			available_logistic_robots = 0,

			charging_robot_count = 0,
			to_charge_robot_count = 0,

			items = {},
			pickups = {},
			deliveries = {},
		}
		for _, networks in pairs(force.logistic_networks) do
			for _, network in pairs(networks) do
				stats.available_construction_robots = network.available_construction_robots
				stats.all_construction_robots = network.all_construction_robots

				stats.available_logistic_robots = network.available_logistic_robots
				stats.all_logistic_robots = network.all_logistic_robots

				stats.charging_robot_count = 0
				stats.to_charge_robot_count = 0
				for _, cell in pairs(network.cells) do
					stats.charging_robot_count = (stats.charging_robot_count) + cell.charging_robot_count
					stats.to_charge_robot_count = (stats.to_charge_robot_count) + cell.to_charge_robot_count
				end

				if config.modules.logistorage then
					for name, v in pairs(network.get_contents()) do
						stats.items[name] = (stats.items[name] or 0) + v
					end

					-- pickups and deliveries of items
					for _, point_list in pairs({ network.provider_points, network.requester_points, network.storage_points }) do
						for _, point in pairs(point_list) do
							for name, qty in pairs(point.targeted_items_pickup) do
								stats.pickups[name] = (stats.pickups[name] or 0) + qty
							end
							for name, qty in pairs(point.targeted_items_deliver) do
								stats.deliveries[name] = (stats.deliveries[name] or 0) + qty
							end
						end
					end
				end
			end
		end
		general.data.output[force.name].robots = stats
	end
end

---@class Research
---@field name string
---@field level uint
---@field progress double

Event.add(defines.events.on_research_finished, function(evt)
	local research = evt.research
	if not general.data.output[research.force.name] then general.data.output[research.force.name] = {} end
	if not general.data.output[research.force.name].research then general.data.output[research.force.name].research = {} end

	local force_research = general.data.output[research.force.name].research or {}
	table.remove(force_research, 1)
	general.data.output[research.force.name].research = force_research
end)

Event.add(defines.events.on_research_started, function(evt)
	-- move queue up
	local research = evt.research
	if not general.data.output[research.force.name].research then general.data.output[research.force.name].research = {} end

	local force_research = general.data.output[research.force.name].research or {}
	table.remove(force_research, 1)
	general.data.output[research.force.name].research = force_research
end)

Event.on_nth_tick(60, function()
	for _, force in pairs(game.forces) do
		if not general.data.output[force.name].research then general.data.output[force.name].research = {} end

		local force_research = {}
		-- this works even if the queue is disabled, but it will always be just 1 long in that case
		for _, research in pairs(force.research_queue) do
			table.insert(force_research, {
				name = research.name,
				level = research.level,
				progress = force.get_saved_technology_progress(research) or 0,
			})
		end

		general.data.output[force.name].research = force_research
	end
end)

return lib
