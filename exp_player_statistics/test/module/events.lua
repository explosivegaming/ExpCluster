local Suite = ... --- @type Suite<ExpPlayerStatistics.TestEnv>

Suite.test("counters go up by one for online players", function(env)
    local Stats = env.Statistics
    local alice = env.add_player{ name = "alice" }
    local bob = env.add_player{ name = "bob", connected = false }
    env.raise("on_console_chat", { player_index = alice.index })
    env.raise("on_console_chat", { player_index = alice.index })
    env.raise("on_player_died", { player_index = alice.index })
    env.raise("on_console_chat", { player_index = bob.index })
    env.raise("on_console_chat", {})

    Suite.eq(Stats.get(alice, "ChatMessages"), 2, "chat")
    Suite.eq(Stats.get(alice, "Deaths"), 1, "deaths")
    Suite.eq(Stats.get(bob, "ChatMessages"), 0, "offline players are skipped")
end)

Suite.test("a player is counted once per map", function(env)
    local alice = env.add_player{ name = "alice" }
    env.raise("on_player_created", { player_index = alice.index })
    Suite.eq(env.Statistics.get(alice, "MapsPlayed"), 1, "maps played")
end)

Suite.test("afk time goes up each minute, playtime comes from clusterio", function(env)
    local Stats = env.Statistics
    local alice = env.add_player{ name = "alice" }
    local bob = env.add_player{ name = "bob", afk_time = 6 * 3600 }
    local tick = env.handlers.on_nth_tick[3600]
    game.tick = 3600
    tick()
    tick()

    Suite.eq(Stats.get(alice, "Playtime"), 0, "playtime is not counted")
    Suite.eq(Stats.get(alice, "AfkTime"), 0, "not afk")
    Suite.eq(Stats.get(bob, "AfkTime"), 2, "afk")
end)

Suite.test("distance is not counted while afk", function(env)
    local Stats = env.Statistics
    local alice = env.add_player{ name = "alice" }
    local bob = env.add_player{ name = "bob", afk_time = 6 * 3600 }
    env.raise("on_player_changed_position", { player_index = alice.index })
    env.raise("on_player_changed_position", { player_index = bob.index })
    Suite.eq(Stats.get(alice, "DistanceTravelled"), 1, "moving")
    Suite.eq(Stats.get(bob, "DistanceTravelled"), 0, "afk")
end)

Suite.test("removed entities count as ore, trees or machines", function(env)
    local Stats = env.Statistics
    local alice = env.add_player{ name = "alice" }
    local function entity(type, force)
        return { valid = true, type = type, force = force or env.force("neutral") }
    end
    env.raise("on_player_mined_entity", { player_index = alice.index, entity = entity("resource") })
    env.raise("on_marked_for_deconstruction", { player_index = alice.index, entity = entity("tree") })
    env.raise("on_player_mined_entity", { player_index = alice.index, entity = entity("assembling-machine", alice.force) })
    env.raise("on_player_mined_entity", { player_index = alice.index, entity = entity("assembling-machine", env.force("enemy")) })
    env.raise("on_marked_for_deconstruction", { entity = entity("tree") })

    Suite.eq(Stats.get(alice, "OreMined"), 1, "ore")
    Suite.eq(Stats.get(alice, "TreesDestroyed"), 1, "trees, by players only")
    Suite.eq(Stats.get(alice, "MachinesRemoved"), 1, "own force only")
end)

Suite.test("damage and kills count against hostile entities", function(env)
    local Stats = env.Statistics
    local alice = env.add_player{ name = "alice" }
    local character = { valid = true, type = "character", object_name = "LuaEntity", player = alice }
    local enemy = { valid = true, force = env.force("enemy") }
    local ally = { valid = true, force = alice.force }
    env.raise("on_entity_damaged", { cause = character, entity = enemy, final_damage_amount = 12.7 })
    env.raise("on_entity_damaged", { cause = character, entity = ally, final_damage_amount = 5 })
    env.raise("on_entity_died", { cause = character, entity = enemy })
    env.raise("on_entity_died", { entity = enemy })

    Suite.eq(Stats.get(alice, "DamageDealt"), 12, "damage is floored, allies are skipped")
    Suite.eq(Stats.get(alice, "Kills"), 1, "kills without a cause are skipped")
end)

Suite.test("vehicles credit their driver", function(env)
    local Stats = env.Statistics
    local alice = env.add_player{ name = "alice" }
    local enemy = { valid = true, force = env.force("enemy") }
    local car = {
        valid = true, type = "car",
        get_driver = function() return alice end,
        get_passenger = function() return nil end,
    }
    local empty_train = {
        valid = true, type = "locomotive",
        get_driver = function() return nil end,
        get_passenger = function() return nil end,
    }
    env.raise("on_entity_died", { cause = car, entity = enemy })
    env.raise("on_entity_died", { cause = empty_train, entity = enemy })
    Suite.eq(Stats.get(alice, "Kills"), 1, "the driver, not the empty train")
end)

Suite.test("rockets and research count for every online player on the force", function(env)
    local Stats = env.Statistics
    local alice = env.add_player{ name = "alice" }
    local bob = env.add_player{ name = "bob" }
    local carol = env.add_player{ name = "carol", force = "other" }
    env.raise("on_rocket_launched", { rocket_silo = { valid = true, force = alice.force } })
    env.raise("on_research_finished", { research = { valid = true, force = alice.force } })
    env.raise("on_research_finished", { by_script = true, research = { valid = true, force = alice.force } })

    Suite.eq({ Stats.get(alice, "RocketsLaunched"), Stats.get(bob, "RocketsLaunched") }, { 1, 1 }, "rockets")
    Suite.eq(Stats.get(alice, "ResearchCompleted"), 1, "research by script is skipped")
    Suite.eq(Stats.get(carol, "RocketsLaunched"), 0, "other forces are skipped")
end)

Suite.test("leaving sends the player and forgets them", function(env)
    local Stats = env.Statistics
    local alice = env.add_player{ name = "alice" }
    local bob = env.add_player{ name = "bob" }
    Stats.increment(alice, "Kills")
    Stats.increment(bob, "Kills")
    env.raise("on_player_left_game", { player_index = alice.index })

    Suite.eq(assert(env.sent[1]).data.players, { { name = "alice", stats = { Kills = 1 } } }, "only the player leaving")
    Suite.eq(Stats.get(alice, "Kills"), 0, "forgotten")
    Suite.eq(Stats.get(bob, "Kills"), 1, "others are kept")
end)

Suite.test("everyone is sent every 5 minutes", function(env)
    local alice = env.add_player{ name = "alice" }
    env.Statistics.increment(alice, "Kills")
    env.handlers.on_nth_tick[5 * 3600]()
    Suite.eq(#env.sent, 1, "one update")
end)

return Suite.run()
