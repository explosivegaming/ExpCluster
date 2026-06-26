--- Config file for the repair command
-- @config Repair

return {
    allow_blueprint_repair = false, --- @setting allow_blueprint_repair when true will allow blueprints (things not destroyed by biters) to be build instantly using the repair command
    allow_ghost_revive = true, --- @setting allow_ghost_revive when true will allow ghosts (things destroyed by biters) to be build instantly using the repair command
    allow_heal_entities = true, --- @setting allow_heal_entities when true will heal entities to full health that are within range
}
