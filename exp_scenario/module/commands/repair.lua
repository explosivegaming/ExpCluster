--[[-- Commands - Repair
Adds a command that allows an admin to repair and revive a large area
]]

local Commands = require("modules/exp_commands")
local config = require("modules.exp_legacy.config.repair") --- @dep config.repair

--- Repairs entities on your force around you
Commands.new("repair", { "exp-commands_repair.description" })
    :argument("range", { "exp-commands_repair.arg-range" }, Commands.types.integer_range(1, config.max_range))
    :register(function(player, range)
        --- @cast range number
        local force = player.force
        local surface = player.surface -- Allow remote view
        local position = player.position -- Allow remote view
        local response = { "" } --- @type LocalisedString

        if config.allow_ghost_revive then
            local revive_count = 0
            local entities = surface.find_entities_filtered{
                type = "entity-ghost",
                position = position,
                radius = range,
                force = force,
            }

            local param = { raise_revive = true } --- @type LuaEntity.silent_revive_param
            for _, entity in ipairs(entities) do
                if not config.disallow[entity.ghost_name] and (config.allow_blueprint_repair or entity.created_by_corpse) then
                    revive_count = revive_count + 1
                    entity.silent_revive(param)
                end
            end

            response[#response + 1] = { "exp-commands_repair.response-revive", revive_count }
        end

        if config.allow_heal_entities then
            local healed_count = 0
            local entities = surface.find_entities_filtered{
                position = position,
                radius = range,
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

        return Commands.status.success(response)
    end)
