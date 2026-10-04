--- The machines the module inserter can fill, and the modules it puts in them, by mod set
-- @config Module-Inserter-Machines

return {
    ["base"] = {
        ["electric-mining-drill"] = {
            ["module"] = "efficiency-module",
            ["prod"] = true,
        },
        ["pumpjack"] = {
            ["module"] = "efficiency-module",
            ["prod"] = true,
        },
        ["assembling-machine-2"] = {
            ["module"] = "productivity-module",
            ["prod"] = true,
        },
        ["assembling-machine-3"] = {
            ["module"] = "productivity-module-3",
            ["prod"] = true,
        },
        ["electric-furnace"] = {
            ["module"] = "productivity-module-3",
            ["prod"] = true,
        },
        ["beacon"] = {
            ["module"] = "speed-module-3",
            ["prod"] = false,
        },
        ["oil-refinery"] = {
            ["module"] = "productivity-module-3",
            ["prod"] = true,
        },
        ["chemical-plant"] = {
            ["module"] = "productivity-module-3",
            ["prod"] = true,
        },
        ["centrifuge"] = {
            ["module"] = "productivity-module-3",
            ["prod"] = true,
        },
        ["lab"] = {
            ["module"] = "productivity-module-3",
            ["prod"] = true,
        },
        ["rocket-silo"] = {
            ["module"] = "productivity-module-3",
            ["prod"] = true,
        }
    },
    ["space-age"] = {
        ["big-mining-drill"] = {
            ["module"] = "efficiency-module",
            ["prod"] = true,
        },
        ["biochamber"] = {
            ["module"] = "efficiency-module",
            ["prod"] = true,
        },
        ["electromagnetic-plant"] = {
            ["module"] = "productivity-module-3",
            ["prod"] = true,
        },
        ["cryogenic-plant"] = {
            ["module"] = "productivity-module-3",
            ["prod"] = true,
        },
        ["biolab"] = {
            ["module"] = "productivity-module-3",
            ["prod"] = true,
        },
        ["foundry"] = {
            ["module"] = "productivity-module-3",
            ["prod"] = true,
        },
        ["recycler"] = {
            ["module"] = "quality-module-3",
            ["prod"] = true,
        }
    }

}
