local Event = require("utils.event")
local Global = require("utils.global")

local lib = {}

lib.data = {
	output = {}
}

Global.register(lib.data, function(tbl)
	lib.data = tbl
end)

---@class Statistics
---@field production ProductionStatistics?
---@field robots RobotStatistics?
---@field other OtherStatistics?
---@field research Research[]?

Event.on_init(function()
	---@type table<string, Statistics>
	lib.data.output = {}
	for _, force in pairs(game.forces) do
		lib.data.output[force.name] = {}
	end
end)

---@class OtherStatistics
---@field tick uint
---@field evolution EvolutionStatistics

---@class EvolutionStatistics
---@field evolution_factor double
---@field evolution_factor_by_pollution double
---@field evolution_factor_by_time double
---@field evolution_factor_by_killing_spawners double

lib.collect_other = function()
	for _, force in pairs(game.forces) do
		---@type OtherStatistics
		local other = lib.data.output[force.name].other or {}

		other.evolution = {
			evolution_factor = force.evolution_factor,
			evolution_factor_by_pollution = force.evolution_factor_by_pollution,
			evolution_factor_by_time = force.evolution_factor_by_time,
			evolution_factor_by_killing_spawners = force.evolution_factor_by_killing_spawners
		}
		for k, v in pairs(other) do
			lib.data.output[force.name].other[k] = v
		end
	end
end

Event.add(defines.events.on_force_created, function(evt)
	lib.data.output[evt.force.name] = {}
end)

Event.add(defines.events.on_forces_merged, function(evt)
	lib.data.output[evt.source_name] = nil
end)

return lib
