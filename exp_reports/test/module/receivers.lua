local Suite = ... --- @type Suite<ExpReports.TestEnv>

Suite.test("receive_created() tells everyone and raises on_player_reported", function(env)
    env.add_player("alice", true, true)
    local bob = env.add_player("bob")
    env.add_player("carol")
    local report = env.report("bob", "alice")
    env.Reports.receive_created{ report = report, reports = { report, env.report("bob", "carol") } }

    Suite.eq(env.printed, {
        { to = "alice", { "exp-reports.created-admin", "bob", "alice", "griefing" } },
        { to = "bob", { "exp-reports.created", "bob", "griefing" } },
        { to = "carol", { "exp-reports.created", "bob", "griefing" } },
    }, "admins see who reported, everyone else only the reason")
    Suite.eq(env.events, {
        {
            name = env.Reports.on_player_reported,
            tick = 1,
            player_index = bob.index,
            by_player_name = "alice",
            reason = "griefing",
            report_count = 2,
            by_player_names = { "alice", "carol" },
        },
    }, "the event carries every report against the player")
end)

Suite.test("receive_created() raises nothing when the reported player has left", function(env)
    env.add_player("alice")
    env.add_player("bob", false)
    local report = env.report("bob", "alice")
    env.Reports.receive_created{ report = report, reports = { report } }
    Suite.eq(env.printed, { { to = "alice", { "exp-reports.created", "bob", "griefing" } } }, "the report is still announced")
    Suite.empty(env.events, "there is nobody to act on")
end)

Suite.test("receive_list() prints the reports against a player to the caller", function(env)
    env.add_player("alice")
    env.Reports.receive_list{
        caller = "alice",
        player_name = "bob",
        reports = { env.report("bob", "carol", "spam"), env.report("bob", "dave", "griefing") },
    }
    Suite.eq(env.printed, {
        { to = "alice", { "exp-reports.list-title", "bob", 2 } },
        { to = "alice", { "exp-reports.list-entry", "carol", "spam" } },
        { to = "alice", { "exp-reports.list-entry", "dave", "griefing" } },
    }, "the title is followed by one line per report")
end)

Suite.test("receive_list() prints how many reports each player has", function(env)
    env.add_player("alice")
    env.Reports.receive_list{
        caller = "alice",
        reports = { env.report("dave", "alice"), env.report("bob", "carol"), env.report("dave", "carol") },
    }
    Suite.eq(env.printed, {
        { to = "alice", { "exp-reports.list-all-title" } },
        { to = "alice", { "exp-reports.list-all-entry", "bob", 1 } },
        { to = "alice", { "exp-reports.list-all-entry", "dave", 2 } },
    }, "players are listed by name with their count")
end)

Suite.test("receive_list() says when nobody is reported", function(env)
    env.add_player("alice")
    env.Reports.receive_list{ caller = "alice", reports = {} }
    Suite.eq(env.printed, { { to = "alice", { "exp-reports.list-all-none" } } }, "the caller is told there are none")
end)

Suite.test("receive_list() prints nothing once the caller has left", function(env)
    env.add_player("alice", false)
    env.Reports.receive_list{ caller = "alice", reports = { env.report("bob", "carol") } }
    Suite.empty(env.printed, "nothing is printed")
end)

Suite.test("receive_deleted() announces the deletion and raises on_reports_deleted", function(env)
    env.add_player("alice")
    local bob = env.add_player("bob")
    env.Reports.receive_deleted{ caller = "alice", player_name = "bob", count = 2 }
    Suite.eq(env.printed, { { "exp-reports.deleted", "bob", 2, "alice" } }, "everyone is told")
    Suite.eq(env.events, {
        { name = env.Reports.on_reports_deleted, tick = 1, player_index = bob.index, by_player_name = "alice", count = 2 },
    }, "the event names who deleted how many")
end)

Suite.test("receive_deleted() tells the caller when there was nothing to delete", function(env)
    env.add_player("alice")
    env.add_player("bob")
    env.Reports.receive_deleted{ caller = "alice", player_name = "bob", count = 0 }
    Suite.eq(env.printed, { { to = "alice", { "exp-reports.deleted-none", "bob" } } }, "only the caller is told")
    Suite.empty(env.events, "nothing was deleted")
end)

Suite.test("receive_error() prints the refusal to the caller while they are online", function(env)
    env.add_player("alice")
    env.add_player("bob", false)
    env.Reports.receive_error{ caller = "alice", message = "alice has already reported bob" }
    env.Reports.receive_error{ caller = "bob", message = "gone" }
    Suite.eq(env.printed, { { to = "alice", "alice has already reported bob" } }, "the offline player is skipped")
end)

return Suite.run()
