local Suite = ... --- @type Suite<ExpPlayerStatistics.TestEnv>

Suite.test("increment() adds to the unsent statistics", function(env)
    local Stats = env.Statistics
    local alice = env.add_player{ name = "alice" }
    Stats.increment(alice, "Kills")
    Stats.increment(alice, "Kills", 4)
    Suite.eq(Stats.get(alice, "Kills"), 5, "by one, then by the amount")
    Suite.eq(Stats.get("alice", "Kills"), 5, "by player name")
    Suite.eq(Stats.get(alice, "Deaths"), 0, "missing statistics are zero")
end)

Suite.test("send_all() sends every player with changes in one update", function(env)
    local Stats = env.Statistics
    local alice = env.add_player{ name = "alice" }
    local bob = env.add_player{ name = "bob" }
    env.add_player{ name = "carol" }
    Stats.increment(alice, "Kills", 2)
    Stats.increment(bob, "Deaths")
    Stats.send_all()

    Suite.eq(#env.sent, 1, "one update")
    Suite.eq(assert(env.sent[1]).channel, "exp_player_statistics:update", "on the update channel")
    local players = assert(env.sent[1]).data.players
    table.sort(players, function(a, b) return a.name < b.name end)
    Suite.eq(players, {
        { name = "alice", stats = { Kills = 2 } },
        { name = "bob", stats = { Deaths = 1 } },
    }, "players without changes are left out")
end)

Suite.test("sending clears the unsent statistics but keeps the total", function(env)
    local Stats = env.Statistics
    local alice = env.add_player{ name = "alice" }
    Stats.increment(alice, "Kills", 2)
    Stats.send_all()
    Suite.eq(Stats.get(alice, "Kills"), 2, "moved into the totals")

    env.reset_log()
    Stats.send_all()
    Suite.empty(env.sent, "nothing is sent twice")

    Stats.increment(alice, "Kills")
    Stats.send_all()
    Suite.eq(assert(env.sent[1]).data.players, { { name = "alice", stats = { Kills = 1 } } }, "only the new delta is sent")
    Suite.eq(Stats.get(alice, "Kills"), 3, "the total includes it")
end)

Suite.test("send() sends one player", function(env)
    local Stats = env.Statistics
    local alice = env.add_player{ name = "alice" }
    local bob = env.add_player{ name = "bob" }
    Stats.increment(alice, "Kills")
    Stats.increment(bob, "Kills")
    Stats.send("alice")
    Suite.eq(env.sent, { { channel = "exp_player_statistics:update", data = { players = { { name = "alice", stats = { Kills = 1 } } } } } }, "only that player")

    env.reset_log()
    Stats.send("carol")
    Suite.empty(env.sent, "nothing is sent for a player without changes")
end)

Suite.test("receive_totals() adds the unsent statistics to the totals", function(env)
    local Stats = env.Statistics
    local alice = env.add_player{ name = "alice" }
    Stats.increment(alice, "Kills", 2)
    Stats.receive_totals{ name = "alice", stats = { Kills = 10, Deaths = 1 } }
    Suite.eq(Stats.get(alice, "Kills"), 12, "received plus unsent")
    Suite.eq(Stats.get(alice, "Deaths"), 1, "received only")

    Stats.send_all()
    Suite.eq(assert(env.sent[1]).data.players[1].stats, { Kills = 2 }, "the received totals are not sent back")
    Suite.eq(Stats.get(alice, "Kills"), 12, "the total is unchanged by sending")
end)

Suite.test("receive_totals() ignores players who are not online", function(env)
    local Stats = env.Statistics
    env.add_player{ name = "bob", connected = false }
    Stats.receive_totals{ name = "bob", stats = { Kills = 10 } }
    Stats.receive_totals{ name = "nobody", stats = { Kills = 10 } }
    Suite.eq(Stats.get("bob", "Kills"), 0, "offline")
    Suite.eq(Stats.get("nobody", "Kills"), 0, "never joined")
end)

Suite.test("send_and_forget() sends then drops the totals", function(env)
    local Stats = env.Statistics
    local alice = env.add_player{ name = "alice" }
    Stats.receive_totals{ name = "alice", stats = { Kills = 10 } }
    Stats.increment(alice, "Kills")
    Stats.send_and_forget("alice")
    Suite.eq(assert(env.sent[1]).data.players[1].stats, { Kills = 1 }, "the unsent delta is sent")
    Suite.eq(Stats.get(alice, "Kills"), 0, "nothing is kept")
end)

Suite.test("discard_unsent() drops what was not sent", function(env)
    local Stats = env.Statistics
    local alice = env.add_player{ name = "alice" }
    Stats.receive_totals{ name = "alice", stats = { Kills = 10 } }
    Stats.increment(alice, "Kills")
    Stats.discard_unsent()
    Suite.eq(Stats.get(alice, "Kills"), 10, "only the totals remain")
    Stats.send_all()
    Suite.empty(env.sent, "nothing to send")
end)

Suite.test("format() shows times and numbers", function(env)
    local Stats = env.Statistics
    Suite.eq(Stats.format("Playtime", 90), { "time-long", 90 }, "long time")
    Suite.eq(Stats.format("AfkTime", 90, true), { "time-short", 90 }, "short time")
    Suite.eq(Stats.format("Kills", 7), "7", "number")
    Suite.eq(Stats.units.DistanceTravelled, " tiles", "distance has a unit")
end)

Suite.test("display_order lists every enabled statistic", function(env)
    local order = env.Statistics.display_order
    Suite.eq(#order, 24, "all enabled by default")
    Suite.eq(order[1], "Playtime", "in the configured order")
end)

return Suite.run()
