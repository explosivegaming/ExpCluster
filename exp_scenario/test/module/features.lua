local Suite = ... --- @type Suite<ExpScenario.TestEnv>

--- The raised on_config_updated events as { path, old value, new value }, sorted by path
local function updates(env)
    local rtn = {}
    for _, event in ipairs(env.events) do
        rtn[#rtn + 1] = { event.path, event.old_value, event.new_value }
    end
    table.sort(rtn, function(a, b) return a[1] < b[1] end)
    return rtn
end

Suite.test("register() enables features unless the config says otherwise", function(env)
    Suite.eq(env.Feature.register("on", { value = 1 }).config.enabled, true, "enabled by default")
    Suite.eq(env.Feature.register("off", { enabled = false }):is_enabled(), false, "the config can disable it")
    Suite.eq(env.Feature.register("empty").config, { enabled = true }, "config is optional")
    Suite.throws(function() env.Feature.register("on", {}) end, "Feature already registered: on", "names are unique")
end)

Suite.test("register() returns the config as well", function(env)
    local feature, config = env.Feature.register("test", { flag = true })
    Suite.eq(config == feature.config, true, "the same table")
end)

Suite.test("get() finds registered features", function(env)
    local feature = env.Feature.register("test")
    Suite.eq(env.Feature.get("test") == feature, true, "by name")
    Suite.throws(function() env.Feature.get("unknown") end, "Unknown feature: unknown", "unknown names error")
end)

Suite.test("update_config() sets every value, missing ones to their default", function(env)
    local feature, config = env.Feature.register("test", { flag = true, count = 5, text = "a" })
    feature:update_config{ enabled = false, flag = false, count = 7 }
    Suite.eq(config, { enabled = false, flag = false, count = 7, text = "a" }, "given values are set")

    feature:update_config{ enabled = true, text = "b" }
    Suite.eq(config, { enabled = true, flag = true, count = 5, text = "b" }, "values left out go back to their default")
    Suite.eq(env.storage, { test = { enabled = true, text = "b" } }, "the values are kept in storage")
end)

Suite.test("update_config() raises on_config_updated for each changed value", function(env)
    local feature = env.Feature.register("test", { flag = true, names = env.Feature.set{ "a" }, section = { count = 1 } })
    feature:update_config{ enabled = false, flag = true, names = { "a" }, ["section.count"] = 2 }
    Suite.eq(env.Feature.events.on_config_updated, assert(env.events[1]).name, "the event is on_config_updated")
    Suite.eq(updates(env), {
        { "enabled", true, false },
        { "section.count", 1, 2 },
    }, "with the path, old value, and new value, unchanged values raise nothing")
end)

Suite.test("update_config() raises when a value goes back to its default", function(env)
    local feature = env.Feature.register("test", { flag = true })
    feature:update_config{ enabled = true, flag = false }
    env.events = {}
    feature:update_config{ enabled = true }
    Suite.eq(updates(env), { { "flag", false, true } }, "the value reverts")
end)

Suite.test("update_config() ignores and logs values of the wrong type", function(env)
    local function check() return true end
    local feature, config = env.Feature.register("test", { flag = true, check = check })
    feature:update_config{ enabled = true, flag = "yes", check = false }
    Suite.eq(config, { enabled = true, flag = true, check = check }, "wrong types and functions keep their default")
    Suite.eq(#env.logged, 2, "each one is logged")
end)

Suite.test("receive_update() updates known features", function(env)
    local feature = env.Feature.register("test", { flag = true })
    env.Feature.receive_update{
        { name = "test", values = { enabled = true, flag = false } },
        { name = "unknown", values = { enabled = false } },
    }
    Suite.eq(feature.config.flag, false, "the known feature changed")
    Suite.eq(env.storage.unknown, nil, "unknown features are not stored")
end)

Suite.test("on_load applies the stored values without raising events", function(env)
    local feature, config = env.Feature.register("test", { flag = true })
    env.on_load{ test = { enabled = false, flag = false, gone = 1 } }
    Suite.eq(config, { enabled = false, flag = false }, "the saved values apply, unknown ones are skipped")
    Suite.empty(env.events, "nothing is raised")

    feature:update_config{ enabled = true }
    Suite.eq(env.storage, { test = { enabled = true } }, "later updates replace the stored values")
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
    feature:update_config{ enabled = false }
    lib.events.on_event("c")
    lib.on_nth_tick[60]("d")
    Suite.eq(calls, { "a", "b" }, "only called while enabled")
end)

Suite.test("register() addresses nested values by path", function(env)
    local offset = { 1, 2 }
    local feature, config = env.Feature.register("test", { section = { flag = true, count = 1 }, offset = offset })
    feature:update_config{ enabled = true, ["section.flag"] = false, offset = { "x" } }
    Suite.eq(config.section, { flag = false, count = 1 }, "the nested value changes in place")
    Suite.eq(config.offset, offset, "tables which are not sections can not be set")

    feature:update_config{ enabled = true }
    Suite.eq(config.section.flag, true, "and goes back to its default")
end)

Suite.test("list() declares a list of strings", function(env)
    local feature, config = env.Feature.register("test", { names = env.Feature.list{ "a", "b" }, empty = env.Feature.list{}, plain = { "x" } })
    Suite.eq(config.names, { "a", "b" }, "the default is the list")
    feature:update_config{ enabled = true, names = { "c" }, empty = { "d" }, plain = { "y" } }
    Suite.eq(config.names, { "c" }, "a list is replaced")
    Suite.eq(config.empty, { "d" }, "an empty list can be set")
    Suite.eq(config.plain, { "x" }, "a plain table can not be set")
    feature:update_config{ enabled = true, names = { 1 } }
    Suite.eq(config.names, { "a", "b" }, "a list with other types is invalid")
end)

Suite.test("set() declares a set of strings which is sent as a list", function(env)
    local feature, config = env.Feature.register("test", { names = env.Feature.set{ "a" }, empty = env.Feature.set{} })
    Suite.eq(config.names, { a = true }, "the default is a set")
    Suite.eq(config.empty, {}, "and can be empty")
    feature:update_config{ enabled = true, names = { "b", "c" } }
    Suite.eq(config.names, { b = true, c = true }, "the list is converted to a set")
    env.on_load{ test = { enabled = true, names = { "d" } } }
    Suite.eq(config.names, { d = true }, "also when the values are loaded")
end)

Suite.test("optional() declares a value without a default", function(env)
    local feature, config = env.Feature.register("test", { role_id = env.Feature.optional("number") })
    Suite.eq(config.role_id, nil, "nil until set")
    feature:update_config{ enabled = true, role_id = 3 }
    Suite.eq(config.role_id, 3, "set with the given type")
    feature:update_config{ enabled = true }
    Suite.eq(config.role_id, nil, "and back to nil")
end)

Suite.test("config files register their feature", function(env)
    local feature = env.load_config("spawn_area")
    feature:update_config{ enabled = true, ["turrets.enabled"] = false }
    Suite.eq(feature.config.turrets.enabled, false, "spawn_area can be changed")
    Suite.eq(feature.config.turrets.ammo_type, "uranium-rounds-magazine", "other values keep their default")
end)

return Suite.run()
