--- Tests for the sync entry points of module/control.lua
local Suite = ... --- @type Suite<ExpRoles.TestEnv> The suite this file adds its tests to, see test/lua/framework.lua
local test, check, eq, empty = Suite.test, Suite.check, Suite.eq, Suite.empty

--- The state given by the admin trigger, reset by setup for every test
local admin_state = {} --- @type table<string, boolean>

--- alice is a moderator and carol has only the default role, both connected
local function setup(env)
    local players = {
        alice = env.add_player{ name = "alice" },
        carol = env.add_player{ name = "carol" },
    }
    admin_state = {}
    env.Roles.define_permission_trigger("exp_scenario.player.admin", function(player, state)
        admin_state[player.name] = state
    end)
    env.initialise{
        env.assignment("alice", { "Moderator" }),
        env.assignment("zed", { "Moderator", "Regular" }), -- has never joined this map
    }
    env.Roles.set_emit_events(true)
    return players
end

test("initialise() applies triggers and raises empty events", function(env)
    setup(env)
    eq(admin_state, { alice = true, carol = false }, "triggers run for connected players")
    eq(#env.events, 2, "the event is raised once per connected player")
    for _, event in ipairs(env.events) do
        empty(event.assigned, "the events assign nothing")
        empty(event.unassigned, "the events unassign nothing")
    end
    empty(env.printed, "initialise is silent")
    empty(env.sent, "initialise sends nothing")
    empty(env.sounds, "initialise plays no sounds")
end)

test("initialise() skips deleted assignments", function(env)
    local players = setup(env)
    local record = env.assignment("carol", { "Moderator" })
    record.is_deleted = true
    env.initialise{ record }
    check(not env.R("Moderator"):has_player(players.carol), "a deleted assignment is ignored")
end)

test("initialise() is authoritative for pending roles", function(env)
    local players = setup(env)
    env.R("Moderator"):assign(players.carol)
    env.R("Jail"):assign(players.carol, { silent = true, local_only = true })

    local sd = env.script_data()
    eq(sd.pending.carol, { env.R("Moderator").id }, "the role is pending before initialise")

    env.reset_log()
    env.initialise{ env.assignment("alice", { "Moderator" }) }
    eq(sd.pending.carol, nil, "pending roles are cleared")
    check(not env.R("Moderator"):has_player(players.carol), "an unconfirmed role is given up")
    eq(sd.local_players.carol, { env.R("Jail").id }, "local only roles are kept")
    empty(env.sent, "initialise sends nothing")
end)

test("receive_assignment_updates() applies controller changes", function(env)
    local players = setup(env)
    env.reset_log()
    env.Roles.receive_assignment_updates{ env.assignment("carol", { "Moderator" }) }
    check(env.R("Moderator"):has_player(players.carol), "the assignment applies")
    eq(env.events, {
        {
            name = env.Roles.events.on_player_roles_changed,
            tick = 1,
            player_index = players.carol.index,
            by_player_index = 0,
            assigned = { env.R("Moderator").id },
            unassigned = {},
        },
    }, "the event carries the change with no by player")
    eq(env.printed, {
        { "exp-roles.game-message-assign", "carol", "Moderator", "<server>" },
    }, "the change is announced by the server")
    check(admin_state.carol == true, "triggers follow the assignment")

    env.reset_log()
    env.Roles.receive_assignment_updates{ { name = "carol", role_ids = {}, is_deleted = true } }
    check(not env.R("Moderator"):has_player(players.carol), "a removal applies")
    eq(env.events, {
        {
            name = env.Roles.events.on_player_roles_changed,
            tick = 1,
            player_index = players.carol.index,
            by_player_index = 0,
            assigned = {},
            unassigned = { env.R("Moderator").id },
        },
    }, "the removal raises the event")
    check(admin_state.carol == false, "triggers follow the removal")
end)

test("receive_assignment_updates() for players not on this map raises nothing", function(env)
    setup(env)
    env.reset_log()
    env.Roles.receive_assignment_updates{ env.assignment("zed", { "Moderator" }) }
    empty(env.events, "no event is raised")
    empty(env.printed, "nothing is announced")
end)

test("receive_role_updates() applies to the holders", function(env)
    setup(env)
    env.reset_log()
    local regular_id = env.R("Regular").id
    env.Roles.receive_role_updates{
        { id = regular_id, name = "Regular", permissions = { "exp_scenario.command.jail" }, meta = { id = 0, order = 3 } },
    }
    check(env.R("Regular"):has_permission("exp_scenario.command.jail"), "the permission change applies")
    eq(#env.events, 2, "a role change raises for every connected player")
    for _, event in ipairs(env.events) do
        empty(event.assigned, "role change events are empty")
    end

    env.Roles.receive_role_updates{
        { id = regular_id, name = "Regular", permissions = {}, meta = { id = 0, order = 3 }, is_deleted = true },
    }
    eq(env.Roles.get_role(regular_id), nil, "a deleted role is removed")
end)

test("receive_role_updates() moves the default role", function(env)
    local players = setup(env)
    env.Roles.receive_role_updates{
        { id = env.R("Player").id, name = "Player", permissions = {}, meta = { id = 0, order = 5 } },
        { id = 8, name = "Guest", permissions = {}, meta = { id = 0, order = 7 }, is_default = true },
    }
    check(env.Roles.get_default_role() == env.R("Guest"), "the new default role is known")
    eq(Suite.names(env.Roles.get_player_roles(players.carol)), { "Guest" }, "players pick up the new default")
end)

test("set_emit_events() gates what is sent and defaults to enabled", function(env)
    local players = setup(env)
    env.Roles.set_emit_events(false)
    env.reset_log()
    env.R("Regular"):assign(players.alice)
    empty(env.sent, "nothing is sent while disabled")
    check(env.R("Regular"):has_player(players.alice), "the assignment still applies locally")

    env.Roles.set_emit_events()
    env.R("Jail"):assign(players.alice, { silent = true })
    eq(env.sent, {
        { channel = "exp_roles:assignment_update", data = { name = "alice", assign = { env.R("Jail").id } } },
    }, "no argument enables sending")
end)

test("on_load() restores the state after a save and load", function(env)
    local players = setup(env)
    env.R("Jail"):assign(players.carol, { silent = true, local_only = true })
    env.save_load()
    env.Roles.on_load()

    check(env.R("Moderator"):is_higher_than(env.R("Regular")), "role methods survive through the registered metatable")
    check(env.R("Moderator"):has_player(players.alice), "synced roles survive")
    check(env.R("Jail"):has_player(players.carol), "local roles survive")
    check(env.Roles.player_has_permission(players.alice, "exp_scenario.command.kill"), "permission checks still answer")
end)

test("on_player_joined_game() runs the triggers", function(env)
    local players = setup(env)
    admin_state.alice = nil
    env.Roles.on_player_joined_game{
        name = defines.events.on_player_joined_game,
        tick = game.tick,
        player_index = players.alice.index,
    }
    check(admin_state.alice ~= nil, "triggers run when a player joins")
end)

return Suite.run()
