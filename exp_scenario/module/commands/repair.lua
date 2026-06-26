--[[-- Commands - Repair
Adds a command that allows an admin to repair and revive a large area
]]

local AABB = require("modules/exp_util/aabb")
local Commands = require("modules/exp_commands")
local config = require("modules.exp_legacy.config.repair") --- @dep config.repair
local Selection = require("modules/exp_util/selection")
local SelectArea = Selection.connect("ExpCommand_Waterfill")

--- @class ExpCommands_Repair.commands
local commands = {}

--- Toggle player selection mode
--- @class ExpCommands_Repair.commands.repair: ExpCommand
commands.repair = Commands.new("repair", { "exp-commands_repair.description" })
    :register(function(player)
        if SelectArea:stop(player) then
            return Commands.status.success{ "exp-commands_repair.exit" }
        end
        SelectArea:start(player)
        return Commands.status.success{ "exp-commands_repair.enter" }
    end)

--- When an area is selected to be converted to water
SelectArea:on_selection(function(event)
    local player = assert(game.get_player(event.player_index))
    local area = AABB.expand(event.area)
    local surface = event.surface
    local force = player.force
    local response = { "" } --- @type LocalisedString

    if config.allow_ghost_revive then
        local revive_count = 0
        local entities = surface.find_entities_filtered{
            type = "entity-ghost",
            area = area,
            force = force,
        }

        local param = { raise_revive = true } --- @type LuaEntity.silent_revive_param
        for _, entity in ipairs(entities) do
            if not (entity.ghost_prototype and entity.ghost_prototype.hidden) and (config.allow_blueprint_repair or entity.created_by_corpse) then
                revive_count = revive_count + 1
                entity.silent_revive(param)
            end
        end

        response[#response + 1] = { "exp-commands_repair.response-revive", revive_count }
    end

    if config.allow_heal_entities then
        local healed_count = 0
        local entities = surface.find_entities_filtered{
            area = area,
            force = force,
        }

        for _, entity in ipairs(entities) do
            if entity.health and entity.max_health and entity.health ~= entity.max_health then
                healed_count = healed_count + 1
                entity.health = entity.max_health
            end
        end

        response[#response + 1] = { "exp-commands_repair.response-heal", healed_count }
    end

    return player.print(response)
end)

return {
    commands = commands,
}
