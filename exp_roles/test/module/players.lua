--- Tests for the player checks of module/control.lua
local Suite = ... --- @type Suite<ExpRoles.TestEnv> The suite this file adds its tests to, see test/lua/framework.lua
local test, check, eq = Suite.test, Suite.check, Suite.eq

--- alice is a moderator, bob is a regular, and carol has only the default role
local function setup(env)
    local players = {
        alice = env.add_player{ name = "alice" },
        bob = env.add_player{ name = "bob" },
        carol = env.add_player{ name = "carol" },
    }
    env.initialise{
        env.assignment("alice", { "Moderator" }),
        env.assignment("bob", { "Regular" }),
    }
    return players
end

test("get_player_roles() includes the default role", function(env)
    local players = setup(env)
    eq(Suite.sorted(Suite.names(env.Roles.get_player_roles(players.alice))), { "Moderator", "Player" },
        "held roles and the default role")
    eq(Suite.names(env.Roles.get_player_roles(players.carol)), { "Player" },
        "a player with no roles has the default role")
end)

test("get_player_roles() treats nil and index 0 as the server", function(env)
    setup(env)
    eq(Suite.names(env.Roles.get_player_roles(nil)), { "<server>" }, "nil is the server")
    eq(Suite.names(env.Roles.get_player_roles(env.server)), { "<server>" }, "index 0 is the server")
    check(env.Roles.player_has_permission(nil, "anything.at.all"), "the server has every permission")
    check(not env.R("Player"):has_player(nil), "the server does not have the default role")
end)

test("get_player_highest_role() returns the most privileged role", function(env)
    local players = setup(env)
    check(env.Roles.get_player_highest_role(players.alice) == env.R("Moderator"), "the highest held role")
    check(env.Roles.get_player_highest_role(players.carol) == env.R("Player"), "the default role when none are held")
end)

test("get_player_highest_role() errors when a player has no roles", function(env)
    local players = setup(env)
    env.Roles.receive_role_updates{
        { id = env.R("Player").id, name = "Player", permissions = {}, meta = { id = 0, order = 5 }, is_deleted = true },
    }
    Suite.throws(function()
        env.Roles.get_player_highest_role(players.carol)
    end, "Player has no roles", "no default role and no held roles errors")
end)

test("player_has_permission()", function(env)
    local players = setup(env)
    check(env.Roles.player_has_permission(players.alice, "exp_scenario.command.kill"), "granted by a held role")
    check(env.Roles.player_has_permission(players.alice, "exp_scenario.gui.readme"), "granted by the default role")
    check(not env.Roles.player_has_permission(players.bob, "exp_scenario.command.jail"), "not granted")
end)

test("player_has_any_permission() and player_has_all_permission()", function(env)
    local players = setup(env)
    local jail, kill = "exp_scenario.command.jail", "exp_scenario.command.kill"
    check(env.Roles.player_has_any_permission(players.bob, jail, kill), "any passes when one is granted")
    check(not env.Roles.player_has_any_permission(players.bob, jail, "exp_scenario.command.assign_role"),
        "any fails when none are granted")
    check(not env.Roles.player_has_any_permission(players.bob), "any of none is false")
    check(env.Roles.player_has_all_permission(players.alice, jail, kill), "all passes when every one is granted")
    check(not env.Roles.player_has_all_permission(players.bob, jail, kill), "all fails when one is missing")
    check(env.Roles.player_has_all_permission(players.bob), "all of none is true")
    check(env.Roles.player_has_any_permission(nil, "anything.at.all"), "the server passes any")
    check(env.Roles.player_has_all_permission(nil, "anything.at.all", "and.this.too"), "the server passes all")
end)

test(".has_permission()", function(env)
    setup(env)
    check(env.R("Moderator"):has_permission("exp_scenario.command.kill"), "granted")
    check(not env.R("Regular"):has_permission("exp_scenario.command.jail"), "not granted")
    check(env.R("Cluster Admin"):has_permission("anything.at.all"), "core.admin grants everything")
end)

test(".has_player()", function(env)
    local players = setup(env)
    check(env.R("Moderator"):has_player(players.alice), "a held role")
    check(not env.R("Moderator"):has_player(players.bob), "a role not held")
    check(env.R("Player"):has_player(players.carol), "everyone has the default role")
end)

test("player_outranks()", function(env)
    local players = setup(env)
    check(env.Roles.player_outranks(players.alice, players.bob), "a higher role outranks a lower one")
    check(not env.Roles.player_outranks(players.bob, players.alice), "a lower role does not outrank a higher one")
    check(not env.Roles.player_outranks(players.alice, players.alice), "nobody outranks themselves")
    check(env.Roles.player_outranks(nil, players.alice), "the server outranks everyone")
    check(not env.Roles.player_outranks(players.alice, nil), "nobody outranks the server")
end)

return Suite.run()
