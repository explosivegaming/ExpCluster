--- Config file for the repair command
-- @config Repair

return {
    disallow = { --- @setting disallow items in this list will never be repaired
        ["loader"] = true,
        ["fast-loader"] = true,
        ["express-loader"] = true,
        ["electric-energy-interface"] = true,
        ["infinity-chest"] = true,
    },
    max_range = 50, --- @setting max_range the max range that can be used with the repair command
    allow_blueprint_repair = false, --- @setting allow_blueprint_repair when true will allow blueprints (things not destroyed by biters) to be build instantly using the repair command
    allow_ghost_revive = true, --- @setting allow_ghost_revive when true will allow ghosts (things destroyed by biters) to be build instantly using the repair command
    allow_heal_entities = true, --- @setting allow_heal_entities when true will heal entities to full health that are within range
}
