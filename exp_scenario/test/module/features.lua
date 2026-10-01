local Suite = ... --- @type Suite<ExpScenario.TestEnv>

--- The values of on_config_updated events, ignoring the event name and tick
local function updates(env)
    local rtn = {}
    for _, event in ipairs(env.events) do
        rtn[#rtn + 1] = { event.feature_name, event.path, event.old_value, event.new_value }
    end
    return rtn
end

Suite.test("register() enables features unless the config says otherwise", function(env)
    Suite.eq(env.Feature.register("on", { value = 1 }).config.enabled, true, "enabled by default")
    Suite.eq(env.Feature.register("off", { enabled = false }):is_enabled(), false, "the config can disable it")
    Suite.eq(env.Feature.register("empty").config, { enabled = true }, "config is optional")
    Suite.throws(function() env.Feature.register("on", {}) end, "Feature already registered: on", "names are unique")
end)

Suite.test("get() finds registered features", function(env)
    local feature = env.Feature.register("test")
    Suite.eq(env.Feature.get("test") == feature, true, "by name")
    Suite.throws(function() env.Feature.get("unknown") end, "Unknown feature: unknown", "unknown names error")
end)

Suite.test("update_config() changes the config in place", function(env)
    local feature = env.Feature.register("test", { flag = true, count = 5, text = "a" })
    local config = feature.config
    feature:update_config(false, { flag = false, count = 7 })
    Suite.eq(config, { enabled = false, flag = false, count = 7, text = "a" }, "given values replace the defaults")

    feature:update_config(true, { text = "b" })
    Suite.eq(config, { enabled = true, flag = true, count = 5, text = "b" }, "values left out go back to their default")
    Suite.eq(env.storage, { test = { enabled = true, text = "b" } }, "the overrides are kept in storage")
end)

Suite.test("update_config() raises on_config_updated for each changed value", function(env)
    local feature = env.Feature.register("test", { flag = true, names = { "a" }, section = { count = 1 } })
    feature:update_config(false, { names = { "a" }, ["section.count"] = 2 })
    Suite.eq(#env.events, 2, "unchanged values raise nothing")
    Suite.eq(env.Feature.events.on_config_updated, assert(env.events[1]).name, "the event is on_config_updated")

    local seen = updates(env)
    table.sort(seen, function(a, b) return a[2] < b[2] end)
    Suite.eq(seen, {
        { "test", "enabled", true, false },
        { "test", "section.count", 1, 2 },
    }, "with the path, old value, and new value")
end)

Suite.test("update_config() ignores and logs values which can not be overridden", function(env)
    local function check() return true end
    local feature = env.Feature.register("test", { flag = true, check = check, icon = nil })
    feature:update_config(true, { flag = "yes", check = false, icon = "x" })
    Suite.eq(feature.config, { enabled = true, flag = true, check = check }, "wrong types, functions, and unknown keys are skipped")
    Suite.eq(#env.logged, 3, "each one is logged")
end)

Suite.test("receive_update() updates known features", function(env)
    local feature = env.Feature.register("test", { flag = true })
    env.Feature.receive_update{
        { name = "test", enabled = true, values = { flag = false } },
        { name = "unknown", enabled = false, values = {} },
    }
    Suite.eq(feature.config.flag, false, "the known feature changed")
    Suite.eq(env.storage.unknown, nil, "unknown features are not stored")
end)

Suite.test("on_load applies the overrides from storage without raising events", function(env)
    local feature = env.Feature.register("test", { flag = true })
    env.on_load{ test = { enabled = false, flag = false } }
    Suite.eq(feature.config, { enabled = false, flag = false }, "the saved overrides apply")
    Suite.empty(env.events, "nothing is raised")

    feature:update_config(true, {})
    Suite.eq(env.storage, { test = { enabled = true } }, "later updates go to the loaded storage table")
end)

Suite.test("guard() skips handlers while the feature is disabled", function(env)
    local feature = env.Feature.register("test")
    local calls = {}
    local lib = feature:guard{
        events = { on_event = function(event) calls[#calls + 1] = event end },
        on_nth_tick = { [60] = function(event) calls[#calls + 1] = event end },
        on_init = function() end,
    }

    lib.events.on_event("a")
    lib.on_nth_tick[60]("b")
    feature:update_config(false, {})
    lib.events.on_event("c")
    lib.on_nth_tick[60]("d")
    Suite.eq(calls, { "a", "b" }, "only called while enabled")
end)

Suite.test("register() addresses nested values by path", function(env)
    local offset = { 1, 2 }
    local feature = env.Feature.register("test", { section = { flag = true, count = 1 }, offset = offset })
    feature:update_config(true, { ["section.flag"] = false, offset = { "x" } })
    Suite.eq(feature.config.section, { flag = false, count = 1 }, "the nested value changes in place")
    Suite.eq(feature.config.offset, offset, "lists of other types can not be overridden")

    feature:update_config(true, {})
    Suite.eq(feature.config.section.flag, true, "and goes back to its default")
end)

Suite.test("register() allows lists of strings to be overridden", function(env)
    local feature = env.Feature.register("test", { names = { "a", "b" }, empty = {} })
    feature:update_config(true, { names = { "c" }, empty = { "d" } })
    Suite.eq(feature.config.names, { "c" }, "a list is replaced")
    Suite.eq(feature.config.empty, { "d" }, "an empty default is a list")
    feature:update_config(true, { names = { 1 } })
    Suite.eq(feature.config.names, { "a", "b" }, "a list with other types is invalid")
end)

Suite.test("optional() declares a value without a default", function(env)
    local feature = env.Feature.register("test", { role_id = env.Feature.optional("number") })
    Suite.eq(feature.config.role_id, nil, "nil until overridden")
    feature:update_config(true, { role_id = 3 })
    Suite.eq(feature.config.role_id, 3, "overridden with the given type")
    feature:update_config(true, {})
    Suite.eq(feature.config.role_id, nil, "and back to nil")
end)

Suite.test("to_set() is cached until the list is replaced", function(env)
    local feature = env.Feature.register("test", { names = { "a" } })
    local set = env.Feature.to_set(feature.config.names)
    Suite.eq(set, { a = true }, "a set of the items")
    Suite.eq(env.Feature.to_set(feature.config.names) == set, true, "the same set while the list is unchanged")
    env.on_load{ test = { enabled = true, names = { "b" } } }
    Suite.eq(env.Feature.to_set(feature.config.names), { b = true }, "a new set after load replaces the list")
end)

Suite.test("config files register their feature", function(env)
    local feature = env.load_config("popups")
    feature:update_config(true, { show_player_damage = false })
    Suite.eq(feature.config.show_player_damage, false, "popups can be changed")
    Suite.eq(feature.config.show_player_health, true, "other values keep their default")
end)

return Suite.run()
