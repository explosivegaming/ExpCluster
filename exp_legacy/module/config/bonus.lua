--- Lists all bonuses which can be used, name followed by min max
-- @config Bonuses

return {
    --[[
    Base point is equal to the amount of standard value in each parameter.

            CMMS    CRS     CCS     CISB    CHB     CRDB    PBR
    STD     20      60      24      10      12      8      40
    =       174

    MAX     40      120     48      20      24      16      80
    =       348
    ]]
    points = {
        base = 174,
        increase_percentage_per_role_level = 0.03,
        role_name = "Member",
    },
    periodic_bonus_rate = 300,
    player_bonus = {
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
    },
    force_bonus = {
        ["worker_robots_battery_modifier"] = {
            max_value = 1,
            value_step = 1,
            scale = 1,
            cost = 1,
            is_percentage = false,
        },
        ["worker_robots_storage_bonus"] = {
            max_value = 1,
            value_step = 1,
            scale = 1,
            cost = 1,
            is_percentage = false,
        },
        ["following_robots_lifetime_modifier"] = {
            max_value = 1,
            value_step = 1,
            scale = 1,
            cost = 1,
            is_percentage = false,
        },
    },
    surface_bonus = {
    },
}
