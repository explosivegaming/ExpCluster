local Suite = ... --- @type Suite<ExpScenario.TestEnv>

Suite.test("config() enables features unless the defaults say otherwise", function(env)
    Suite.eq(env.Features.config("on", { value = 1 }).enabled, true, "enabled by default")
    Suite.eq(env.Features.config("off", { enabled = false }).enabled, false, "the defaults can disable it")
    Suite.eq(env.Features.config("empty"), { enabled = true }, "config is optional")
    Suite.throws(function() env.Features.config("on", {}) end, "Feature already declared: on", "names are unique")
end)

Suite.test("is_enabled() takes a name or a config", function(env)
    local config = env.Features.config("test", { enabled = false })
    Suite.eq(env.Features.is_enabled("test"), false, "by name")
    Suite.eq(env.Features.is_enabled(config), false, "by config")
    Suite.throws(function() env.Features.is_enabled("unknown") end, "Unknown feature: unknown", "unknown names error")
end)

Suite.test("receive_update() changes the config in place", function(env)
    local config = env.Features.config("test", { flag = true, count = 5, text = "a" })
    env.Features.receive_update{ { name = "test", enabled = false, values = { flag = false, count = 7 } } }
    Suite.eq(config, { enabled = false, flag = false, count = 7, text = "a" }, "given values replace the defaults")

    env.Features.receive_update{ { name = "test", enabled = true, values = { text = "b" } } }
    Suite.eq(config, { enabled = true, flag = true, count = 5, text = "b" }, "values left out go back to their default")
    Suite.eq(env.storage, { test = { enabled = true, text = "b" } }, "the overrides are kept in storage")
end)

Suite.test("receive_update() raises on_feature_changed for each known feature", function(env)
    env.Features.config("test")
    env.Features.receive_update{
        { name = "test", enabled = false, values = {} },
        { name = "unknown", enabled = false, values = {} },
    }
    Suite.eq(env.events, {
        { name = env.Features.events.on_feature_changed, tick = game.tick, feature_name = "test" },
    }, "raised once")
end)

Suite.test("receive_update() ignores values which can not be overridden", function(env)
    local function check() return true end
    local config = env.Features.config("test", { flag = true, check = check, icon = nil })
    env.Features.receive_update{
        { name = "unknown", enabled = false, values = {} },
        { name = "test", enabled = true, values = { flag = "yes", check = false, icon = "x", extra = 1 } },
    }
    Suite.eq(config, { enabled = true, flag = true, check = check }, "wrong types, functions, and unknown keys are skipped")
    Suite.eq(env.storage.unknown, nil, "unknown features are not stored")
end)

Suite.test("on_load applies the overrides from storage", function(env)
    local config = env.Features.config("test", { flag = true })
    env.on_load{ test = { enabled = false, flag = false } }
    Suite.eq(config, { enabled = false, flag = false }, "the saved overrides apply")

    env.Features.receive_update{ { name = "test", enabled = true, values = {} } }
    Suite.eq(env.storage, { test = { enabled = true } }, "later updates go to the loaded storage table")
end)

Suite.test("guard() skips handlers while the feature is disabled", function(env)
    local config = env.Features.config("test")
    local calls = {}
    local lib = env.Features.guard(config, {
        events = { on_event = function(event) calls[#calls + 1] = event end },
        on_nth_tick = { [60] = function(event) calls[#calls + 1] = event end },
        on_init = function() end,
    })

    lib.events.on_event("a")
    lib.on_nth_tick[60]("b")
    env.Features.receive_update{ { name = "test", enabled = false, values = {} } }
    lib.events.on_event("c")
    lib.on_nth_tick[60]("d")
    Suite.eq(calls, { "a", "b" }, "only called while enabled")
end)

Suite.test("guard() declares features by name", function(env)
    local calls = 0
    local lib = env.Features.guard("test", { events = { on_event = function() calls = calls + 1 end } })
    env.Features.receive_update{ { name = "test", enabled = false, values = {} } }
    lib.events.on_event()
    Suite.eq(calls, 0, "the name is declared without config")
    Suite.eq(env.Features.is_enabled("test"), false, "and can be looked up")
end)

Suite.test("receive_update() logs invalid and unknown overrides", function(env)
    local config = env.Features.config("test", { flag = true })
    env.Features.receive_update{ { name = "test", enabled = true, values = { flag = 1, extra = 2 } } }
    Suite.eq(config.flag, true, "the default is used")
    Suite.eq(#env.logged, 2, "both are logged")
end)

Suite.test("config() addresses nested values by path", function(env)
    local offset = { 1, 2 }
    local config = env.Features.config("test", { section = { flag = true, count = 1 }, offset = offset })
    env.Features.receive_update{ { name = "test", enabled = true, values = { ["section.flag"] = false, offset = { "x" } } } }
    Suite.eq(config.section, { flag = false, count = 1 }, "the nested value changes in place")
    Suite.eq(config.offset, offset, "lists of other types can not be overridden")

    env.Features.receive_update{ { name = "test", enabled = true, values = {} } }
    Suite.eq(config.section.flag, true, "and goes back to its default")
end)

Suite.test("config() allows lists of strings to be overridden", function(env)
    local config = env.Features.config("test", { names = { "a", "b" }, empty = {} })
    env.Features.receive_update{ { name = "test", enabled = true, values = { names = { "c" }, empty = { "d" } } } }
    Suite.eq(config.names, { "c" }, "a list is replaced")
    Suite.eq(config.empty, { "d" }, "an empty default is a list")
    env.Features.receive_update{ { name = "test", enabled = true, values = { names = { 1 } } } }
    Suite.eq(config.names, { "a", "b" }, "a list with other types is invalid")
end)

Suite.test("optional() declares a value without a default", function(env)
    local config = env.Features.config("test", { role_id = env.Features.optional("number") })
    Suite.eq(config.role_id, nil, "nil until overridden")
    env.Features.receive_update{ { name = "test", enabled = true, values = { role_id = 3 } } }
    Suite.eq(config.role_id, 3, "overridden with the given type")
    env.Features.receive_update{ { name = "test", enabled = true, values = {} } }
    Suite.eq(config.role_id, nil, "and back to nil")
end)

Suite.test("on_apply() is called now and after every change", function(env)
    local config = env.Features.config("test", { names = { "a" } })
    local seen = {}
    env.Features.on_apply("test", function(applied) seen[#seen + 1] = applied.names[1] end)
    env.Features.receive_update{ { name = "test", enabled = true, values = { names = { "b" } } } }
    env.on_load{ test = { enabled = true, names = { "c" } } }
    Suite.eq(seen, { "a", "b", "c" }, "on register, update, and load")
    Suite.eq(config.names, { "c" }, "after the config is applied")
end)

Suite.test("config files declare their feature", function(env)
    local config = env.load_config("popups")
    env.Features.receive_update{ { name = "popups", enabled = true, values = { show_player_damage = false } } }
    Suite.eq(config.show_player_damage, false, "popups can be changed")
    Suite.eq(config.show_player_health, true, "other values keep their default")
end)

return Suite.run()
