--- This file controls the placement/degrading of tiles as players build and walk
-- @config Scorched-Earth

return {
    weakness_value = 70, --- @setting weakness_value lower value will make tiles more likely to degrade
    strengths = { --- @setting strengths this decides how "strong" a tile is, bigger number means less likely to degrade
        -- debug: /interface require('modules.addons.worn-paths')(player.name,true)
        -- note: tiles are effected by the tiles around them, so player paths will not degrade as fast when made wider
        -- note: values are relative to the tile with the highest value, recommended to keep highest tile as a "nice" number
        -- note: tiles not in list will never degrade under any conditions (which is why some are omitted such as water)
        ["refined-concrete"] = 100,
        ["refined-hazard-concrete-left"] = 100,
        ["refined-hazard-concrete-right"] = 100,
        ["concrete"] = 90,
        ["hazard-concrete-left"] = 90,
        ["hazard-concrete-right"] = 90,
        ["stone-path"] = 80,
        ["red-desert-0"] = 80,
        ["dry-dirt"] = 50,
        -- grass four (main grass tiles)
        ["grass-1"] = 50,
        ["grass-2"] = 40,
        ["grass-3"] = 30,
        ["grass-4"] = 25,
        -- red three (main red tiles)
        ["red-desert-1"] = 40,
        ["red-desert-2"] = 30,
        ["red-desert-3"] = 25,
        -- sand three (main sand tiles)
        ["sand-1"] = 40,
        ["sand-2"] = 30,
        ["sand-3"] = 25,
        -- dirt 3 (main dirt tiles)
        ["dirt-1"] = 40,
        ["dirt-2"] = 30,
        ["dirt-3"] = 25,
        -- last three/four (all sets of three merge here)
        ["dirt-4"] = 25,
        ["dirt-5"] = 30,
        ["dirt-6"] = 40,
        -- ["dirt-7"]=0, -- last tile, nothing to degrade to
        -- land fill chain
        -- ["landfill"]=50,
        -- ["water-shallow"]=90,
        -- ["water-mud"]=0, -- last tile, nothing to degrade to
    },
    degrade_order = { --- @setting degrade_order when a tile degrades it will turn into the next tile given here
        ["refined-concrete"] = "concrete",
        ["refined-hazard-concrete-left"] = "hazard-concrete-left",
        ["refined-hazard-concrete-right"] = "hazard-concrete-right",
        ["concrete"] = "stone-path",
        ["hazard-concrete-left"] = "stone-path",
        ["hazard-concrete-right"] = "stone-path",
        ["stone-path"] = "dry-dirt",
        ["red-desert-0"] = "dry-dirt",
        ["dry-dirt"] = "dirt-4",
        -- grass four (main grass tiles)
        ["grass-1"] = "grass-2",
        ["grass-2"] = "grass-3",
        ["grass-3"] = "grass-4",
        ["grass-4"] = "dirt-4",
        -- red three (main red tiles)
        ["red-desert-1"] = "red-desert-2",
        ["red-desert-2"] = "red-desert-3",
        ["red-desert-3"] = "dirt-4",
        -- sand three (main sand tiles)
        ["sand-1"] = "sand-2",
        ["sand-2"] = "sand-3",
        ["sand-3"] = "dirt-4",
        -- dirt 3 (main dirt tiles)
        ["dirt-1"] = "dirt-2",
        ["dirt-2"] = "dirt-3",
        ["dirt-3"] = "dirt-4",
        -- last three/four (all sets of three merge here)
        ["dirt-4"] = "dirt-5",
        ["dirt-5"] = "dirt-6",
        ["dirt-6"] = "dirt-7",
        -- ["dirt-7"]=0, -- last tile, nothing to degrade to
        -- land fill chain
        -- ["landfill"]='grass-2', -- 'water-shallow'
        -- ["water-shallow"]='water-mud',
        -- ["water-mud"]=0, -- last tile, nothing to degrade to
    },
    entities = { --- @setting entities entities in this list will degrade the tiles under them when they are placed
        ["stone-furnace"] = true,
        ["steel-furnace"] = true,
        ["electric-furnace"] = true,
        ["assembling-machine-1"] = true,
        ["assembling-machine-2"] = true,
        ["assembling-machine-3"] = true,
        ["beacon"] = true,
        ["centrifuge"] = true,
        ["chemical-plant"] = true,
        ["oil-refinery"] = true,
        ["storage-tank"] = true,
        ["nuclear-reactor"] = true,
        ["steam-engine"] = true,
        ["steam-turbine"] = true,
        ["boiler"] = true,
        ["heat-exchanger"] = true,
        ["stone-wall"] = true,
        ["gate"] = true,
        ["gun-turret"] = true,
        ["laser-turret"] = true,
        ["flamethrower-turret"] = true,
        ["radar"] = true,
        ["lab"] = true,
        ["big-electric-pole"] = true,
        ["substation"] = true,
        ["rocket-silo"] = true,
        ["pumpjack"] = true,
        ["electric-mining-drill"] = true,
        ["roboport"] = true,
        ["accumulator"] = true,
    },
}
