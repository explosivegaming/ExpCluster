--- Res Settings
-- @config Research

return {
    enabled = true,
    pollution_ageing_by_research = false,
    queue_amount = 3,
    mod_set = "base",
    mod_set_lookup = {
        "space-age",
    },
    -- this enable 20 more inventory for each mining productivity level up to 4
    bonus_inventory = {
        enabled = true,
        log = {
            ["base"] = {
                ["name"] = "mining-productivity-4",
                ["level"] = 4
            },
            ["space-age"] = {
                ["name"] = "mining-productivity-3",
                ["level"] = 3
            },
        },
        res = {
            -- Mining Productivity
            ["mining-productivity"] = true,
            ["mining-productivity-2"] = true,
            ["mining-productivity-3"] = true,
            ["mining-productivity-4"] = true,
        },
        name = "character_inventory_slots_bonus",
        rate = 5,
        limit = 20,
    },
    file_name = "log/research.log",
    milestone = {
        ["base"] = {
            ["automation"] = 600,
            ["logistics"] = 300,
            ["steel-processing"] = 300,
            ["logistic-science-pack"] = 300,
            ["electronics"] = 300,
            ["fast-inserter"] = 300,
            ["steel-axe"] = 300,
            ["automation-2"] = 300,
            ["advanced-material-processing"] = 300,
            ["engine"] = 300,
            ["fluid-handling"] = 300,
            ["oil-processing"] = 300,
            ["sulfur-processing"] = 300,
            ["plastics"] = 300,
            ["advanced-circuit"] = 300,
            ["chemical-science-pack"] = 300,
            ["modules"] = 300,
            ["logistics-2"] = 300,
            ["railway"] = 300,
            ["research-speed-1"] = 300,
            ["research-speed-2"] = 300,
            ["battery"] = 300,
            ["concrete"] = 300,
            ["flammables"] = 300,
            ["low-density-structure"] = 300,
            ["advanced-material-processing-2"] = 300,
            ["productivity-module"] = 300,
            ["production-science-pack"] = 300,
            ["processing-unit"] = 300,
            ["advanced-oil-processing"] = 300,
            ["electric-engine"] = 300,
            ["robotics"] = 300,
            ["construction-robotics"] = 300,
            ["worker-robots-speed-1"] = 300,
            ["worker-robots-speed-2"] = 300,
            ["utility-science-pack"] = 300,
            ["productivity-module-2"] = 300,
            ["speed-module-2"] = 300,
            ["rocket-fuel"] = 300,
            ["effect-transmission"] = 300,
            ["productivity-module-3"] = 300,
            ["speed-module-3"] = 300,
            ["rocket-silo"] = 300,
            ["space-science-pack"] = 300,
        },
        ["space-age"] = {
            ["logistic-science-pack"] = 3600,
            ["military-science-pack"] = 3600,
            ["chemical-science-pack"] = 5400,
            ["utility-science-pack"] = 7200,
            ["production-science-pack"] = 7200,
            ["space-science-pack"] = 7200,
            ["metallurgic-science-pack"] = 10800,
            ["electromagnetic-science-pack"] = 10800,
            ["agricultural-science-pack"] = 10800,
            ["cryogenic-science-pack"] = 10800,
            ["promethium-science-pack"] = 14400,
        }
    },
    inf_res = {
        ["base"] = {
            -- Mining Productivity
            ["mining-productivity-4"] = 4,
            -- Robot Speed
            ["worker-robots-speed-6"] = 6,
            -- Laser Damage
            ["energy-weapons-damage-7"] = 7,
            -- Explosive Damage
            ["stronger-explosives-7"] = 7,
            -- Bullet Damage
            ["physical-projectile-damage-7"] = 7,
            -- Flame Damage
            ["refined-flammables-7"] = 7,
            -- Artillery Range
            ["artillery-shell-range-1"] = 1,
            -- Artillery Speed
            ["artillery-shell-speed-1"] = 1,
            -- Follower Robot Count
            ["follower-robot-count-5"] = 5,
        },
        ["space-age"] = {
            -- Mining Productivity
            ["mining-productivity-3"] = 3,
            -- Robot Speed
            ["worker-robots-speed-7"] = 7,
            -- Laser Damage
            ["laser-weapons-damage-7"] = 7,
            -- Electric Damage
            ["electric-weapons-damage-4"] = 4,
            -- Explosive Damage
            ["stronger-explosives-7"] = 7,
            -- Bullet Damage
            ["physical-projectile-damage-7"] = 7,
            -- Flame Damage
            ["refined-flammables-7"] = 7,
            -- Artillery Range
            ["artillery-shell-range-1"] = 1,
            -- Artillery Speed
            ["artillery-shell-speed-1"] = 1,
            -- Artillery Damage
            ["artillery-shell-damage-1"] = 1,
            -- Railgun Speed
            ["railgun-shooting-speed-1"] = 1,
            -- Railgun Damage
            ["railgun-damage-1"] = 1,
            -- Health
            ["health"] = 1,
            -- Research Productivity
            ["research-productivity"] = 1,
            -- Scrap Recycling Productivity
            ["scrap-recycling-productivity"] = 1,
            -- Asteroid Productivity
            ["asteroid-productivity"] = 1,
            -- Processing Unit Productivity
            ["processing-unit-productivity"] = 1,
            -- Steel Plate Productivity
            ["steel-plate-productivity"] = 1,
            -- Low Density Structure Productivity
            ["low-density-structure-productivity"] = 1,
            -- Plastic Bar Productivity
            ["plastic-bar-productivity"] = 1,
            -- Rocket Fuel Productivity
            ["rocket-fuel-productivity"] = 1,
            -- Rocket Part Productivity
            ["rocket-part-productivity"] = 1,
            -- Follower Robot Count
            ["follower-robot-count-5"] = 5,
        },
    },
    -- prevent research up to a certain level
    limit_res = {
        -- Artillery Range
        ["artillery-shell-range-1"] = 7,
        -- Artillery Speed
        ["artillery-shell-speed-1"] = 7,
        -- Atomic Bomb
        -- ["atomic-bomb"] = 1
    },
}
