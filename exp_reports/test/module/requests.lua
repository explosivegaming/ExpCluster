local Suite = ... --- @type Suite<ExpReports.TestEnv>

Suite.test("create_report() sends the report to the controller", function(env)
    local alice = env.add_player("alice")
    local bob = env.add_player("bob")
    env.Reports.create_report(alice, bob, "griefing")
    Suite.eq(env.sent, {
        { channel = "exp_reports:create", data = { player_name = "bob", by_player_name = "alice", reason = "griefing" } },
    }, "the report names both players")
end)

Suite.test("list_reports() sends the caller and the player", function(env)
    local alice = env.add_player("alice")
    local bob = env.add_player("bob")
    env.Reports.list_reports(alice, bob)
    env.Reports.list_reports(alice)
    Suite.eq(env.sent, {
        { channel = "exp_reports:list", data = { caller = "alice", player_name = "bob" } },
        { channel = "exp_reports:list", data = { caller = "alice" } },
    }, "the player is left out when listing everyone")
end)

Suite.test("delete_reports() sends the caller, the player and the reporter", function(env)
    local alice = env.add_player("alice")
    local bob = env.add_player("bob")
    env.Reports.delete_reports(alice, bob, "carol")
    env.Reports.delete_reports(alice, bob)
    Suite.eq(env.sent, {
        { channel = "exp_reports:delete", data = { caller = "alice", player_name = "bob", by_player_name = "carol" } },
        { channel = "exp_reports:delete", data = { caller = "alice", player_name = "bob" } },
    }, "the reporter is left out when deleting every report")
end)

return Suite.run()
