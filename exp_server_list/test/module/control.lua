local Suite = ... --- @type Suite<ExpServerList.TestEnv>

Suite.test("nothing is known before the first update", function(env)
    Suite.eq(env.ServerList.get_current(), nil, "no current server")
    Suite.empty(env.ServerList.get_servers(), "no servers")
end)

Suite.test("receive_update() with replace swaps the whole list", function(env)
    local List = env.ServerList
    List.receive_update{ current_id = 1, replace = true, servers = { env.server(1), env.server(2) } }
    List.receive_update{ current_id = 1, replace = true, servers = { env.server(1), env.server(3) } }

    Suite.eq(List.get_current().id, 1, "the current server is set")
    Suite.eq(List.get_server(2), nil, "servers missing from the new list are removed")
    Suite.eq(List.get_server(3).name, "Server 3", "new servers are added")
    local ids = env.events[2].server_ids
    table.sort(ids)
    Suite.eq(ids, { 1, 2, 3 }, "the event lists removed and added servers")
end)

Suite.test("receive_update() without replace changes only the given servers", function(env)
    local List = env.ServerList
    List.receive_update{ current_id = 1, replace = true, servers = { env.server(1), env.server(2), env.server(3) } }
    List.receive_update{ current_id = 1, replace = false, servers = {
        env.server(2, { player_count = 4 }),
        { id = 3, is_deleted = true },
    } }

    Suite.eq(List.get_server(1).name, "Server 1", "untouched servers stay")
    Suite.eq(List.get_server(2).player_count, 4, "changed servers are replaced")
    Suite.eq(List.get_server(3), nil, "deleted servers are removed")
    local ids = env.events[2].server_ids
    table.sort(ids)
    Suite.eq(ids, { 2, 3 }, "the event lists only the given servers")
    Suite.eq(env.events[2].name, List.on_servers_updated, "on_servers_updated is raised")
end)

Suite.test("get_servers() leaves out hidden servers and sorts by name", function(env)
    local List = env.ServerList
    List.receive_update{ current_id = 1, replace = true, servers = {
        env.server(1, { name = "Charlie" }),
        env.server(2, { name = "Alpha" }),
        env.server(3, { name = "Bravo", hidden = true }),
    } }

    local names = {}
    for index, server in ipairs(List.get_servers()) do
        names[index] = server.name
    end
    Suite.eq(names, { "Alpha", "Charlie" }, "hidden servers are not listed")
    Suite.eq(List.get_server(3).name, "Bravo", "but can still be looked up by id")
end)

Suite.test("find_servers() matches name, short name and id ignoring case", function(env)
    local List = env.ServerList
    List.receive_update{ current_id = 1, replace = true, servers = {
        env.server(1, { name = "Public Weekly", short_name = "S1" }),
        env.server(2, { name = "Modded", short_name = "S2" }),
        env.server(37, { name = "Event", short_name = "Event" }),
    } }

    local function ids(search)
        local rtn = {}
        for index, server in ipairs(List.find_servers(search)) do
            rtn[index] = server.id
        end
        return rtn
    end

    Suite.eq(ids("weekly"), { 1 }, "by name")
    Suite.eq(ids("s2"), { 2 }, "by short name")
    Suite.eq(ids("37"), { 37 }, "by id")
    Suite.eq(ids("nothing"), {}, "no match")
end)

Suite.test("is_online() needs a running server with an address", function(env)
    local List = env.ServerList
    Suite.eq(List.is_online(env.server(1)), true, "running with an address")
    Suite.eq(List.is_online(env.server(1, { status = "stopped" })), false, "stopped")
    Suite.eq(List.is_online(env.server(1, { address = "" })), false, "no address")
end)

Suite.test("request_connection() connects to a server or an address", function(env)
    local List = env.ServerList
    local alice = env.add_player{ name = "alice" }
    List.request_connection(alice, env.server(2, { description = "Weekly reset" }), true)
    List.request_connection(alice, "example.com:34197")

    Suite.eq(env.connections, {
        {
            to = "alice",
            address = "localhost:34198",
            name = { "exp-server-list.connect-name", "Server 2" },
            description = { "exp-server-list.connect-description", "Weekly reset" },
        },
        {
            to = "alice",
            address = "example.com:34197",
            name = { "exp-server-list.connect-name", { "exp-server-list.unknown-name" } },
            description = { "exp-server-list.connect-description-asked", { "exp-server-list.unknown-description" } },
        },
    }, "players asked by someone else are told so")
end)

return Suite.run()
