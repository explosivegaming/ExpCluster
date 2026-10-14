--[[-- ExpStatistics - Config
Which statistics are tracked, and the order they are shown in.
]]

local e = defines.events
return {
    MapsPlayed = true, -- Maps a player has joined at least once
    Playtime = true, -- Minutes online
    AfkTime = true, -- Minutes online after doing nothing for 5 minutes
    DistanceTravelled = true, -- Tiles moved while not afk
    MachinesRemoved = true, -- Own force entities marked for deconstruction or mined
    TreesDestroyed = true, -- Trees marked for deconstruction or mined
    OreMined = true, -- Resources mined by hand
    DamageDealt = true, -- Damage to entities not on the same force or neutral
    Kills = true, -- Entities killed which are not on the same force or neutral
    RocketsLaunched = true, -- Counted for every online player on the force
    ResearchCompleted = true, -- Counted for every online player on the force
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
        JoinCount = e.on_player_joined_game,
        TilesRemoved = e.on_player_mined_tile,
        CapsulesUsed = e.on_player_used_capsule,
        EntityRepaired = e.on_player_repaired_entity,
    },
    --- The order statistics are shown in, disabled ones are skipped
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
