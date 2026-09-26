--[[-- Generic factorio stubs for plugin module tests
Provides the surface a clusterio module touches, recording what the module does
to it. Every stub raises an error when an unimplemented property is read, which
mirrors the game api and catches mistakes in tests early.

Plugins compose these from their own test/lua/env.lua, adding their own stubs
with the extend methods rather than by mutating the tables directly.
]]

local Stubs = {}

--- Give a table an index metamethod which raises on unknown properties
--- @generic T : table
--- @param name string Shown in the error message
--- @param tbl T
--- @param allowed_nil string[]? Properties which may be read while unset
--- @return T
function Stubs.strict(name, tbl, allowed_nil)
    local allowed = {}
    for _, key in pairs(allowed_nil or {}) do
        allowed[key] = true
    end

    return setmetatable(tbl, {
        __index = function(_, key)
            if allowed[key] then return nil end
            error(name .. " does not implement: " .. tostring(key), 2)
        end,
    })
end

--- Merge extra into target recursively, raising when a value already exists
--- @generic T : table
--- @param target T
--- @param extra table
--- @return T
function Stubs.extend(target, extra)
    for key, value in pairs(extra) do
        local existing = rawget(target, key)
        if existing == nil then
            rawset(target, key, value)
        elseif type(existing) == "table" and type(value) == "table" then
            Stubs.extend(existing, value)
        else
            error("Stub already implements: " .. tostring(key), 2)
        end
    end
    return target
end

--- Create an independent set of stubs, installed as the lua globals
function Stubs.new()
    --- @class Stubs
    --- @field events table[] Events raised through script.raise_event, name and tick filled in
    --- @field printed (LocalisedString | { to: string, [1]: LocalisedString })[] Messages from game.print and player.print
    --- @field sent { channel: string, data: table }[] Payloads sent through the clusterio api
    --- @field sounds string[] Sounds played to players, as "player:path"
    local stubs = {
        events = {},
        printed = {},
        sent = {},
        sounds = {},
    }

    local next_event_id = 100
    local registered_metatables = {} --- @type table<table, true>
    script = Stubs.strict("LuaBootstrap", {
        generate_event_name = function()
            next_event_id = next_event_id + 1
            return next_event_id
        end,
        raise_event = function(id, data)
            -- Factorio fills in the name and tick of the event
            data.name = id
            data.tick = game.tick
            stubs.events[#stubs.events + 1] = data
        end,
        register_metatable = function(_, metatable)
            registered_metatables[metatable] = true
        end,
    })

    defines = Stubs.strict("defines", {
        events = Stubs.strict("defines.events", {
            on_player_joined_game = 1,
            on_multiplayer_init = 2,
        }),
    })

    -- Stored by name, with an index metamethod so players are also found by
    -- their player index, the same way game.players works
    local players_by_index = {}
    local players = setmetatable({}, { __index = players_by_index })
    local connected = {}
    game = Stubs.strict("LuaGameScript", {
        tick = 1,
        players = players,
        connected_players = connected,
        print = function(message) stubs.printed[#stubs.printed + 1] = message end,
        get_player = function(key) return players[key] end,
    }, { "player" })

    --- @class Stubs.PlayerParams
    --- @field name string
    --- @field connected boolean? Defaults to true
    --- @field admin boolean? Defaults to false

    --- Add a player to the stubbed game, indexes are assigned in join order
    --- @param params Stubs.PlayerParams
    --- @return Stubs.Player
    function stubs.add_player(params)
        local name = params.name
        local index = #players_by_index + 1
        --- @class Stubs.Player
        local player = Stubs.strict("LuaPlayer " .. name, {
            name = name,
            index = index,
            connected = params.connected ~= false,
            admin = params.admin == true,
            valid = true,
            play_sound = function(opts)
                stubs.sounds[#stubs.sounds + 1] = name .. ":" .. opts.path
            end,
            print = function(message)
                stubs.printed[#stubs.printed + 1] = { to = name, message }
            end,
        })
        rawset(players, name, player)
        players_by_index[index] = player
        if player.connected then connected[#connected + 1] = player end
        return player
    end

    --- A player object which represents the server
    --- @type Stubs.Player
    stubs.server = Stubs.strict("LuaPlayer <server>", { index = 0, name = "<server>" })

    --- Modules resolved by the stubbed require, add to them with extend_requires
    local requires = {
        ["modules/clusterio/api"] = Stubs.strict("clusterio api", {
            send_json = function(channel, data)
                stubs.sent[#stubs.sent + 1] = { channel = channel, data = data }
            end,
        }),
        ["modules/clusterio/compat"] = Stubs.strict("clusterio compat", { script_data = {} }),
        ["modules/exp_util/async"] = Stubs.strict("exp_util async", {
            register = function(callback)
                return function(...) return callback(...) end
            end,
        }),
    }
    require = function(name)
        return assert(rawget(requires, name), "Unexpected require: " .. name)
    end

    --- Add modules or properties to the stubbed require
    function stubs.extend_requires(extra) return Stubs.extend(requires, extra) end

    --- Add properties to the script, game, and defines globals
    function stubs.extend_script(extra) return Stubs.extend(script, extra) end
    function stubs.extend_game(extra) return Stubs.extend(game, extra) end
    function stubs.extend_defines(extra) return Stubs.extend(defines, extra) end

    --- Copy a value the way factorio saves script data: functions are refused
    --- and only metatables registered with script.register_metatable survive
    local function save_load_copy(value, copies)
        if type(value) == "function" then
            error("Functions can not be stored in script data", 0)
        end
        if type(value) ~= "table" then return value end
        if copies[value] then return copies[value] end

        local copy = {}
        copies[value] = copy
        for key, entry in pairs(value) do
            copy[save_load_copy(key, copies)] = save_load_copy(entry, copies)
        end

        local metatable = getmetatable(value)
        if metatable ~= nil and registered_metatables[metatable] then
            setmetatable(copy, metatable)
        end
        return copy
    end

    --- Replace the script data with a copy of itself as if the map was saved
    --- and loaded, the module's on_load handler should be called afterwards
    function stubs.save_load()
        local compat = requires["modules/clusterio/compat"]
        compat.script_data = save_load_copy(compat.script_data, {})
    end

    --- Forget everything recorded so far
    function stubs.reset_log()
        stubs.events, stubs.printed, stubs.sent, stubs.sounds = {}, {}, {}, {}
    end

    return stubs
end

return Stubs
