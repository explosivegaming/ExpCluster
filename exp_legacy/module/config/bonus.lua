--- Lists all bonuses which can be used, name followed by min max
-- @config Bonuses

return {
    --[[
    TODO
    force bonus
    quick health regeneration

    Base point is equal to the amount of standard value in each parameter.

            CMMS    CRS     CCS     CISB    CHB     CRDB    PBR
    STD     30      90      32      20      16      12      60
    =       260

    MAX     60      180     64      40      32      24      120
    =       480
    ]]
    points = {
        base = 260,
        increase_percentage_per_role_level = 0.03,
        role_name = "Member",
    },
    periodic_bonus_rate = 300,
    player_bonus = {
        {
            name = "character_mining_speed_modifier",
            scale = 1,
            cost = 10,
            max_value = 6,
            initial_value = 3,
            value_step = 0.5,
            is_percentage = true,
        },
        {
            name = "character_running_speed_modifier",
            scale = 1,
            cost = 60,
            max_value = 3,
            initial_value = 1.5,
            value_step = 0.25,
            is_percentage = true,
        },
        {
            name = "character_crafting_speed_modifier",
            scale = 1,
            cost = 4,
            max_value = 16,
            initial_value = 8,
            value_step = 1,
            is_percentage = true,
        },
        {
            name = "character_inventory_slots_bonus",
            cost = 2,
            scale = 10,
            max_value = 200,
            initial_value = 100,
            value_step = 10,
        },
        {
            name = "character_health_bonus",
            scale = 50,
            cost = 4,
            max_value = 400,
            initial_value = 200,
            value_step = 50,
        },
        {
            name = "character_reach_distance_bonus",
            cost = 1,
            scale = 1,
            max_value = 24,
            initial_value = 12,
            value_step = 2,
            combined_bonus = {
                "character_resource_reach_distance_bonus",
                "character_build_distance_bonus",
            },
        },
        {
            name = "personal_battery_recharge",
            initial_value = 6,
            max_value = 12,
            value_step = 1,
            scale = 4,
            cost = 40,
            is_special = true,
        },
        --[[
        ['character_item_pickup_distance_bonus'] = {
            initial_value = 0,
            max_value = 20,
            value_step = 1,
            scale = 1,
            cost = 1,
            is_percentage = false
        },
        ['character_loot_pickup_distance_bonus'] = {
            initial_value = 0,
            max_value = 20,
            value_step = 1,
            scale = 1,
            cost = 1,
            is_percentage = false
        },
        ['character_item_drop_distance_bonus'] = {
            initial_value = 0,
            max_value = 20,
            value_step = 1,
            scale = 1,
            cost = 1,
            is_percentage = false
        }
        ]]
    },
    force_bonus = {
        --[[
        ['character_mining_speed_modifier'] = {
            initial_value = 0,
            max_value = 6,
            value_step = 0.5,
            scale = 1,
            cost = 10,
            is_percentage = true
        },
        ['character_running_speed_modifier'] = {
            initial_value = 0,
            max_value = 3,
            value_step = 0.25,
            scale = 1,
            cost = 40,
            is_percentage = true
        },
        ['character_crafting_speed_modifier'] = {
            initial_value = 0,
            max_value = 16,
            value_step = 1,
            scale = 1,
            cost = 4,
            is_percentage = true
        },
        ['character_inventory_slots_bonus'] = {
            initial_value = 0,
            max_value = 200,
            value_step = 10,
            scale = 100,
            cost = 2,
            is_percentage = false
        },
        ['character_health_bonus'] = {
            initial_value = 0,
            max_value = 400,
            value_step = 50,
            cost = 4,
            is_percentage = false
        },
        ['character_reach_distance_bonus'] = {
            initial_value = 0,
            max_value = 24,
            value_step = 2,
            scale = 1,
            cost = 1,
            is_percentage = false,
            combined_bonus = {
                'character_resource_reach_distance_bonus',
                'character_build_distance_bonus'
            }
        },
        ['worker_robots_speed_modifier'] = {
            initial_value = 0,
            max_value = 0,
            value_step = 0,
            scale = 1,
            cost = 1,
            is_percentage = false
        },
        ]]
        ["worker_robots_battery_modifier"] = {
            initial_value = 1,
            max_value = 1,
            value_step = 1,
            scale = 1,
            cost = 1,
            is_percentage = false,
        },
        ["worker_robots_storage_bonus"] = {
            initial_value = 1,
            max_value = 1,
            value_step = 1,
            scale = 1,
            cost = 1,
            is_percentage = false,
        },
        ["following_robots_lifetime_modifier"] = {
            initial_value = 1,
            max_value = 1,
            value_step = 1,
            scale = 1,
            cost = 1,
            is_percentage = false,
        },
        --[[
        ['character_item_pickup_distance_bonus'] = {
            initial_value = 0,
            max_value = 20,
            value_step = 1,
            scale = 1,
            cost = 1,
            is_percentage = false
        },
        ['character_loot_pickup_distance_bonus'] = {
            initial_value = 0,
            max_value = 20,
            value_step = 1,
            scale = 1,
            cost = 1,
            is_percentage = false
        },
        ['character_item_drop_distance_bonus'] = {
            initial_value = 0,
            max_value = 20,
            value_step = 1,
            scale = 1,
            cost = 1,
            is_percentage = false
        },
        ['character_trash_slot_count'] = {
            initial_value = 0,
            max_value = 0,
            value_step = 0,
            scale = 1,
            cost = 1,
            is_percentage = false
        },
        ['mining_drill_productivity_bonus'] = {
            initial_value = 0,
            max_value = 0,
            value_step = 0,
            scale = 1,
            cost = 1,
            is_percentage = false
        },
        ['train_braking_force_bonus'] = {
            initial_value = 0,
            max_value = 0,
            value_step = 0,
            scale = 1,
            cost = 1,
            is_percentage = false
        },
        ['laboratory_speed_modifier'] = {
            initial_value = 0,
            max_value = 0,
            value_step = 0,
            scale = 1,
            cost = 1,
            is_percentage = false
        },
        ['laboratory_productivity_bonus'] = {
            initial_value = 0,
            max_value = 0,
            value_step = 0,
            scale = 1,
            cost = 1,
            is_percentage = false
        },
        ['inserter_stack_size_bonus'] = {
            initial_value = 0,
            max_value = 0,
            value_step = 0,
            scale = 1,
            cost = 1,
            is_percentage = false
        },
        ['stack_inserter_capacity_bonus'] = {
            initial_value = 0,
            max_value = 0,
            value_step = 0,
            scale = 1,
            cost = 1,
            is_percentage = false
        },
        ['artillery_range_modifier'] = {
            initial_value = 0,
            max_value = 0,
            value_step = 0,
            scale = 1,
            cost = 1,
            is_percentage = false
        }
        ]]
    },
    surface_bonus = {
        --[[
        ['solar_power_multiplier'] = {
            initial_value = 1,
            max_value = 1000,
            value_step = 1,
            scale = 1,
            cost = 1,
            is_percentage = false
        }
        ]]
    },
}
