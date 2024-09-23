--[[-- Commands Module - Connect
    - Adds a commands that allows you to request a player move to another server
    @commands Connect
]]

local Async = require 'expcore.async' --- @dep expcore.async
local External = require 'expcore.external' --- @dep expcore.external
local Commands = require 'expcore.commands' --- @dep expcore.commands
require 'config.expcore.command_role_parse'
local concat = table.concat

local request_connection = Async.register(External.request_connection)

local function get_server_id(server)
    local current_server = External.get_current_server()
    local current_version = current_server.version
    local servers = External.get_servers_filtered(server)

    local server_names_before, server_names = {}, {}
    local server_count_before, server_count = 0, 0
    for next_server_id, server_details in pairs(servers) do
        server_count_before = server_count_before + 1
        server_names_before[server_count_before] = server_details.name
        if server_details.version == current_version then
            server_count = server_count + 1
            server_names[server_count] = server_details.name
        else
            servers[next_server_id] = nil
        end
    end

    if server_count > 1 then
        return false, Commands.error{'expcom-connect.too-many-matching', concat(server_names, ', ')}
    elseif server_count == 1 then
        local server_id, server_details = next(servers)
        local status = External.get_server_status(server_id)
        if server_id == current_server.id then
            return false, Commands.error{'expcom-connect.same-server', server_details.name}
        elseif status == 'Offline' then
            return false, Commands.error{'expcom-connect.offline', server_details.name}
        end
        return true, server_id
    elseif server_count_before > 0 then
        return false, Commands.error{'expcom-connect.wrong-version', concat(server_names_before, ', ')}
    else
        return false, Commands.error{'expcom-connect.none-matching'}
    end
end

--- Connect to a different server
-- @command connect
-- @tparam string server The address or name of the server to connect to
-- @tparam[opt=false] boolean is_address If an address was given for the server param
Commands.new_command('connect', {'expcom-connect.description'}, 'Connect to another server')
:add_param('server')
:add_param('is_address', true, 'boolean')
:add_alias('join', 'server')
:register(function(player, server, is_address)
    local server_id = server
    if not is_address and External.valid() then
        local success, new_server_id = get_server_id(server)
        if not success then return new_server_id end
        server_id = new_server_id
    end

    Async(request_connection, player, server_id, true)
end)

--- Connect a player to a different server
-- @command connect-player
-- @tparam string address The address or name of the server to connect to
-- @tparam LuaPlayer player The player to connect to a different server
-- @tparam[opt=false] boolean is_address If an address was given for the server param
Commands.new_command('connect-player', {'expcom-connect.description-player'}, 'Send a player to a different server')
:add_param('player', 'player-role')
:add_param('server')
:add_param('is_address', true, 'boolean')
:register(function(_, player, server, is_address)
    local server_id = server
    if not is_address and External.valid() then
        local success, new_server_id = get_server_id(server)
        if not success then return new_server_id end
        server_id = new_server_id
    end

    External.request_connection(player, server_id)
end)

--- Connect all players to a different server
-- @command connect-all
-- @tparam string address The address or name of the server to connect to
-- @tparam[opt=false] boolean is_address If an address was given for the server param
Commands.new_command('connect-all', {'expcom-connect.description-all'}, 'Connect all players to another server')
:add_param('server')
:add_param('is_address', true, 'boolean')
:register(function(_, server, is_address)
    local server_id = server
    if not is_address and External.valid() then
        local success, new_server_id = get_server_id(server)
        if not success then return new_server_id end
        server_id = new_server_id
    end

    for _, player in pairs(game.connected_players) do
        External.request_connection(player, server_id)
    end
end)
