--[[-- Core Module - External
- A module used to make accessing externally set data easier.
@core External
@alias External

@usage-- Printing all server to chat
local External = require("modules.exp_legacy.expcore.external") --- @dep expcore.external

local message = 'id: %s name: %s version: %s status: %s'
for server_id, server in pairs(External.get_servers()) do
    local status = External.get_server_status(server_id)
    game.print(message:format(server_id, server.name, server.version, status))
end

]]

local ext, var
local concat = table.concat

local External = {}

--[[-- Checks that local links are valid, will try to add the links if invalid
@treturn boolean If the external data is valid, if false you should not call any other methods from External

@usage-- Check that external data is valid
if not External.valid() then
    -- error code here
end

]]
function External.valid()
    if storage.ext == nil then return false end
    if ext == storage.ext and var == ext.var then
        return var ~= nil
    else
        ext = storage.ext
        var = ext.var
        return var ~= nil
    end
end

--[[-- Gets a table of all the servers, key is the server id, value is the server details
@treturn table A table containing all the servers, key is the server id, value is the server details

@usage-- Get all servers
local servers = External.get_servers()

]]
function External.get_servers()
    assert(ext, "No external data was found, use External.valid() to ensure external data exists.")
    return assert(ext.servers, "No server list was found, please ensure that the external service is running")
end

--[[-- Gets a table of all the servers filtered by name, key is the server id, value is the server details
@tparam string search The string to search for, names, short_names and ids are checked for this string.
@treturn table A table containing all the servers filtered by name, key is the server id, value is the server details

@usage-- Get all servers with public in the name
local servers = External.get_servers_filtered(public)

]]
function External.get_servers_filtered(search)
    assert(ext, "No external data was found, use External.valid() to ensure external data exists.")
    local servers = assert(ext.servers, "No server list was found, please ensure that the external service is running")
    local found_servers = {}
    search = search:lower()
    for server_id, server in pairs(servers) do
        local str = concat{ server.name, server.short_name, server.id }
        if str:lower():find(search, 1, true) then found_servers[server_id] = server end
    end

    return found_servers
end

--[[-- Gets the details of the current server
@treturn table The details of the current server

@usage-- Get the details of the current server
local server = External.get_current_server()

]]
function External.get_current_server()
    assert(ext, "No external data was found, use External.valid() to ensure external data exists.")
    local servers = assert(ext.servers, "No server list was found, please ensure that the external service is running")
    local server_id = assert(ext.current, "No current id was found, please ensure that the external service is running")
    return assert(servers[server_id], "No details found for server with id: " .. tostring(server_id))
end

--[[-- Gets the details of the given server
@tparam string server_id The internal server if for the server you want the details of
@treturn table The details of the given server

@usage-- Get the details of the given server
local server = External.get_server_details('eu-01')

]]
function External.get_server_details(server_id)
    assert(ext, "No external data was found, use External.valid() to ensure external data exists.")
    local servers = assert(ext.servers, "No server list was found, please ensure that the external service is running")
    return assert(servers[server_id], "No details found for server with id: " .. tostring(server_id))
end

--[[-- Gets the status of the given server
@tparam string server_id The internal server if for the server you want the status of
@tparam boolean raw When true Current will not be returned as status but rather the raw status for the server
@treturn string The status of the given server, one of: Online, Modded, Protected, Current, Offline

@usage-- Get the status of the given server
local status = External.get_server_status('eu-01')

]]
function External.get_server_status(server_id, raw)
    assert(var, "No external data was found, use External.valid() to ensure external data exists.")
    local servers = assert(var.status, "No server status was found, please ensure that the external service is running")
    local current = assert(ext.current, "No current id was found, please ensure that the external service is running")
    return not raw and server_id == current and "Current" or assert(servers[server_id], "No status found for server with id: " .. tostring(server_id))
end

--[[-- Gets the ups of the current server
@usage-- Get the ups of the current server
local server_ups = External.get_server_ups()

]]
function External.get_server_ups()
    assert(var, "No external data was found, use External.valid() to ensure external data exists.")
    return assert(var.server_ups, "No server ups was found, please ensure that the external service is running")
end

--[[-- Connect a player to the given server
@tparam LuaPlayer player The player that you want to request to join a different server
@tparam string server_id The internal id of the server to connect to, can also be any address but this will show Unknown Server
@tparam[opt=false] boolean self_requested If the player requested the join themself, this will hide the message about being asked to switch

@usage-- Request that a player joins a different server
External.request_connection(player, 'eu-01')

@usage-- Request that a player joins a different server, by own request
External.request_connection(player, 'eu-01', true)

]]
function External.request_connection(player, server_id, self_requested)
    local server = { address = server_id, name = "Unknown Server", description = "This server is not ran by us, please check the address of the server." }
    if ext and ext.servers and ext.servers[server_id] then server = ext.servers[server_id] end
    local message = "Please press the connect button below to join."
    if not self_requested then message = "You have been asked to switch to a different server.\n" .. message end
    player.connect_to_server{
        address = server.address,
        name = "\n[color=orange][font=heading-1]" .. server.name .. "[/font][/color]\n",
        description = server.description .. "\n" .. message,
    }
end

--- Module return
return External
