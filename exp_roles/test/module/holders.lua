--- Tests for listing and printing to the players who hold a role
local Suite = ... --- @type Suite<ExpRoles.TestEnv> The suite this file adds its tests to, see test/lua/framework.lua
local test, check, eq = Suite.test, Suite.check, Suite.eq

--- alice and dave are moderators with dave offline, zed has never joined
local function setup(env)
    local players = {
        alice = env.add_player{ name = "alice" },
        bob = env.add_player{ name = "bob" },
        dave = env.add_player{ name = "dave", connected = false },
    }
    env.initialise{
        env.assignment("alice", { "Moderator" }),
        env.assignment("bob", { "Regular" }),
        env.assignment("dave", { "Moderator" }),
        env.assignment("zed", { "Moderator" }),
    }
    env.Roles.set_emit_events(true)
    return players
end

test(".get_player_names() includes players not on this map", function(env)
    setup(env)
    eq(Suite.sorted(env.R("Moderator"):get_player_names()), { "alice", "dave", "zed" },
        "every player given the role is listed")
end)

test(".get_player_names() counts a player in both lists once", function(env)
    local players = setup(env)
    env.R("Regular"):assign(players.alice, { silent = true, local_only = true })
    env.Roles.receive_assignment_updates{ env.assignment("alice", { "Moderator", "Regular" }) }

    local sd = env.script_data()
    check(sd.local_players.alice ~= nil and sd.synced_players.alice ~= nil, "the role is held in both lists")
    eq(Suite.sorted(env.R("Regular"):get_player_names()), { "alice", "bob" }, "the player is counted once")
end)

test(".get_players() is limited to this map and can be filtered", function(env)
    setup(env)
    local moderator = env.R("Moderator")
    eq(Suite.sorted(Suite.names(moderator:get_players())), { "alice", "dave" }, "players are limited to this map")
    eq(Suite.names(moderator:get_players(true)), { "alice" }, "filtered to connected players")
    eq(Suite.names(moderator:get_players(false)), { "dave" }, "filtered to offline players")
end)

test(".print() reaches online holders", function(env)
    setup(env)
    env.reset_log()
    eq(env.R("Moderator"):print("hello"), 1, "print returns the number of players reached")
    eq(env.printed, { { "hello", to = "alice" } }, "only online holders receive the message")
    eq(env.R("Jail"):print("hello"), 0, "a role with no online holders reaches nobody")
end)

test(".print() over get_higher_roles() can repeat", function(env)
    local players = setup(env)
    env.R("Regular"):assign(players.alice, { silent = true, local_only = true })
    env.reset_log()
    for _, role in ipairs(env.Roles.get_higher_roles(env.R("Regular"))) do
        role:print("hello")
    end

    local got = {}
    for _, entry in ipairs(env.printed) do got[#got + 1] = entry.to end
    -- alice holds two of the roles, so like the legacy system the message can repeat
    eq(Suite.sorted(got), { "alice", "alice", "bob" }, "the online holders of each role are reached")
end)

return Suite.run()
