--[[-- Commands - Connect
Adds a commands that allows you to request a player move to another server
]]

local Async = require("modules/exp_util/async")
local Commands = require("modules/exp_commands")

local ExpServerList = require("modules/exp_server_list")
local request_connection_async = Async.register(ExpServerList.request_connection)

local concat = table.concat

--- Find the one server matching a name, is not an Commands.InputParser because it does not accept addresses
--- @param search string
--- @return boolean, LocalisedString | ExpServerList.Server # True for success
local function find_server(search)
    local current_server = ExpServerList.get_current() --- @cast current_server -nil
    local found = ExpServerList.find_servers(search)

    local names_all, names = {}, {}
    local matching = {} --- @type ExpServerList.Server[]
    for index, server in ipairs(found) do
        names_all[index] = server.name
        if server.factorio_version == current_server.factorio_version then
            matching[#matching + 1] = server
            names[#names + 1] = server.name
        end
    end

    if #matching > 1 then
        return false, { "exp-commands_connect.too-many-matching", concat(names, ", ") }
    elseif #matching == 1 then
        local server = matching[1]
        if server.id == current_server.id then
            return false, { "exp-commands_connect.same-server", server.name }
        elseif not ExpServerList.is_online(server) then
            return false, { "exp-commands_connect.offline", server.name }
        end
        return true, server
    elseif #found > 0 then
        return false, { "exp-commands_connect.wrong-version", concat(names_all, ", ") }
    else
        return false, { "exp-commands_connect.none-matching" }
    end
end

--- Resolve the server argument to a server, or leave it as an address
--- @param server string
--- @param is_address boolean?
--- @return boolean, LocalisedString | ExpServerList.Server | string # True for success
local function resolve_server(server, is_address)
    if is_address or not ExpServerList.get_current() then
        return true, server
    end
    return find_server(server)
end

--- Connect to a different server
Commands.new("connect", { "exp-commands_connect.description" })
    :argument("server", { "exp-commands_connect.arg-server" }, Commands.types.string)
    :optional("is-address", { "exp-commands_connect.arg-is-address" }, Commands.types.boolean)
    :add_aliases{ "join" }
    :register(function(player, server, is_address)
        --- @cast server string
        --- @cast is_address boolean?
        local success, result = resolve_server(server, is_address)
        if not success then
            return Commands.status.invalid_input(result)
        end

        request_connection_async(player, result, true)
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
        local success, result = resolve_server(server, is_address)
        if not success then
            return Commands.status.invalid_input(result)
        end

        request_connection_async(other_player, result)
    end)

--- Connect all players to a different server
Commands.new("connect-all", { "exp-commands_connect.description-all" })
    :argument("server", { "exp-commands_connect.arg-server" }, Commands.types.string)
    :optional("is-address", { "exp-commands_connect.arg-is-address" }, Commands.types.boolean)
    :add_flags{ "admin_only" }
    :register(function(player, server, is_address)
        --- @cast server string
        --- @cast is_address boolean?
        local success, result = resolve_server(server, is_address)
        if not success then
            return Commands.status.invalid_input(result)
        end

        for _, next_player in pairs(game.connected_players) do
            request_connection_async(next_player, result)
        end
    end)
