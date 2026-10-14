--[[-- ExpPlayerStatistics - Config
The counted statistics and the order statistics are shown in.
Playtime and JoinCount come from the clusterio user, not from here.
]]

local e = defines.events
return {
    --- Statistics that go up by one each time the event is raised for a player
    --- @type table<string, defines.events>
    counters = {
        MachinesBuilt = e.on_built_entity,
        MapTagsMade = e.on_chart_tag_added,
        ChatMessages = e.on_console_chat,
        CommandsUsed = e.on_console_command,
        ItemsPickedUp = e.on_picked_up_item,
        TilesBuilt = e.on_player_built_tile,
        ItemsCrafted = e.on_player_crafted_item,
        DeconstructionPlannerUsed = e.on_player_deconstructed_area,
        Deaths = e.on_player_died,
        TilesRemoved = e.on_player_mined_tile,
        CapsulesUsed = e.on_player_used_capsule,
        EntityRepaired = e.on_player_repaired_entity,
    },
    --- The order statistics are shown in
    display_order = {
        "Playtime", "AfkTime",
        "MapsPlayed", "JoinCount",
        "ChatMessages", "CommandsUsed",
        "RocketsLaunched", "ResearchCompleted",
        "MachinesBuilt", "MachinesRemoved",
        "TilesBuilt", "TilesRemoved",
        "TreesDestroyed", "OreMined",
        "ItemsCrafted", "ItemsPickedUp",
        "Kills", "Deaths",
        "DamageDealt", "DistanceTravelled",
        "CapsulesUsed", "EntityRepaired",
        "DeconstructionPlannerUsed", "MapTagsMade",
    },
}
