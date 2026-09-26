--- Tests for the assignment methods of module/control.lua
local Suite = ... --- @type Suite<ExpRoles.TestEnv> The suite this file adds its tests to, see env.lua
local test, check, eq, empty = Suite.test, Suite.check, Suite.eq, Suite.empty

--- alice is a moderator and bob a regular, with changes sent to the controller
local function setup(env)
    local players = {
        alice = env.add_player{ name = "alice" },
        bob = env.add_player{ name = "bob" },
    }
    env.initialise{
        env.assignment("alice", { "Moderator" }),
        env.assignment("bob", { "Regular" }),
    }
    env.Roles.set_emit_events(true)
    env.reset_log()
    return players
end

test(".assign() applies locally and is sent to the controller", function(env)
    local players = setup(env)
    local moderator = env.R("Moderator")
    moderator:assign(players.bob, { by_player_name = "alice" })
    eq(env.sent, {
        { channel = "exp_roles:assignment_update", data = { name = "bob", assign = { moderator.id } } },
    }, "the assignment is sent to the controller")
    check(moderator:has_player(players.bob), "the role applies before confirmation")
    eq(env.events, {
        {
            name = env.Roles.events.on_player_roles_changed,
            tick = 1,
            player_index = players.bob.index,
            by_player_index = players.alice.index,
            assigned = { moderator.id },
            unassigned = {},
        },
    }, "the event carries the change")
    eq(env.printed, {
        { "exp-roles.game-message-assign", "bob", "Moderator", "alice" },
    }, "the change is announced")
    eq(env.sounds, { "bob:utility/achievement_unlocked" }, "the assign sound plays")

    local sd = env.script_data()
    eq(sd.local_players.bob, { moderator.id }, "the role is held locally")
    eq(sd.pending.bob, { moderator.id }, "the role is pending")

    env.reset_log()
    moderator:assign(players.bob)
    empty(env.sent, "assigning a held role sends nothing")
    empty(env.events, "assigning a held role raises nothing")
end)

test(".assign() defaults the by player to game.player", function(env)
    local players = setup(env)
    game.player = players.alice
    env.R("Jail"):assign(players.bob, { silent = true })
    eq(env.events, {
        {
            name = env.Roles.events.on_player_roles_changed,
            tick = 1,
            player_index = players.bob.index,
            by_player_index = players.alice.index,
            assigned = { env.R("Jail").id },
            unassigned = {},
        },
    }, "the acting player is game.player")
end)

test("receive_assignment_updates() releases the local hold once confirmed", function(env)
    local players = setup(env)
    env.R("Moderator"):assign(players.bob)
    env.reset_log()
    env.Roles.receive_assignment_updates{ env.assignment("bob", { "Regular", "Moderator" }) }
    empty(env.events, "a confirmation raises no events")
    empty(env.printed, "a confirmation announces nothing")

    local sd = env.script_data()
    check(sd.local_players.bob == nil and sd.pending.bob == nil, "the role is no longer held locally")
    check(env.R("Moderator"):has_player(players.bob), "the role is still held after confirmation")
end)

test(".unassign() removes a synced role", function(env)
    local players = setup(env)
    local regular = env.R("Regular")
    regular:unassign(players.bob, { by_player_name = "alice", silent = true })
    eq(env.sent, {
        { channel = "exp_roles:assignment_update", data = { name = "bob", unassign = { regular.id } } },
    }, "the unassignment is sent to the controller")
    check(not regular:has_player(players.bob), "the role is removed locally")
    eq(env.events, {
        {
            name = env.Roles.events.on_player_roles_changed,
            tick = 1,
            player_index = players.bob.index,
            by_player_index = players.alice.index,
            assigned = {},
            unassigned = { regular.id },
        },
    }, "the event carries the change")
    empty(env.printed, "silent suppresses the announcement")
    eq(env.sounds, { "bob:utility/game_lost" }, "the unassign sound plays")
end)

test("reject_assignment() rolls the assignment back", function(env)
    local players = setup(env)
    local jail = env.R("Jail")
    jail:assign(players.alice)
    check(jail:has_player(players.alice), "the role applies before rejection")

    env.reset_log()
    env.Roles.reject_assignment{ name = "alice", role_ids = { jail.id } }
    check(not jail:has_player(players.alice), "the rejected role is rolled back")
    empty(env.sent, "the rollback is not sent to the controller")
    eq(env.events, {
        {
            name = env.Roles.events.on_player_roles_changed,
            tick = 1,
            player_index = players.alice.index,
            by_player_index = 0,
            assigned = {},
            unassigned = { jail.id },
        },
    }, "the rollback raises the event")

    local sd = env.script_data()
    check(sd.local_players.alice == nil and sd.pending.alice == nil, "the rollback clears the local state")
end)

test(".assign() with local_only never reaches the controller", function(env)
    local players = setup(env)
    local regular = env.R("Regular")
    regular:assign(players.alice, { silent = true, local_only = true })
    empty(env.sent, "the assignment is not sent")
    check(regular:has_player(players.alice), "the role applies")

    local sd = env.script_data()
    check(sd.pending.alice == nil, "the role is not pending")
    eq(sd.local_players.alice, { regular.id }, "the role is held locally")

    env.Roles.receive_assignment_updates{ env.assignment("alice", { "Moderator" }) }
    check(regular:has_player(players.alice), "the role survives controller updates")

    env.reset_log()
    regular:unassign(players.alice, { local_only = true })
    check(not regular:has_player(players.alice), "the role is removed")
    empty(env.sent, "the removal is not sent")
end)

test(".assign() of a higher priority role suppresses the rest", function(env)
    local players = setup(env)
    local jail = env.R("Jail")
    jail:assign(players.alice, { by_player_name = "<server>", silent = true })
    eq(Suite.names(env.Roles.get_player_roles(players.alice)), { "Jail" }, "only the jail role applies")
    check(env.R("Moderator"):has_player(players.alice), "a suppressed role is still held")
    check(not env.Roles.player_has_permission(players.alice, "exp_scenario.command.kill"), "permissions are lost")
    check(not env.Roles.player_has_permission(players.alice, "exp_scenario.gui.readme"), "the default role is lost")
    check(not env.Roles.player_outranks(players.alice, players.bob), "a jailed player no longer outranks")
    eq(env.events, {
        {
            name = env.Roles.events.on_player_roles_changed,
            tick = 1,
            player_index = players.alice.index,
            by_player_index = 0,
            assigned = { jail.id },
            unassigned = {},
        },
    }, "the event lists only the jail role")

    env.reset_log()
    jail:unassign(players.alice, { by_player_name = "<server>", silent = true })
    eq(Suite.sorted(Suite.names(env.Roles.get_player_roles(players.alice))), { "Moderator", "Player" },
        "unjail restores the roles")
    eq(env.events, {
        {
            name = env.Roles.events.on_player_roles_changed,
            tick = 1,
            player_index = players.alice.index,
            by_player_index = 0,
            assigned = {},
            unassigned = { jail.id },
        },
    }, "the unjail event lists only the jail role")
end)

test(".assign() ignores the server", function(env)
    setup(env)
    env.R("Moderator"):assign(env.server)
    empty(env.sent, "assigning to the server sends nothing")
    empty(env.events, "assigning to the server raises nothing")
end)

return Suite.run()
