local ExpUtil = require("modules/exp_util")

local Event = {
    real_handlers = {
        events = {},
        on_nth_tick = {},
        on_init = nil,
        on_load = nil,
    },
    handlers = {
        events = {},
        on_nth_tick = {},
        on_init = nil,
        on_load = nil,
    },
}

local function call_handlers_factory(handlers)
    return function(event)
        for _, handler in ipairs(handlers) do
            handler(event)
        end
    end
end

function Event.add(event_name, handler)
    ExpUtil.assert_not_runtime()
    ExpUtil.assert_argument_type(event_name, "number", 1, "event_name")
    ExpUtil.assert_argument_type(handler, "function", 2, "handler")

    local handlers = Event.handlers.events[event_name]
    if not handlers then
        handlers = {}
        Event.handlers.events[event_name] = handlers
        Event.real_handlers.events[event_name] = call_handlers_factory(handlers)
    end

    handlers[#handlers + 1] = handler
end

function Event.on_nth_tick(tick, handler)
    ExpUtil.assert_not_runtime()
    ExpUtil.assert_argument_type(tick, "number", 1, "tick")
    ExpUtil.assert_argument_type(handler, "function", 2, "handler")

    local handlers = Event.handlers.on_nth_tick[tick]
    if not handlers then
        handlers = {}
        Event.handlers.on_nth_tick[tick] = handlers
        Event.real_handlers.on_nth_tick[tick] = call_handlers_factory(handlers)
    end

    handlers[#handlers + 1] = handler
end

function Event.on_init(handler)
    ExpUtil.assert_not_runtime()
    ExpUtil.assert_argument_type(handler, "function", 1, "handler")

    local handlers = Event.handlers.on_init
    if not handlers then
        handlers = {}
        Event.handlers.on_init = handlers
        Event.real_handlers.on_init = call_handlers_factory(handlers)
    end

    handlers[#handlers + 1] = handler
    Event.add(defines.events.on_singleplayer_init, handler)
    Event.add(defines.events.on_multiplayer_init, handler)
end

function Event.on_load(handler)
    ExpUtil.assert_not_runtime()
    ExpUtil.assert_argument_type(handler, "function", 1, "handler")

    local handlers = Event.handlers.on_load
    if not handlers then
        handlers = {}
        Event.handlers.on_load = handlers
        Event.real_handlers.on_load = call_handlers_factory(handlers)
    end

    handlers[#handlers + 1] = handler
end

return Event
