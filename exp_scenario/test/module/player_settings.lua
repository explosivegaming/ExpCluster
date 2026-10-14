local Suite = ... --- @type Suite<ExpScenario.TestEnv>

local valid_state = { order = { { name = "readme", favourite = true } }, open = {}, visible = true }

--- Load control/player_settings.lua with a stubbed toolbar, encoding is a "enc:" prefix
--- @param env ExpScenario.TestEnv
--- @param toolbar table? Replaces the Gui.toolbar stub
--- @return table PlayerSettings
--- @return table restored Calls to set_state as { player name, state }
local function load(env, toolbar)
    local restored = {}
    env.extend_defines{ events = { on_player_locale_changed = 3, on_player_left_game = 4 } }
    env.extend_requires{
        ["modules/exp_gui"] = {
            toolbar = toolbar or {
                get_state = function() return valid_state end,
                set_state = function(player, state) restored[#restored + 1] = { player.name, state } end,
            },
        },
    }
    local json_values = { ['{"valid"}'] = valid_state, ['{"wrong shape"}'] = { order = "x" } }
    helpers = {
        encode_string = function(str) return "enc:" .. str end,
        decode_string = function(str) return str:match("^enc:(.*)$") end,
        table_to_json = function(tbl) return tbl == valid_state and '{"valid"}' or "{}" end,
        json_to_table = function(json) return json_values[json] end,
    }
    return env.load_module("control/player_settings"), restored
end

Suite.test("send_locale() sends the locale of the player", function(env)
    local PlayerSettings = load(env)
    rawset(env.add_player{ name = "Alice" }, "locale", "pt-BR")
    PlayerSettings.events[defines.events.on_player_joined_game]{ player_index = 1 }
    Suite.eq(env.sent, { { channel = "exp_scenario:locale", data = { player_name = "Alice", locale = "pt-BR" } } }, "sent")
end)

Suite.test("send_toolbar() sends the compressed toolbar when a player leaves", function(env)
    local PlayerSettings = load(env)
    env.add_player{ name = "Alice" }
    PlayerSettings.events[defines.events.on_player_left_game]{ player_index = 1 }
    Suite.eq(env.sent, { { channel = "exp_scenario:toolbar", data = { player_name = "Alice", toolbar = 'enc:{"valid"}' } } }, "sent")
end)

Suite.test("send_toolbar() sends nothing when the toolbar can not be read", function(env)
    local PlayerSettings = load(env, { get_state = function() error("no toolbar") end })
    env.add_player{ name = "Alice" }
    PlayerSettings.events[defines.events.on_player_left_game]{ player_index = 1 }
    Suite.eq(env.sent, {}, "nothing sent")
    Suite.eq(#env.logged, 1, "a warning is logged")
end)

Suite.test("receive_toolbar() restores the toolbar of online players", function(env)
    local PlayerSettings, restored = load(env)
    env.add_player{ name = "Alice" }
    env.add_player{ name = "Bob", connected = false }
    PlayerSettings.receive_toolbar("Alice", 'enc:{"valid"}')
    PlayerSettings.receive_toolbar("Bob", 'enc:{"valid"}')
    PlayerSettings.receive_toolbar("Unknown", 'enc:{"valid"}')
    Suite.eq(restored, { { "Alice", valid_state } }, "only Alice is online")
end)

Suite.test("receive_toolbar() logs malformed toolbars instead of raising", function(env)
    local PlayerSettings, restored = load(env)
    env.add_player{ name = "Alice" }
    for _, toolbar in ipairs{ "not encoded", "enc:not json", 'enc:{"wrong shape"}' } do
        PlayerSettings.receive_toolbar("Alice", toolbar)
    end
    Suite.eq(restored, {}, "nothing is restored")
    Suite.eq(#env.logged, 3, "each one is logged")
end)

Suite.test("receive_toolbar() logs errors from set_state", function(env)
    local PlayerSettings = load(env, { set_state = function() error("Missing toolbox item for removed") end })
    env.add_player{ name = "Alice" }
    PlayerSettings.receive_toolbar("Alice", 'enc:{"valid"}')
    Suite.eq(#env.logged, 1, "a warning is logged")
end)
return Suite.run()
