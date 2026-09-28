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

Suite.test("guard() runs intervals once per period of the config value in seconds", function(env)
    local config = env.Features.config("test", { every = 5 })
    local ticks, seconds = {}, {}
    local lib = env.Features.guard(config, {
        on_nth_tick = { [60] = function(event) seconds[#seconds + 1] = event.tick end },
        intervals = { every = function(event) ticks[#ticks + 1] = event.tick end },
    })
    Suite.eq(lib.intervals, nil, "intervals are replaced by on_nth_tick")

    local function run_until(last)
        for tick = 60, last, 60 do lib.on_nth_tick[60]{ tick = tick } end
    end

    run_until(1200)
    Suite.eq(ticks, { 300, 600, 900, 1200 }, "every 5 seconds")
    Suite.eq(#seconds, 20, "an existing handler every second still runs")

    ticks = {}
    env.Features.receive_update{ { name = "test", enabled = true, values = { every = 7 } } }
    run_until(1260)
    Suite.eq(ticks, { 420, 840, 1260 }, "the period can change at runtime")
end)

Suite.test("config files declare their feature", function(env)
    env.extend_requires{ ["modules/exp_roles"] = {} }
    local config = env.load_config("afk_kick")
    env.Features.receive_update{ { name = "afk_kick", enabled = true, values = { afk_minutes = 3 } } }
    Suite.eq(config.afk_minutes, 3, "afk_kick can be changed")
    Suite.eq(config.kick_minutes, 30, "other values keep their default")
end)

return Suite.run()
