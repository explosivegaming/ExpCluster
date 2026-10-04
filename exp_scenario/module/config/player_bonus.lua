--- The bonuses players can spend their points on, see gui/player_bonus.lua
-- @config Player-Bonus

return {
    {
        name = "character_mining_speed_modifier",
        scale = 1,
        cost = 10,
        max_value = 4,
        value_step = 0.5,
        is_percentage = true,
    },
    {
        name = "character_running_speed_modifier",
        scale = 1,
        cost = 60,
        max_value = 2,
        value_step = 0.25,
        is_percentage = true,
    },
    {
        name = "character_crafting_speed_modifier",
        scale = 1,
        cost = 4,
        max_value = 12,
        value_step = 1,
        is_percentage = true,
    },
    {
        name = "character_inventory_slots_bonus",
        scale = 10,
        cost = 2,
        max_value = 100,
        value_step = 10,
    },
    {
        name = "character_health_bonus",
        scale = 50,
        cost = 4,
        max_value = 300,
        value_step = 50,
    },
    {
        name = "character_reach_distance_bonus",
        scale = 1,
        cost = 1,
        max_value = 16,
        value_step = 2,
        combined_bonus = {
            "character_resource_reach_distance_bonus",
            "character_build_distance_bonus",
        },
    },
    {
        name = "personal_battery_recharge",
        scale = 4,
        cost = 40,
        max_value = 8,
        value_step = 1,
        is_special = true,
    },

}
