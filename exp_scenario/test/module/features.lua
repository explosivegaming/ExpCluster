local Suite = ... --- @type Suite<ExpScenario.TestEnv>

Suite.test("register() enables features unless the defaults say otherwise", function(env)
    Suite.eq(env.Features.register("on", { value = 1 }).enabled, true, "enabled by default")
    Suite.eq(env.Features.register("off", { enabled = false }).enabled, false, "the defaults can disable it")
    Suite.throws(function() env.Features.register("on", {}) end, "Feature already registered: on", "names are unique")
end)

Suite.test("receive_update() changes the registered table in place", function(env)
    local config = env.Features.register("test", { flag = true, count = 5, text = "a" })
    env.Features.receive_update{ { name = "test", enabled = false, values = { flag = false, count = 7 } } }
    Suite.eq(config, { enabled = false, flag = false, count = 7, text = "a" }, "given values replace the defaults")

    env.Features.receive_update{ { name = "test", enabled = true, values = { text = "b" } } }
    Suite.eq(config, { enabled = true, flag = true, count = 5, text = "b" }, "values left out go back to their default")
    Suite.eq(env.storage, { test = { enabled = true, text = "b" } }, "the overrides are kept in storage")
end)

Suite.test("receive_update() ignores values which can not be overridden", function(env)
    local function check() return true end
    local config = env.Features.register("test", { flag = true, check = check, icon = nil })
    env.Features.receive_update{
        { name = "unknown", enabled = false, values = {} },
        { name = "test", enabled = true, values = { flag = "yes", check = false, icon = "x", extra = 1 } },
    }
    Suite.eq(config, { enabled = true, flag = true, check = check }, "wrong types, functions, and unknown keys are skipped")
    Suite.eq(env.storage.unknown, nil, "unknown features are not stored")
end)

Suite.test("on_load applies the overrides from storage", function(env)
    local config = env.Features.register("test", { flag = true })
    env.on_load{ test = { enabled = false, flag = false } }
    Suite.eq(config, { enabled = false, flag = false }, "the saved overrides apply")

    env.Features.receive_update{ { name = "test", enabled = true, values = {} } }
    Suite.eq(env.storage, { test = { enabled = true } }, "later updates go to the loaded storage table")
end)

Suite.test("guard() skips handlers while the feature is disabled", function(env)
    local config = env.Features.register("test", {})
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

Suite.test("config files register their feature", function(env)
    local config = env.load_config("death_markers")
    env.Features.receive_update{ { name = "death_markers", enabled = true, values = { show_map_markers = false } } }
    Suite.eq(config.show_map_markers, false, "death_markers can be changed")
    Suite.eq(config.period_check_map_tags, 60 * 60 * 5, "other values keep their default")
end)

return Suite.run()
