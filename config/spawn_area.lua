--- Used to config the spawn generation settings yes there is alot here i know just ignore the long tables at the end (they were generated with a command)
-- @config Spawn-Area

return {
    spawn_area = { --- @setting spawn_area Settings relating to the whole spawn area
        -- Enable predefined patches: 128, else: 32
        deconstruction_radius = 20, -- @setting deconstruction_radius All entities within this radius will be removed
        tile_radius = 20,
        deconstruction_tile = 'refined-concrete', --- @setting deconstruction_tile Tile to be placed in the deconstruction radius, use nil for map gen
        landfill_radius = 50, --- @setting pattern_radius All water within this radius will be land filled
    },
    turrets = { --- @setting turrets Settings relating to adding turrets to spawn
        enabled = true, --- @setting enabled Whether turrets will be added to spawn
        ammo_type = 'uranium-rounds-magazine', --- @setting ammo_type The ammo type that will be used during refills
        refill_time = 60*60*5, --- @setting refill_time The time in ticks between each refill of the turrets, only change if having lag issues
        offset = {x=0, y=0}, --- @setting offset The position offset to apply to turrets
        locations = { --- @setting locations The locations of all turrets, this list can change during runtime
            {surface=1,position={x=-3,y=-3}},
            {surface=1,position={x=3,y=-3}},
            {surface=1,position={x=-3,y=3}},
            {surface=1,position={x=3,y=3}}
        }
    },
    afk_belts = { --- @setting afk_belts Settings relating to adding afk belts to spawn
        enabled = true, --- @setting enabled Whether afk belts will be added to spawn
        belt_type = 'fast-transport-belt', --- @setting belt_type The belt to be used as afk belts
        protected = true, --- @setting protected Whether belts will be protected from player interaction
        offset = {x=0, y=0}, --- @setting offset The position offset to apply to afk belts
        locations={ --- @setting locations The locations to spawn afk belts at, given as the top left position
            {-5,-5}, {5,-5},
            {-5,5}, {5,5}
        }
    },
    water = { --- @setting water Settings relating to adding water to spawn
        enabled = true, --- @setting enabled Whether water tiles will be added to spawn
        water_tile = 'water-mud', --- @setting water_tile The tile to be used as the water tile
        offset = {x=0, y=0}, --- @setting offset The position offset to apply to water tiles
        locations = { --- @setting locations The location of the water tiles {x,y}
            -- Each is a 3x3 with the closest tile to 0,0 removed
            {7,8}, {7,9}, {8,7}, {8,8}, {8,9}, {9,7}, {9,8}, {9,9}, -- Bottom Right
            {7,-9}, {7,-10}, {8,-8}, {8,-9}, {8,-10}, {9,-8}, { 9,-9}, {9,-10}, -- Top Right
            {-8,-9}, {-8,-10}, {-9,-8}, {-9,-9}, {-9,-10}, {-10,-8}, {-10,-9}, {-10,-10}, -- Top Left
            {-8,8}, {-8,9}, {-9,7}, {-9,8}, {-9,9}, {-10,7}, {-10,8}, {-10,9}, -- Bottom Left
        }
    },
    entities = { --- @setting entities Settings relating to adding entities to spawn
        enabled = true,  --- @setting enabled Whether entities will be added to spawn
        protected = true, --- @setting protected Whether entities will be protected from player interaction
        operable = true, --- @setting operable Whether entities can be opened by players, must be true if chests are used
        offset = {x=0, y=-2}, --- @setting offset The position offset to apply to entities
        locations = { --- @setting locations The location and names of entities {name,x,y}
        {"stone-wall",-10,-5},{"stone-wall",-10,-4},{"stone-wall",-10,-3},{"stone-wall",-10,-2},{"stone-wall",-10,-1},{"stone-wall",-10,0},{"stone-wall",-10,3},{"stone-wall",-10,4},{"stone-wall",-10,5},
        {"stone-wall",-10,6},{"stone-wall",-10,7},{"stone-wall",-10,8},{"small-lamp",-8,-4},{"small-lamp",-8,-1},{"logistic-chest-passive-provider",-8,0},{"logistic-chest-passive-provider",-8,3},{"small-lamp",-8,4},
        {"small-lamp",-8,7},{"stone-wall",-7,-8},{"medium-electric-pole",-7,-2},{"logistic-chest-passive-provider",-7,0},{"logistic-chest-passive-provider",-7,3},{"medium-electric-pole",-7,5},{"stone-wall",-7,11},{"stone-wall",-6,-8},{"small-lamp",-6,-6},
        {"logistic-chest-passive-provider",-6,0},{"logistic-chest-passive-provider",-6,3},{"small-lamp",-6,9},{"stone-wall",-6,11},{"stone-wall",-5,-8},{"small-lamp",-5,-1},{"logistic-chest-passive-provider",-5,0},{"logistic-chest-passive-provider",-5,3},{"small-lamp",-5,4},{"stone-wall",-5,11},
        {"stone-wall",-4,-8},{"medium-electric-pole",-4,-5},{"logistic-chest-passive-provider",-4,0},{"logistic-chest-passive-provider",-4,3},{"medium-electric-pole",-4,8},{"stone-wall",-4,11},{"stone-wall",-3,-8},{"small-lamp",-3,-6},{"small-lamp",-3,-3},{"small-lamp",-3,6},
        {"small-lamp",-3,9},{"stone-wall",-3,11},{"stone-wall",-2,-8},{"logistic-chest-passive-provider",-2,-6},{"logistic-chest-passive-provider",-2,-5},{"logistic-chest-passive-provider",-2,-4},{"logistic-chest-passive-provider",-2,-3},{"logistic-chest-passive-provider",-2,-2},{"logistic-chest-passive-provider",-2,5},{"logistic-chest-passive-provider",-2,6},
        {"logistic-chest-passive-provider",-2,7},{"logistic-chest-passive-provider",-2,8},{"logistic-chest-passive-provider",-2,9},{"stone-wall",-2,11},{"stone-wall",1,-8},{"logistic-chest-passive-provider",1,-6},
        {"logistic-chest-passive-provider",1,-5},{"logistic-chest-passive-provider",1,-4},{"logistic-chest-passive-provider",1,-3},{"logistic-chest-passive-provider",1,-2},{"logistic-chest-passive-provider",1,5},{"logistic-chest-passive-provider",1,6},{"logistic-chest-passive-provider",1,7},{"logistic-chest-passive-provider",1,8},{"logistic-chest-passive-provider",1,9},{"stone-wall",1,11},
        {"stone-wall",2,-8},{"small-lamp",2,-6},{"small-lamp",2,-3},{"small-lamp",2,6},{"small-lamp",2,9},{"stone-wall",2,11},{"stone-wall",3,-8},{"medium-electric-pole",3,-5},{"logistic-chest-passive-provider",3,0},{"logistic-chest-passive-provider",3,3},
        {"medium-electric-pole",3,8},{"stone-wall",3,11},{"stone-wall",4,-8},{"small-lamp",4,-1},{"logistic-chest-passive-provider",4,0},{"logistic-chest-passive-provider",4,3},{"small-lamp",4,4},{"stone-wall",4,11},{"stone-wall",5,-8},{"small-lamp",5,-6},
        {"logistic-chest-passive-provider",5,0},{"logistic-chest-passive-provider",5,3},{"small-lamp",5,9},{"stone-wall",5,11},{"stone-wall",6,-8},{"medium-electric-pole",6,-2},{"logistic-chest-passive-provider",6,0},{"logistic-chest-passive-provider",6,3},{"medium-electric-pole",6,5},{"stone-wall",6,11},
        {"small-lamp",7,-4},{"small-lamp",7,-1},{"logistic-chest-passive-provider",7,0},{"logistic-chest-passive-provider",7,3},{"small-lamp",7,4},{"small-lamp",7,7},{"stone-wall",9,-5},
        {"stone-wall",9,-4},{"stone-wall",9,-3},{"stone-wall",9,-2},{"stone-wall",9,-1},{"stone-wall",9,0},{"stone-wall",9,3},{"stone-wall",9,4},{"stone-wall",9,5},{"stone-wall",9,6},{"stone-wall",9,7},
        {"stone-wall",9,8}
        }
    },
    pattern = {
        enabled = true, --- @setting enabled Whether pattern tiles will be added to spawn
        pattern_tile = 'refined-concrete', --- @setting pattern_tile The tile to be used for the pattern
        offset = {x=0, y=-2}, --- @setting offset The position offset to apply to pattern tiles
        locations = { --- @setting locations The location of the pattern tiles {x,y}
            {-49,-3},{-49,-2},{-49,1},{-49,2},{-49,5},{-49,6},{-48,-4},{-48,-3},{-48,-2},{-48,1},{-48,2},{-48,5},{-48,6},{-48,7},{-47,-7},{-47,-6},{-47,-5},{-47,-4},{-47,-3},{-47,-2},{-47,5},{-47,6},{-47,7},{-47,8},{-47,9},{-47,10},{-46,-8},{-46,-7},{-46,-6},{-46,-5},
            {-46,-4},{-46,-3},{-46,-2},{-46,-1},{-46,4},{-46,5},{-46,6},{-46,7},{-46,8},{-46,9},{-46,10},{-46,11},{-45,-17},{-45,-16},{-45,-15},{-45,-14},{-45,-13},{-45,-12},{-45,-9},{-45,-8},{-45,-7},{-45,-2},{-45,-1},{-45,0},{-45,1},{-45,2},{-45,3},{-45,4},{-45,5},{-45,10},
            {-45,11},{-45,12},{-45,15},{-45,16},{-45,17},{-45,18},{-45,19},{-45,20},{-44,-18},{-44,-17},{-44,-16},{-44,-15},{-44,-14},{-44,-13},{-44,-12},{-44,-9},{-44,-8},{-44,-1},{-44,0},{-44,1},{-44,2},{-44,3},{-44,4},{-44,11},{-44,12},{-44,15},{-44,16},{-44,17},{-44,18},{-44,19},
            {-44,20},{-44,21},{-43,-19},{-43,-18},{-43,-17},{-43,-1},{-43,0},{-43,1},{-43,2},{-43,3},{-43,4},{-43,20},{-43,21},{-43,22},{-42,-19},{-42,-18},{-42,-1},{-42,0},{-42,1},{-42,2},{-42,3},{-42,4},{-42,21},{-42,22},{-41,-25},{-41,-24},{-41,-19},{-41,-18},{-41,-13},{-41,-12},
            {-41,-11},{-41,-10},{-41,-5},{-41,-4},{-41,7},{-41,8},{-41,13},{-41,14},{-41,15},{-41,16},{-41,21},{-41,22},{-41,27},{-41,28},{-40,-26},{-40,-25},{-40,-24},{-40,-20},{-40,-19},{-40,-18},{-40,-13},{-40,-12},{-40,-11},{-40,-10},{-40,-5},{-40,-4},{-40,7},{-40,8},{-40,13},{-40,14},
            {-40,15},{-40,16},{-40,21},{-40,22},{-40,23},{-40,27},{-40,28},{-40,29},{-39,-27},{-39,-26},{-39,-25},{-39,-24},{-39,-21},{-39,-20},{-39,-19},{-39,-13},{-39,-12},{-39,-5},{-39,-4},{-39,-3},{-39,-2},{-39,-1},{-39,0},{-39,1},{-39,2},{-39,3},{-39,4},{-39,5},{-39,6},{-39,7},
            {-39,8},{-39,15},{-39,16},{-39,22},{-39,23},{-39,24},{-39,27},{-39,28},{-39,29},{-39,30},{-38,-27},{-38,-26},{-38,-25},{-38,-24},{-38,-21},{-38,-20},{-38,-13},{-38,-12},{-38,-5},{-38,-4},{-38,-3},{-38,-2},{-38,-1},{-38,0},{-38,1},{-38,2},{-38,3},{-38,4},{-38,5},{-38,6},
            {-38,7},{-38,8},{-38,15},{-38,16},{-38,23},{-38,24},{-38,27},{-38,28},{-38,29},{-38,30},{-37,-17},{-37,-16},{-37,-13},{-37,-12},{-37,-11},{-37,-10},{-37,-4},{-37,-3},{-37,-2},{-37,-1},{-37,0},{-37,3},{-37,4},{-37,5},{-37,6},{-37,7},{-37,13},{-37,14},{-37,15},{-37,16},
            {-37,19},{-37,20},{-36,-17},{-36,-16},{-36,-13},{-36,-12},{-36,-11},{-36,-10},{-36,-9},{-36,-3},{-36,-2},{-36,-1},{-36,0},{-36,3},{-36,4},{-36,5},{-36,6},{-36,12},{-36,13},{-36,14},{-36,15},{-36,16},{-36,19},{-36,20},{-35,-29},{-35,-28},{-35,-23},{-35,-22},{-35,-17},{-35,-16},
            {-35,-12},{-35,-11},{-35,-10},{-35,-9},{-35,-8},{-35,11},{-35,12},{-35,13},{-35,14},{-35,15},{-35,19},{-35,20},{-35,25},{-35,26},{-35,31},{-35,32},{-34,-30},{-34,-29},{-34,-28},{-34,-23},{-34,-22},{-34,-17},{-34,-16},{-34,-15},{-34,-11},{-34,-10},{-34,-9},{-34,-8},{-34,11},{-34,12},
            {-34,13},{-34,14},{-34,18},{-34,19},{-34,20},{-34,25},{-34,26},{-34,31},{-34,32},{-34,33},{-33,-31},{-33,-30},{-33,-29},{-33,-28},{-33,-23},{-33,-22},{-33,-16},{-33,-15},{-33,-14},{-33,-5},{-33,-4},{-33,-1},{-33,0},{-33,3},{-33,4},{-33,7},{-33,8},{-33,17},{-33,18},{-33,19},
            {-33,25},{-33,26},{-33,31},{-33,32},{-33,33},{-33,34},{-32,-32},{-32,-31},{-32,-30},{-32,-29},{-32,-28},{-32,-27},{-32,-23},{-32,-22},{-32,-21},{-32,-15},{-32,-14},{-32,-6},{-32,-5},{-32,-4},{-32,-1},{-32,0},{-32,3},{-32,4},{-32,7},{-32,8},{-32,9},{-32,17},{-32,18},{-32,24},
            {-32,25},{-32,26},{-32,30},{-32,31},{-32,32},{-32,33},{-32,34},{-32,35},{-31,-33},{-31,-32},{-31,-31},{-31,-30},{-31,-29},{-31,-28},{-31,-27},{-31,-26},{-31,-22},{-31,-21},{-31,-20},{-31,-19},{-31,-18},{-31,-11},{-31,-10},{-31,-9},{-31,-8},{-31,-7},{-31,-6},{-31,-5},{-31,-1},{-31,0},
            {-31,1},{-31,2},{-31,3},{-31,4},{-31,8},{-31,9},{-31,10},{-31,11},{-31,12},{-31,13},{-31,14},{-31,21},{-31,22},{-31,23},{-31,24},{-31,25},{-31,29},{-31,30},{-31,31},{-31,32},{-31,33},{-31,34},{-31,35},{-31,36},{-30,-33},{-30,-32},{-30,-31},{-30,-30},{-30,-29},{-30,-28},
            {-30,-27},{-30,-26},{-30,-21},{-30,-20},{-30,-19},{-30,-18},{-30,-11},{-30,-10},{-30,-9},{-30,-8},{-30,-7},{-30,-6},{-30,-1},{-30,0},{-30,1},{-30,2},{-30,3},{-30,4},{-30,9},{-30,10},{-30,11},{-30,12},{-30,13},{-30,14},{-30,21},{-30,22},{-30,23},{-30,24},{-30,29},{-30,30},
            {-30,31},{-30,32},{-30,33},{-30,34},{-30,35},{-30,36},{-29,-37},{-29,-36},{-29,-30},{-29,-29},{-29,-28},{-29,-27},{-29,-26},{-29,-15},{-29,-14},{-29,-10},{-29,-9},{-29,-8},{-29,-7},{-29,10},{-29,11},{-29,12},{-29,13},{-29,17},{-29,18},{-29,29},{-29,30},{-29,31},{-29,32},{-29,33},
            {-29,39},{-29,40},{-28,-38},{-28,-37},{-28,-36},{-28,-29},{-28,-28},{-28,-27},{-28,-26},{-28,-16},{-28,-15},{-28,-14},{-28,-9},{-28,-8},{-28,11},{-28,12},{-28,17},{-28,18},{-28,19},{-28,29},{-28,30},{-28,31},{-28,32},{-28,39},{-28,40},{-28,41},{-27,-39},{-27,-38},{-27,-37},{-27,-36},
            {-27,-23},{-27,-22},{-27,-19},{-27,-18},{-27,-17},{-27,-16},{-27,-15},{-27,-5},{-27,-4},{-27,-1},{-27,0},{-27,1},{-27,2},{-27,3},{-27,4},{-27,7},{-27,8},{-27,18},{-27,19},{-27,20},{-27,21},{-27,22},{-27,25},{-27,26},{-27,39},{-27,40},{-27,41},{-27,42},{-26,-39},{-26,-38},
            {-26,-37},{-26,-36},{-26,-24},{-26,-23},{-26,-22},{-26,-19},{-26,-18},{-26,-17},{-26,-16},{-26,-6},{-26,-5},{-26,-4},{-26,-1},{-26,0},{-26,1},{-26,2},{-26,3},{-26,4},{-26,7},{-26,8},{-26,9},{-26,19},{-26,20},{-26,21},{-26,22},{-26,25},{-26,26},{-26,27},{-26,39},{-26,40},
            {-26,41},{-26,42},{-25,-33},{-25,-32},{-25,-31},{-25,-30},{-25,-25},{-25,-24},{-25,-23},{-25,-22},{-25,-19},{-25,-18},{-25,-17},{-25,-9},{-25,-8},{-25,-7},{-25,-6},{-25,-5},{-25,-4},{-25,-1},{-25,0},{-25,1},{-25,2},{-25,3},{-25,4},{-25,7},{-25,8},{-25,9},{-25,10},{-25,11},
            {-25,12},{-25,20},{-25,21},{-25,22},{-25,25},{-25,26},{-25,27},{-25,28},{-25,33},{-25,34},{-25,35},{-25,36},{-24,-33},{-24,-32},{-24,-31},{-24,-30},{-24,-29},{-24,-25},{-24,-24},{-24,-23},{-24,-22},{-24,-19},{-24,-18},{-24,-9},{-24,-8},{-24,-7},{-24,-6},{-24,-5},{-24,-4},{-24,-1},
            {-24,0},{-24,1},{-24,2},{-24,3},{-24,4},{-24,7},{-24,8},{-24,9},{-24,10},{-24,11},{-24,12},{-24,21},{-24,22},{-24,25},{-24,26},{-24,27},{-24,28},{-24,32},{-24,33},{-24,34},{-24,35},{-24,36},{-23,-37},{-23,-36},{-23,-30},{-23,-29},{-23,-28},{-23,-19},{-23,-18},{-23,-15},
            {-23,-14},{-23,-9},{-23,-8},{-23,-7},{-23,-6},{-23,-5},{-23,0},{-23,1},{-23,2},{-23,3},{-23,8},{-23,9},{-23,10},{-23,11},{-23,12},{-23,17},{-23,18},{-23,21},{-23,22},{-23,31},{-23,32},{-23,33},{-23,39},{-23,40},{-22,-38},{-22,-37},{-22,-36},{-22,-29},{-22,-28},{-22,-19},
            {-22,-18},{-22,-15},{-22,-14},{-22,-13},{-22,-9},{-22,-8},{-22,-7},{-22,-6},{-22,1},{-22,2},{-22,9},{-22,10},{-22,11},{-22,12},{-22,16},{-22,17},{-22,18},{-22,21},{-22,22},{-22,31},{-22,32},{-22,39},{-22,40},{-22,41},{-21,-41},{-21,-40},{-21,-39},{-21,-38},{-21,-37},{-21,-29},
            {-21,-28},{-21,-25},{-21,-24},{-21,-23},{-21,-22},{-21,-21},{-21,-20},{-21,-19},{-21,-18},{-21,-15},{-21,-14},{-21,-13},{-21,-12},{-21,-3},{-21,-2},{-21,5},{-21,6},{-21,15},{-21,16},{-21,17},{-21,18},{-21,21},{-21,22},{-21,23},{-21,24},{-21,25},{-21,26},{-21,27},{-21,28},{-21,31},
            {-21,32},{-21,40},{-21,41},{-21,42},{-21,43},{-21,44},{-20,-42},{-20,-41},{-20,-40},{-20,-39},{-20,-38},{-20,-29},{-20,-28},{-20,-25},{-20,-24},{-20,-23},{-20,-22},{-20,-21},{-20,-20},{-20,-19},{-20,-18},{-20,-15},{-20,-14},{-20,-13},{-20,-12},{-20,-3},{-20,-2},{-20,-1},{-20,4},{-20,5},
            {-20,6},{-20,15},{-20,16},{-20,17},{-20,18},{-20,21},{-20,22},{-20,23},{-20,24},{-20,25},{-20,26},{-20,27},{-20,28},{-20,31},{-20,32},{-20,41},{-20,42},{-20,43},{-20,44},{-20,45},{-19,-43},{-19,-42},{-19,-41},{-19,-35},{-19,-34},{-19,-33},{-19,-32},{-19,-25},{-19,-24},{-19,-23},
            {-19,-15},{-19,-14},{-19,-13},{-19,-9},{-19,-8},{-19,-7},{-19,-6},{-19,-2},{-19,-1},{-19,0},{-19,1},{-19,2},{-19,3},{-19,4},{-19,5},{-19,9},{-19,10},{-19,11},{-19,12},{-19,16},{-19,17},{-19,18},{-19,26},{-19,27},{-19,28},{-19,35},{-19,36},{-19,37},{-19,38},{-19,44},
            {-19,45},{-19,46},{-18,-43},{-18,-42},{-18,-35},{-18,-34},{-18,-33},{-18,-32},{-18,-31},{-18,-26},{-18,-25},{-18,-24},{-18,-15},{-18,-14},{-18,-10},{-18,-9},{-18,-8},{-18,-7},{-18,-6},{-18,-1},{-18,0},{-18,1},{-18,2},{-18,3},{-18,4},{-18,9},{-18,10},{-18,11},{-18,12},{-18,13},
            {-18,17},{-18,18},{-18,27},{-18,28},{-18,29},{-18,34},{-18,35},{-18,36},{-18,37},{-18,38},{-18,45},{-18,46},{-17,-43},{-17,-42},{-17,-32},{-17,-31},{-17,-30},{-17,-27},{-17,-26},{-17,-25},{-17,-21},{-17,-20},{-17,-19},{-17,-18},{-17,-17},{-17,-16},{-17,-15},{-17,-14},{-17,-11},{-17,-10},
            {-17,-9},{-17,-8},{-17,-7},{-17,-6},{-17,0},{-17,1},{-17,2},{-17,3},{-17,9},{-17,10},{-17,11},{-17,12},{-17,13},{-17,14},{-17,17},{-17,18},{-17,19},{-17,20},{-17,21},{-17,22},{-17,23},{-17,24},{-17,28},{-17,29},{-17,30},{-17,33},{-17,34},{-17,35},{-17,45},{-17,46},
            {-16,-43},{-16,-42},{-16,-31},{-16,-30},{-16,-27},{-16,-26},{-16,-21},{-16,-20},{-16,-19},{-16,-18},{-16,-17},{-16,-16},{-16,-15},{-16,-14},{-16,-11},{-16,-10},{-16,-9},{-16,-8},{-16,-7},{-16,-6},{-16,1},{-16,2},{-16,9},{-16,10},{-16,11},{-16,12},{-16,13},{-16,14},{-16,17},{-16,18},
            {-16,19},{-16,20},{-16,21},{-16,22},{-16,23},{-16,24},{-16,29},{-16,30},{-16,33},{-16,34},{-16,45},{-16,46},{-15,-43},{-15,-42},{-15,-39},{-15,-38},{-15,-37},{-15,-36},{-15,-35},{-15,-34},{-15,-20},{-15,-19},{-15,-18},{-15,-17},{-15,-10},{-15,-9},{-15,-8},{-15,-7},{-15,-3},{-15,-2},
            {-15,1},{-15,2},{-15,5},{-15,6},{-15,10},{-15,11},{-15,12},{-15,13},{-15,20},{-15,21},{-15,22},{-15,23},{-15,37},{-15,38},{-15,39},{-15,40},{-15,41},{-15,42},{-15,45},{-15,46},{-14,-43},{-14,-42},{-14,-39},{-14,-38},{-14,-37},{-14,-36},{-14,-35},{-14,-34},{-14,-33},{-14,-19},
            {-14,-18},{-14,-9},{-14,-8},{-14,-4},{-14,-3},{-14,-2},{-14,1},{-14,2},{-14,5},{-14,6},{-14,7},{-14,11},{-14,12},{-14,21},{-14,22},{-14,36},{-14,37},{-14,38},{-14,39},{-14,40},{-14,41},{-14,42},{-14,45},{-14,46},{-13,-39},{-13,-38},{-13,-35},{-13,-34},{-13,-33},{-13,-32},
            {-13,-29},{-13,-28},{-13,-15},{-13,-14},{-13,-5},{-13,-4},{-13,-3},{-13,-2},{-13,5},{-13,6},{-13,7},{-13,8},{-13,17},{-13,18},{-13,31},{-13,32},{-13,35},{-13,36},{-13,37},{-13,38},{-13,41},{-13,42},{-12,-39},{-12,-38},{-12,-35},{-12,-34},{-12,-33},{-12,-32},{-12,-29},{-12,-28},
            {-12,-27},{-12,-16},{-12,-15},{-12,-14},{-12,-13},{-12,-5},{-12,-4},{-12,-3},{-12,-2},{-12,5},{-12,6},{-12,7},{-12,8},{-12,16},{-12,17},{-12,18},{-12,19},{-12,30},{-12,31},{-12,32},{-12,35},{-12,36},{-12,37},{-12,38},{-12,41},{-12,42},{-11,-43},{-11,-42},{-11,-34},{-11,-33},
            {-11,-32},{-11,-29},{-11,-28},{-11,-27},{-11,-26},{-11,-23},{-11,-22},{-11,-21},{-11,-20},{-11,-17},{-11,-16},{-11,-15},{-11,-14},{-11,-13},{-11,-12},{-11,-9},{-11,-8},{-11,1},{-11,2},{-11,11},{-11,12},{-11,15},{-11,16},{-11,17},{-11,18},{-11,19},{-11,20},{-11,23},{-11,24},{-11,25},
            {-11,26},{-11,29},{-11,30},{-11,31},{-11,32},{-11,35},{-11,36},{-11,37},{-11,45},{-11,46},{-10,-44},{-10,-43},{-10,-42},{-10,-33},{-10,-32},{-10,-29},{-10,-28},{-10,-27},{-10,-26},{-10,-23},{-10,-22},{-10,-21},{-10,-20},{-10,-17},{-10,-16},{-10,-15},{-10,-14},{-10,-13},{-10,-12},{-10,-9},
            {-10,-8},{-10,-7},{-10,0},{-10,1},{-10,2},{-10,3},{-10,10},{-10,11},{-10,12},{-10,15},{-10,16},{-10,17},{-10,18},{-10,19},{-10,20},{-10,23},{-10,24},{-10,25},{-10,26},{-10,29},{-10,30},{-10,31},{-10,32},{-10,35},{-10,36},{-10,45},{-10,46},{-10,47},{-9,-45},{-9,-44},
            {-9,-43},{-9,-29},{-9,-28},{-9,-27},{-9,-23},{-9,-22},{-9,-21},{-9,-20},{-9,-17},{-9,-16},{-9,-15},{-9,-14},{-9,-13},{-9,-8},{-9,-7},{-9,-6},{-9,-5},{-9,-1},{-9,0},{-9,1},{-9,2},{-9,3},{-9,4},{-9,8},{-9,9},{-9,10},{-9,11},{-9,16},{-9,17},{-9,18},
            {-9,19},{-9,20},{-9,23},{-9,24},{-9,25},{-9,26},{-9,30},{-9,31},{-9,32},{-9,46},{-9,47},{-9,48},{-8,-45},{-8,-44},{-8,-30},{-8,-29},{-8,-28},{-8,-24},{-8,-23},{-8,-22},{-8,-21},{-8,-20},{-8,-17},{-8,-16},{-8,-15},{-8,-14},{-8,-7},{-8,-6},{-8,-5},{-8,-4},
            {-8,-1},{-8,0},{-8,1},{-8,2},{-8,3},{-8,4},{-8,7},{-8,8},{-8,9},{-8,10},{-8,17},{-8,18},{-8,19},{-8,20},{-8,23},{-8,24},{-8,25},{-8,26},{-8,27},{-8,31},{-8,32},{-8,33},{-8,47},{-8,48},{-7,-45},{-7,-44},{-7,-39},{-7,-38},{-7,-37},{-7,-36},
            {-7,-31},{-7,-30},{-7,-29},{-7,-25},{-7,-24},{-7,-23},{-7,-22},{-7,-21},{-7,-11},{-7,-10},{-7,-7},{-7,-6},{-7,-5},{-7,-4},{-7,7},{-7,8},{-7,9},{-7,10},{-7,13},{-7,14},{-7,24},{-7,25},{-7,26},{-7,27},{-7,28},{-7,32},{-7,33},{-7,34},{-7,39},{-7,40},
            {-7,41},{-7,42},{-7,47},{-7,48},{-6,-46},{-6,-45},{-6,-44},{-6,-39},{-6,-38},{-6,-37},{-6,-36},{-6,-35},{-6,-31},{-6,-30},{-6,-25},{-6,-24},{-6,-23},{-6,-22},{-6,-12},{-6,-11},{-6,-10},{-6,-6},{-6,-5},{-6,8},{-6,9},{-6,13},{-6,14},{-6,15},{-6,25},{-6,26},
            {-6,27},{-6,28},{-6,33},{-6,34},{-6,38},{-6,39},{-6,40},{-6,41},{-6,42},{-6,47},{-6,48},{-6,49},{-5,-47},{-5,-46},{-5,-45},{-5,-44},{-5,-37},{-5,-36},{-5,-35},{-5,-34},{-5,-19},{-5,-18},{-5,-13},{-5,-12},{-5,-11},{-5,-10},{-5,-1},{-5,0},{-5,1},{-5,2},
            {-5,3},{-5,4},{-5,13},{-5,14},{-5,15},{-5,16},{-5,21},{-5,22},{-5,37},{-5,38},{-5,39},{-5,40},{-5,47},{-5,48},{-5,49},{-5,50},{-4,-47},{-4,-46},{-4,-45},{-4,-44},{-4,-43},{-4,-37},{-4,-36},{-4,-35},{-4,-34},{-4,-19},{-4,-18},{-4,-17},{-4,-13},{-4,-12},
            {-4,-11},{-4,-10},{-4,-2},{-4,-1},{-4,0},{-4,1},{-4,2},{-4,3},{-4,4},{-4,5},{-4,13},{-4,14},{-4,15},{-4,16},{-4,20},{-4,21},{-4,22},{-4,37},{-4,38},{-4,39},{-4,40},{-4,46},{-4,47},{-4,48},{-4,49},{-4,50},{-3,-44},{-3,-43},{-3,-42},{-3,-41},
            {-3,-40},{-3,-37},{-3,-36},{-3,-35},{-3,-34},{-3,-31},{-3,-30},{-3,-29},{-3,-28},{-3,-25},{-3,-24},{-3,-23},{-3,-22},{-3,-18},{-3,-17},{-3,-16},{-3,-7},{-3,-6},{-3,-3},{-3,-2},{-3,-1},{-3,0},{-3,3},{-3,4},{-3,5},{-3,6},{-3,9},{-3,10},{-3,19},{-3,20},
            {-3,21},{-3,25},{-3,26},{-3,27},{-3,28},{-3,31},{-3,32},{-3,33},{-3,34},{-3,37},{-3,38},{-3,39},{-3,40},{-3,43},{-3,44},{-3,45},{-3,46},{-3,47},{-2,-43},{-2,-42},{-2,-41},{-2,-40},{-2,-37},{-2,-36},{-2,-35},{-2,-34},{-2,-31},{-2,-30},{-2,-29},{-2,-28},
            {-2,-25},{-2,-24},{-2,-23},{-2,-22},{-2,-21},{-2,-17},{-2,-16},{-2,-15},{-2,-8},{-2,-7},{-2,-6},{-2,-3},{-2,-2},{-2,-1},{-2,0},{-2,3},{-2,4},{-2,5},{-2,6},{-2,9},{-2,10},{-2,11},{-2,18},{-2,19},{-2,20},{-2,24},{-2,25},{-2,26},{-2,27},{-2,28},
            {-2,31},{-2,32},{-2,33},{-2,34},{-2,37},{-2,38},{-2,39},{-2,40},{-2,43},{-2,44},{-2,45},{-2,46},{-1,-47},{-1,-46},{-1,-43},{-1,-42},{-1,-41},{-1,-40},{-1,-37},{-1,-36},{-1,-29},{-1,-28},{-1,-25},{-1,-24},{-1,-23},{-1,-22},{-1,-21},{-1,-20},{-1,-17},{-1,-16},
            {-1,-15},{-1,-14},{-1,-13},{-1,-12},{-1,-9},{-1,-8},{-1,-7},{-1,-6},{-1,-3},{-1,-2},{-1,5},{-1,6},{-1,9},{-1,10},{-1,11},{-1,12},{-1,15},{-1,16},{-1,17},{-1,18},{-1,19},{-1,20},{-1,23},{-1,24},{-1,25},{-1,26},{-1,27},{-1,28},{-1,31},{-1,32},
            {-1,39},{-1,40},{-1,43},{-1,44},{-1,45},{-1,46},{-1,49},{-1,50},{0,-47},{0,-46},{0,-43},{0,-42},{0,-41},{0,-40},{0,-37},{0,-36},{0,-29},{0,-28},{0,-25},{0,-24},{0,-23},{0,-22},{0,-21},{0,-20},{0,-17},{0,-16},{0,-15},{0,-14},{0,-13},{0,-12},
            {0,-9},{0,-8},{0,-7},{0,-6},{0,-3},{0,-2},{0,5},{0,6},{0,9},{0,10},{0,11},{0,12},{0,15},{0,16},{0,17},{0,18},{0,19},{0,20},{0,23},{0,24},{0,25},{0,26},{0,27},{0,28},{0,31},{0,32},{0,39},{0,40},{0,43},{0,44},
            {0,45},{0,46},{0,49},{0,50},{1,-43},{1,-42},{1,-41},{1,-40},{1,-37},{1,-36},{1,-35},{1,-34},{1,-31},{1,-30},{1,-29},{1,-28},{1,-25},{1,-24},{1,-23},{1,-22},{1,-21},{1,-17},{1,-16},{1,-15},{1,-8},{1,-7},{1,-6},{1,-3},{1,-2},{1,-1},
            {1,0},{1,3},{1,4},{1,5},{1,6},{1,9},{1,10},{1,11},{1,18},{1,19},{1,20},{1,24},{1,25},{1,26},{1,27},{1,28},{1,31},{1,32},{1,33},{1,34},{1,37},{1,38},{1,39},{1,40},{1,43},{1,44},{1,45},{1,46},{2,-44},{2,-43},
            {2,-42},{2,-41},{2,-40},{2,-37},{2,-36},{2,-35},{2,-34},{2,-31},{2,-30},{2,-29},{2,-28},{2,-25},{2,-24},{2,-23},{2,-22},{2,-18},{2,-17},{2,-16},{2,-7},{2,-6},{2,-3},{2,-2},{2,-1},{2,0},{2,3},{2,4},{2,5},{2,6},{2,9},{2,10},
            {2,19},{2,20},{2,21},{2,25},{2,26},{2,27},{2,28},{2,31},{2,32},{2,33},{2,34},{2,37},{2,38},{2,39},{2,40},{2,43},{2,44},{2,45},{2,46},{2,47},{3,-47},{3,-46},{3,-45},{3,-44},{3,-43},{3,-37},{3,-36},{3,-35},{3,-34},{3,-19},
            {3,-18},{3,-17},{3,-13},{3,-12},{3,-11},{3,-10},{3,-2},{3,-1},{3,0},{3,1},{3,2},{3,3},{3,4},{3,5},{3,13},{3,14},{3,15},{3,16},{3,20},{3,21},{3,22},{3,37},{3,38},{3,39},{3,40},{3,46},{3,47},{3,48},{3,49},{3,50},
            {4,-47},{4,-46},{4,-45},{4,-44},{4,-37},{4,-36},{4,-35},{4,-34},{4,-19},{4,-18},{4,-13},{4,-12},{4,-11},{4,-10},{4,-1},{4,0},{4,1},{4,2},{4,3},{4,4},{4,13},{4,14},{4,15},{4,16},{4,21},{4,22},{4,37},{4,38},{4,39},{4,40},
            {4,47},{4,48},{4,49},{4,50},{5,-46},{5,-45},{5,-44},{5,-39},{5,-38},{5,-37},{5,-36},{5,-35},{5,-31},{5,-30},{5,-25},{5,-24},{5,-23},{5,-22},{5,-12},{5,-11},{5,-10},{5,-6},{5,-5},{5,8},{5,9},{5,13},{5,14},{5,15},{5,25},{5,26},
            {5,27},{5,28},{5,33},{5,34},{5,38},{5,39},{5,40},{5,41},{5,42},{5,47},{5,48},{5,49},{6,-45},{6,-44},{6,-39},{6,-38},{6,-37},{6,-36},{6,-31},{6,-30},{6,-29},{6,-25},{6,-24},{6,-23},{6,-22},{6,-21},{6,-11},{6,-10},{6,-7},{6,-6},
            {6,-5},{6,-4},{6,7},{6,8},{6,9},{6,10},{6,13},{6,14},{6,24},{6,25},{6,26},{6,27},{6,28},{6,32},{6,33},{6,34},{6,39},{6,40},{6,41},{6,42},{6,47},{6,48},{7,-45},{7,-44},{7,-30},{7,-29},{7,-28},{7,-24},{7,-23},{7,-22},
            {7,-21},{7,-20},{7,-17},{7,-16},{7,-15},{7,-14},{7,-7},{7,-6},{7,-5},{7,-4},{7,-1},{7,0},{7,1},{7,2},{7,3},{7,4},{7,7},{7,8},{7,9},{7,10},{7,17},{7,18},{7,19},{7,20},{7,23},{7,24},{7,25},{7,26},{7,27},{7,31},
            {7,32},{7,33},{7,47},{7,48},{8,-45},{8,-44},{8,-43},{8,-29},{8,-28},{8,-27},{8,-23},{8,-22},{8,-21},{8,-20},{8,-17},{8,-16},{8,-15},{8,-14},{8,-13},{8,-8},{8,-7},{8,-6},{8,-5},{8,-1},{8,0},{8,1},{8,2},{8,3},{8,4},{8,8},
            {8,9},{8,10},{8,11},{8,16},{8,17},{8,18},{8,19},{8,20},{8,23},{8,24},{8,25},{8,26},{8,30},{8,31},{8,32},{8,46},{8,47},{8,48},{9,-44},{9,-43},{9,-42},{9,-33},{9,-32},{9,-29},{9,-28},{9,-27},{9,-26},{9,-23},{9,-22},{9,-21},
            {9,-20},{9,-17},{9,-16},{9,-15},{9,-14},{9,-13},{9,-12},{9,-9},{9,-8},{9,-7},{9,0},{9,1},{9,2},{9,3},{9,10},{9,11},{9,12},{9,15},{9,16},{9,17},{9,18},{9,19},{9,20},{9,23},{9,24},{9,25},{9,26},{9,29},{9,30},{9,31},
            {9,32},{9,35},{9,36},{9,45},{9,46},{9,47},{10,-43},{10,-42},{10,-34},{10,-33},{10,-32},{10,-29},{10,-28},{10,-27},{10,-26},{10,-23},{10,-22},{10,-21},{10,-20},{10,-17},{10,-16},{10,-15},{10,-14},{10,-13},{10,-12},{10,-9},{10,-8},{10,1},{10,2},{10,11},
            {10,12},{10,15},{10,16},{10,17},{10,18},{10,19},{10,20},{10,23},{10,24},{10,25},{10,26},{10,29},{10,30},{10,31},{10,32},{10,35},{10,36},{10,37},{10,45},{10,46},{11,-39},{11,-38},{11,-35},{11,-34},{11,-33},{11,-32},{11,-29},{11,-28},{11,-27},{11,-16},
            {11,-15},{11,-14},{11,-13},{11,-5},{11,-4},{11,-3},{11,-2},{11,5},{11,6},{11,7},{11,8},{11,16},{11,17},{11,18},{11,19},{11,30},{11,31},{11,32},{11,35},{11,36},{11,37},{11,38},{11,41},{11,42},{12,-39},{12,-38},{12,-35},{12,-34},{12,-33},{12,-32},
            {12,-29},{12,-28},{12,-15},{12,-14},{12,-5},{12,-4},{12,-3},{12,-2},{12,5},{12,6},{12,7},{12,8},{12,17},{12,18},{12,31},{12,32},{12,35},{12,36},{12,37},{12,38},{12,41},{12,42},{13,-43},{13,-42},{13,-39},{13,-38},{13,-37},{13,-36},{13,-35},{13,-34},
            {13,-33},{13,-19},{13,-18},{13,-9},{13,-8},{13,-4},{13,-3},{13,-2},{13,1},{13,2},{13,5},{13,6},{13,7},{13,11},{13,12},{13,21},{13,22},{13,36},{13,37},{13,38},{13,39},{13,40},{13,41},{13,42},{13,45},{13,46},{14,-43},{14,-42},{14,-39},{14,-38},
            {14,-37},{14,-36},{14,-35},{14,-34},{14,-20},{14,-19},{14,-18},{14,-17},{14,-10},{14,-9},{14,-8},{14,-7},{14,-3},{14,-2},{14,1},{14,2},{14,5},{14,6},{14,10},{14,11},{14,12},{14,13},{14,20},{14,21},{14,22},{14,23},{14,37},{14,38},{14,39},{14,40},
            {14,41},{14,42},{14,45},{14,46},{15,-43},{15,-42},{15,-31},{15,-30},{15,-27},{15,-26},{15,-21},{15,-20},{15,-19},{15,-18},{15,-17},{15,-16},{15,-15},{15,-14},{15,-11},{15,-10},{15,-9},{15,-8},{15,-7},{15,-6},{15,1},{15,2},{15,9},{15,10},{15,11},{15,12},
            {15,13},{15,14},{15,17},{15,18},{15,19},{15,20},{15,21},{15,22},{15,23},{15,24},{15,29},{15,30},{15,33},{15,34},{15,45},{15,46},{16,-43},{16,-42},{16,-32},{16,-31},{16,-30},{16,-27},{16,-26},{16,-25},{16,-21},{16,-20},{16,-19},{16,-18},{16,-17},{16,-16},
            {16,-15},{16,-14},{16,-11},{16,-10},{16,-9},{16,-8},{16,-7},{16,-6},{16,0},{16,1},{16,2},{16,3},{16,9},{16,10},{16,11},{16,12},{16,13},{16,14},{16,17},{16,18},{16,19},{16,20},{16,21},{16,22},{16,23},{16,24},{16,28},{16,29},{16,30},{16,33},
            {16,34},{16,35},{16,45},{16,46},{17,-43},{17,-42},{17,-35},{17,-34},{17,-33},{17,-32},{17,-31},{17,-26},{17,-25},{17,-24},{17,-15},{17,-14},{17,-10},{17,-9},{17,-8},{17,-7},{17,-6},{17,-1},{17,0},{17,1},{17,2},{17,3},{17,4},{17,9},{17,10},{17,11},
            {17,12},{17,13},{17,17},{17,18},{17,27},{17,28},{17,29},{17,34},{17,35},{17,36},{17,37},{17,38},{17,45},{17,46},{18,-43},{18,-42},{18,-41},{18,-35},{18,-34},{18,-33},{18,-32},{18,-25},{18,-24},{18,-23},{18,-15},{18,-14},{18,-13},{18,-9},{18,-8},{18,-7},
            {18,-6},{18,-2},{18,-1},{18,0},{18,1},{18,2},{18,3},{18,4},{18,5},{18,9},{18,10},{18,11},{18,12},{18,16},{18,17},{18,18},{18,26},{18,27},{18,28},{18,35},{18,36},{18,37},{18,38},{18,44},{18,45},{18,46},{19,-42},{19,-41},{19,-40},{19,-39},
            {19,-38},{19,-29},{19,-28},{19,-25},{19,-24},{19,-23},{19,-22},{19,-21},{19,-20},{19,-19},{19,-18},{19,-15},{19,-14},{19,-13},{19,-12},{19,-3},{19,-2},{19,-1},{19,4},{19,5},{19,6},{19,15},{19,16},{19,17},{19,18},{19,21},{19,22},{19,23},{19,24},{19,25},
            {19,26},{19,27},{19,28},{19,31},{19,32},{19,41},{19,42},{19,43},{19,44},{19,45},{20,-41},{20,-40},{20,-39},{20,-38},{20,-37},{20,-29},{20,-28},{20,-25},{20,-24},{20,-23},{20,-22},{20,-21},{20,-20},{20,-19},{20,-18},{20,-15},{20,-14},{20,-13},{20,-12},{20,-3},
            {20,-2},{20,5},{20,6},{20,15},{20,16},{20,17},{20,18},{20,21},{20,22},{20,23},{20,24},{20,25},{20,26},{20,27},{20,28},{20,31},{20,32},{20,40},{20,41},{20,42},{20,43},{20,44},{21,-38},{21,-37},{21,-36},{21,-29},{21,-28},{21,-19},{21,-18},{21,-15},
            {21,-14},{21,-13},{21,-9},{21,-8},{21,-7},{21,-6},{21,1},{21,2},{21,9},{21,10},{21,11},{21,12},{21,16},{21,17},{21,18},{21,21},{21,22},{21,31},{21,32},{21,39},{21,40},{21,41},{22,-37},{22,-36},{22,-30},{22,-29},{22,-28},{22,-19},{22,-18},{22,-15},
            {22,-14},{22,-9},{22,-8},{22,-7},{22,-6},{22,-5},{22,0},{22,1},{22,2},{22,3},{22,8},{22,9},{22,10},{22,11},{22,12},{22,17},{22,18},{22,21},{22,22},{22,31},{22,32},{22,33},{22,39},{22,40},{23,-33},{23,-32},{23,-31},{23,-30},{23,-29},{23,-25},
            {23,-24},{23,-23},{23,-22},{23,-19},{23,-18},{23,-9},{23,-8},{23,-7},{23,-6},{23,-5},{23,-4},{23,-1},{23,0},{23,1},{23,2},{23,3},{23,4},{23,7},{23,8},{23,9},{23,10},{23,11},{23,12},{23,21},{23,22},{23,25},{23,26},{23,27},{23,28},{23,32},
            {23,33},{23,34},{23,35},{23,36},{24,-33},{24,-32},{24,-31},{24,-30},{24,-25},{24,-24},{24,-23},{24,-22},{24,-19},{24,-18},{24,-17},{24,-9},{24,-8},{24,-7},{24,-6},{24,-5},{24,-4},{24,-1},{24,0},{24,1},{24,2},{24,3},{24,4},{24,7},{24,8},{24,9},
            {24,10},{24,11},{24,12},{24,20},{24,21},{24,22},{24,25},{24,26},{24,27},{24,28},{24,33},{24,34},{24,35},{24,36},{25,-39},{25,-38},{25,-37},{25,-36},{25,-24},{25,-23},{25,-22},{25,-19},{25,-18},{25,-17},{25,-16},{25,-6},{25,-5},{25,-4},{25,-1},{25,0},
            {25,1},{25,2},{25,3},{25,4},{25,7},{25,8},{25,9},{25,19},{25,20},{25,21},{25,22},{25,25},{25,26},{25,27},{25,39},{25,40},{25,41},{25,42},{26,-39},{26,-38},{26,-37},{26,-36},{26,-23},{26,-22},{26,-19},{26,-18},{26,-17},{26,-16},{26,-15},{26,-5},
            {26,-4},{26,-1},{26,0},{26,1},{26,2},{26,3},{26,4},{26,7},{26,8},{26,18},{26,19},{26,20},{26,21},{26,22},{26,25},{26,26},{26,39},{26,40},{26,41},{26,42},{27,-38},{27,-37},{27,-36},{27,-29},{27,-28},{27,-27},{27,-26},{27,-16},{27,-15},{27,-14},
            {27,-9},{27,-8},{27,11},{27,12},{27,17},{27,18},{27,19},{27,29},{27,30},{27,31},{27,32},{27,39},{27,40},{27,41},{28,-37},{28,-36},{28,-30},{28,-29},{28,-28},{28,-27},{28,-26},{28,-15},{28,-14},{28,-10},{28,-9},{28,-8},{28,-7},{28,10},{28,11},{28,12},
            {28,13},{28,17},{28,18},{28,29},{28,30},{28,31},{28,32},{28,33},{28,39},{28,40},{29,-33},{29,-32},{29,-31},{29,-30},{29,-29},{29,-28},{29,-27},{29,-26},{29,-21},{29,-20},{29,-19},{29,-18},{29,-11},{29,-10},{29,-9},{29,-8},{29,-7},{29,-6},{29,-1},{29,0},
            {29,1},{29,2},{29,3},{29,4},{29,9},{29,10},{29,11},{29,12},{29,13},{29,14},{29,21},{29,22},{29,23},{29,24},{29,29},{29,30},{29,31},{29,32},{29,33},{29,34},{29,35},{29,36},{30,-33},{30,-32},{30,-31},{30,-30},{30,-29},{30,-28},{30,-27},{30,-26},
            {30,-22},{30,-21},{30,-20},{30,-19},{30,-18},{30,-11},{30,-10},{30,-9},{30,-8},{30,-7},{30,-6},{30,-5},{30,-1},{30,0},{30,1},{30,2},{30,3},{30,4},{30,8},{30,9},{30,10},{30,11},{30,12},{30,13},{30,14},{30,21},{30,22},{30,23},{30,24},{30,25},
            {30,29},{30,30},{30,31},{30,32},{30,33},{30,34},{30,35},{30,36},{31,-32},{31,-31},{31,-30},{31,-29},{31,-28},{31,-27},{31,-23},{31,-22},{31,-21},{31,-15},{31,-14},{31,-6},{31,-5},{31,-4},{31,-1},{31,0},{31,3},{31,4},{31,7},{31,8},{31,9},{31,17},
            {31,18},{31,24},{31,25},{31,26},{31,30},{31,31},{31,32},{31,33},{31,34},{31,35},{32,-31},{32,-30},{32,-29},{32,-28},{32,-23},{32,-22},{32,-16},{32,-15},{32,-14},{32,-5},{32,-4},{32,-1},{32,0},{32,3},{32,4},{32,7},{32,8},{32,17},{32,18},{32,19},
            {32,25},{32,26},{32,31},{32,32},{32,33},{32,34},{33,-30},{33,-29},{33,-28},{33,-23},{33,-22},{33,-17},{33,-16},{33,-15},{33,-11},{33,-10},{33,-9},{33,-8},{33,11},{33,12},{33,13},{33,14},{33,18},{33,19},{33,20},{33,25},{33,26},{33,31},{33,32},{33,33},
            {34,-29},{34,-28},{34,-23},{34,-22},{34,-17},{34,-16},{34,-12},{34,-11},{34,-10},{34,-9},{34,-8},{34,11},{34,12},{34,13},{34,14},{34,15},{34,19},{34,20},{34,25},{34,26},{34,31},{34,32},{35,-17},{35,-16},{35,-13},{35,-12},{35,-11},{35,-10},{35,-9},{35,-3},
            {35,-2},{35,-1},{35,0},{35,3},{35,4},{35,5},{35,6},{35,12},{35,13},{35,14},{35,15},{35,16},{35,19},{35,20},{36,-17},{36,-16},{36,-13},{36,-12},{36,-11},{36,-10},{36,-4},{36,-3},{36,-2},{36,-1},{36,0},{36,3},{36,4},{36,5},{36,6},{36,7},
            {36,13},{36,14},{36,15},{36,16},{36,19},{36,20},{37,-27},{37,-26},{37,-25},{37,-24},{37,-21},{37,-20},{37,-13},{37,-12},{37,-5},{37,-4},{37,-3},{37,-2},{37,-1},{37,0},{37,1},{37,2},{37,3},{37,4},{37,5},{37,6},{37,7},{37,8},{37,15},{37,16},
            {37,23},{37,24},{37,27},{37,28},{37,29},{37,30},{38,-27},{38,-26},{38,-25},{38,-24},{38,-21},{38,-20},{38,-19},{38,-13},{38,-12},{38,-5},{38,-4},{38,-3},{38,-2},{38,-1},{38,0},{38,1},{38,2},{38,3},{38,4},{38,5},{38,6},{38,7},{38,8},{38,15},
            {38,16},{38,22},{38,23},{38,24},{38,27},{38,28},{38,29},{38,30},{39,-26},{39,-25},{39,-24},{39,-20},{39,-19},{39,-18},{39,-13},{39,-12},{39,-11},{39,-10},{39,-5},{39,-4},{39,7},{39,8},{39,13},{39,14},{39,15},{39,16},{39,21},{39,22},{39,23},{39,27},
            {39,28},{39,29},{40,-25},{40,-24},{40,-19},{40,-18},{40,-13},{40,-12},{40,-11},{40,-10},{40,-5},{40,-4},{40,7},{40,8},{40,13},{40,14},{40,15},{40,16},{40,21},{40,22},{40,27},{40,28},{41,-19},{41,-18},{41,-1},{41,0},{41,1},{41,2},{41,3},{41,4},
            {41,21},{41,22},{42,-19},{42,-18},{42,-17},{42,-1},{42,0},{42,1},{42,2},{42,3},{42,4},{42,20},{42,21},{42,22},{43,-18},{43,-17},{43,-16},{43,-15},{43,-14},{43,-13},{43,-12},{43,-9},{43,-8},{43,-1},{43,0},{43,1},{43,2},{43,3},{43,4},{43,11},
            {43,12},{43,15},{43,16},{43,17},{43,18},{43,19},{43,20},{43,21},{44,-17},{44,-16},{44,-15},{44,-14},{44,-13},{44,-12},{44,-9},{44,-8},{44,-7},{44,-2},{44,-1},{44,0},{44,1},{44,2},{44,3},{44,4},{44,5},{44,10},{44,11},{44,12},{44,15},{44,16},
            {44,17},{44,18},{44,19},{44,20},{45,-8},{45,-7},{45,-6},{45,-5},{45,-4},{45,-3},{45,-2},{45,-1},{45,4},{45,5},{45,6},{45,7},{45,8},{45,9},{45,10},{45,11},{46,-7},{46,-6},{46,-5},{46,-4},{46,-3},{46,-2},{46,5},{46,6},{46,7},{46,8},
            {46,9},{46,10},{47,-4},{47,-3},{47,-2},{47,1},{47,2},{47,5},{47,6},{47,7},{48,-3},{48,-2},{48,1},{48,2},{48,5},{48,6}
        }
    },
    resource_tiles = {
        enabled = false,
        resources = {
            {
                enabled = false,
                name = "iron-ore",
                amount = 4000,
                size = {26, 27},
                offset = {-64,-32}
            },
            {
                enabled = false,
                name = "copper-ore",
                amount = 4000,
                size = {26, 27},
                offset = {-64, 0}
            },
            {
                enabled = false,
                name = "stone",
                amount = 4000,
                size = {22, 20},
                offset = {-64, 32}
            },
            {
                enabled = false,
                name = "coal",
                amount = 4000,
                size = {22, 20},
                offset = {-64, -64}
            },
            {
                enabled = false,
                name = "uranium-ore",
                amount = 4000,
                size = {22, 20},
                offset = {-64, -96}
            }
        }
    },
    resource_patches = {
        enabled = false,
        resources = {
            {
                enabled = true,
                name = "crude-oil",
                num_patches = 4,
                amount = 4000000,
                offset = {-80, -12},
                offset_next = {0, 6}
            }
        }
    },
    resource_refill = {
        enabled = false,
        range = 128,
        resources_name = {
            "iron-ore",
            "copper-ore",
            "stone",
            "coal",
            "uranium-ore"
        },
        amount = {2500, 4000}
    }
}