--[[-- ExpServerList
The details of every instance in the cluster, kept up to date by the controller.

The instance plugin sends the whole list when the server starts and each
changed server after that. Hidden servers are kept but left out of
get_servers and find_servers.

local ExpServerList = require("modules/exp_server_list")

for _, server in ipairs(ExpServerList.get_servers()) do
    game.print(server.name .. " " .. server.player_count)
end

[ExpServerList.on_servers_updated] = function(event) end, -- { server_ids }
]]

local Storage = require("modules/exp_util/storage")

--- @class ExpServerList.Server
--- @field id number The instance id
--- @field name string
--- @field short_name string The name when not set
--- @field description string
--- @field welcome string
--- @field reset_time string
--- @field hidden boolean
--- @field mod_pack_name string
--- @field factorio_version string Empty if it has never started
--- @field player_count number
--- @field status string The clusterio instance status, "running" once players can join
--- @field address string Empty when the host has no public address

--- @class ExpServerList.Update
--- @field current_id number
--- @field replace boolean True when servers is the whole list
--- @field servers (ExpServerList.Server | { id: number, is_deleted: true })[]

--- @class ExpServerList
local ExpServerList = {
    --- Raised after servers were added, changed or removed
    --- @type EventData.ExpServerList.on_servers_updated
    on_servers_updated = script.generate_event_name(),
}

--- @class EventData.ExpServerList.on_servers_updated : EventData
--- @field server_ids number[] Removed servers included

local servers = {} --- @type table<number, ExpServerList.Server>
local current = { id = nil } --- @type { id: number? }
Storage.register({ servers, current }, function(tbl)
    servers = tbl[1]
    current = tbl[2]
end)

--- @param a ExpServerList.Server
--- @param b ExpServerList.Server
local function by_name(a, b)
    return a.name < b.name
end

--- Get every server that is not hidden, sorted by name
--- @return ExpServerList.Server[]
function ExpServerList.get_servers()
    local rtn, count = {}, 0
    for _, server in pairs(servers) do
        if not server.hidden then
            count = count + 1
            rtn[count] = server
        end
    end
    table.sort(rtn, by_name)
    return rtn
end

--- Get a server by instance id, hidden ones included
--- @param server_id number
--- @return ExpServerList.Server?
function ExpServerList.get_server(server_id)
    return servers[server_id]
end

--- Get this server, nil until the controller has sent the list
--- @return ExpServerList.Server?
function ExpServerList.get_current()
    return current.id and servers[current.id]
end

--- Get the servers that are not hidden whose name, short name or id contains the search, sorted by name
--- @param search string
--- @return ExpServerList.Server[]
function ExpServerList.find_servers(search)
    search = search:lower()
    local rtn, count = {}, 0
    for _, server in ipairs(ExpServerList.get_servers()) do
        local str = server.name .. " " .. server.short_name .. " " .. server.id
        if str:lower():find(search, 1, true) then
            count = count + 1
            rtn[count] = server
        end
    end
    return rtn
end

--- True when players can join the server
--- @param server ExpServerList.Server
--- @return boolean
function ExpServerList.is_online(server)
    return server.status == "running" and server.address ~= ""
end

--- Ask a player to join a different server
--- @param player LuaPlayer
--- @param server ExpServerList.Server | string A server, or the address of one outside the cluster
--- @param self_requested boolean? Hides the message about being asked to switch
function ExpServerList.request_connection(player, server, self_requested)
    local message = self_requested and "exp-server-list.connect-description" or "exp-server-list.connect-description-asked"
    if type(server) == "string" then
        player.connect_to_server{
            address = server,
            name = { "exp-server-list.connect-name", { "exp-server-list.unknown-name" } },
            description = { message, { "exp-server-list.unknown-description" } },
        }
    else
        player.connect_to_server{
            address = server.address,
            name = { "exp-server-list.connect-name", server.name },
            description = { message, server.description },
        }
    end
end

--- Called by the instance plugin over rcon
--- @param payload ExpServerList.Update
function ExpServerList.receive_update(payload)
    current.id = payload.current_id
    local changed = {} --- @type table<number, true>
    if payload.replace then
        for server_id in pairs(servers) do
            changed[server_id] = true
            servers[server_id] = nil
        end
    end

    for _, server in ipairs(payload.servers) do
        changed[server.id] = true
        if server.is_deleted then
            servers[server.id] = nil
        else
            servers[server.id] = server --[[@as ExpServerList.Server]]
        end
    end

    local server_ids, count = {}, 0
    for server_id in pairs(changed) do
        count = count + 1
        server_ids[count] = server_id
    end
    script.raise_event(ExpServerList.on_servers_updated, { server_ids = server_ids })
end

return ExpServerList
