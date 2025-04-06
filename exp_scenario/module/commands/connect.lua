--[[-- Commands - Connect
Adds a commands that allows you to request a player move to another server
]]

local Async = require("modules/exp_util/async")
local Commands = require("modules/exp_commands")

local External = require("modules.exp_legacy.expcore.external") --- @dep expcore.external
local request_connection_async = Async.register(External.request_connection)

local concat = table.concat

--- Convert a server name into a server id, is not an Commands.InputParser because it does not accept addresses
--- @param server string
--- @return boolean, LocalisedString # True for success
local function get_server_id(server)
    local servers = External.get_servers_filtered(server)
    local current_server = External.get_current_server()
    local current_version = current_server.version

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
        return false, { "exp-commands_connect.too-many-matching", concat(server_names, ", ") }
    elseif server_count == 1 then
        local server_id, server_details = next(servers) --- @cast server_details -nil
        local status = External.get_server_status(server_id)
        if server_id == current_server.id then
            return false, { "exp-commands_connect.same-server", server_details.name }
        elseif status == "Offline" then
            return false, { "exp-commands_connect.offline", server_details.name }
        end
        return true, server_id
    elseif server_count_before > 0 then
        return false, { "exp-commands_connect.wrong-version", concat(server_names_before, ", ") }
    else
        return false, { "exp-commands_connect.none-matching" }
    end
end

--- Connect to a different server
Commands.new("connect", { "exp-commands_connect.description" })
    :argument("server", { "exp-commands_connect.arg-server" }, Commands.types.string)
    :optional("is-address", { "exp-commands_connect.arg-is-address" }, Commands.types.boolean)
    :add_aliases{ "join" }
    :register(function(player, server, is_address)
        --- @cast server string
        --- @cast is_address boolean?
        if not is_address and External.valid() then
            local success, result = get_server_id(server)
            if not success then
                return Commands.status.invalid_input(result)
            end
            server = result
        end

        request_connection_async(player, server, true)
    end)

--- Connect another player to a different server
Commands.new("connect-player", { "exp-commands_connect.description-player" })
    :argument("player", { "exp-commands_connect.arg-player" }, Commands.types.player_online)
    :argument("server", { "exp-commands_connect.arg-server" }, Commands.types.string)
    :optional("is-address", { "exp-commands_connect.arg-is-address" }, Commands.types.boolean)
    :add_flags{ "admin_only" }
    :register(function(player, other_player, server, is_address)
        --- @cast other_player LuaPlayer
        --- @cast server string
        --- @cast is_address boolean?
        if not is_address and External.valid() then
            local success, result = get_server_id(server)
            if not success then
                return Commands.status.invalid_input(result)
            end
            server = result
        end

        request_connection_async(other_player, server)
    end)

--- Connect all players to a different server
Commands.new("connect-all", { "exp-commands_connect.description-all" })
    :argument("server", { "exp-commands_connect.arg-server" }, Commands.types.string)
    :optional("is-address", { "exp-commands_connect.arg-is-address" }, Commands.types.boolean)
    :add_flags{ "admin_only" }
    :register(function(player, server, is_address)
        --- @cast server string
        --- @cast is_address boolean?
        if not is_address and External.valid() then
            local success, result = get_server_id(server)
            if not success then
                return Commands.status.invalid_input(result)
            end
            server = result
        end

        for _, next_player in pairs(game.connected_players) do
            request_connection_async(next_player, server)
        end
    end)
