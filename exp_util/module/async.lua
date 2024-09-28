--[[-- Util Module - Async
- Provides a method of spreading work across multiple ticks and running functions at a later time
@core Async
@alias Async

@usage-- Bypass permission groups
-- This is a simple example, you should have some kind of validation to prevent security flaws
local function setAdmin(player, state)
    player.admin = state
end

local setAdminAsync = Async.register(setAdmin)
setAdminAsync(game.players[1], true)

@usage-- Functions stored in storage table
-- This can be used to create run time configurable callbacks, although this is not recommended
storage.myCallback = Async.register(function()
    game.print("I got called!")
end)

-- The function can be called just like any other function
storage.myCallback()

@usage-- Creating singleton tasks (best used with storage data)
-- This allows you to split large tasks across multiple ticks to prevent lag
local myTask = Async.register(function(remainingWork)
    game.print("Working... " .. remainingWork)
    if remainingWork > 0 then
        return Async.status.continue(remainingWork - 1)
    end
end)

myTask:start_task(10) -- Queues the task
myTask:start_task(10) -- Does nothing, task is already running
myTask:start_now(10) -- Ignores the already running instance and starts a second one

@usage-- Actions with variable delays
-- on_nth_tick is great for consistent delays, but tasks allow for variable delays
local linearBackoff = Async.register(function(startingDelay, remainingWork)
    game.print("Working... " .. remainingWork)
    if remainingWork > 0 then
        local newDelay = startingDelay + 1
        return Async.status.delay(newDelay, newDelay, remainingWork - 1)
    end
end)

linearBackoff(1, 10)

@usage-- Getting return values
-- you can capture the return values of an async function using the event
local fillTableAsync = Async.register(function(tbl, val, remainingWork)
    table.insert(tbl, val)
    if remainingWork > 0 then
        return Async.status.continue(tbl, val, remainingWork - 1)
    else
        return Async.status.complete(tbl)
    end
end)

local function on_function_complete(event)
    if event.async_id ~= fillTableAsync.id then return end
    local filledTable = table.unpack(event.return_values)
    game.print("Table has length of " .. #filledTable)
end

fillTableAsync({}, "foo", 10) -- Puts 10 lots of foo into the table

]]

local Clustorio = require("modules/clusterio/api")
local ExpUtil = require("modules/exp_util/common")

local Async = {
    status = {}, -- Stores the allowed return types from a async function
    events = {}, -- Stores all event handlers for this module
    _prototype = {}, -- Prototype of the async function type
    _queue_pressure = {}, -- Stores the count of each function in the queue to avoid queue iteration during start_task
    _functions = {}, -- Stores a reference to all registered functions
    --- Raised when any async function has finished execution
    -- @event on_function_complete
    -- @tparam AsyncFunction async_id The function which finished execution, comparable to the return of register
    -- @tparam table return_values An array representing the values returned by the completed function
    on_function_complete = script.generate_event_name(),
}

Async._metatable = {
    __call = function(self, ...) Async._prototype.start_soon(self, ...) end,
    __index = Async._prototype,
    __class = "AsyncFunction",
}

script.register_metatable("AsyncFunction", Async._metatable)

--- Globals
local async_next -- Stores a queue of async functions to be executed on the next tick
local async_queue -- Stores a queue of async functions to be executed on a later tick
local on_tick_mutex = false -- It is not safe to modify the globals while this value is true

--- Insert an item into the priority queue
local function add_to_queue(pending)
    local tick = pending.tick
    for index = #async_queue, 1, -1 do
        if async_queue[index].tick >= tick then
            async_queue[index + 1] = pending
            return
        else
            async_queue[index + 1] = async_queue[index]
        end
    end

    async_queue[1] = pending
end

--- Static Methods.
-- Static methods of the class
-- @section async-static

--- Register a new async function
-- @tparam function func The function which becomes the async function
-- @treturn AsyncFunction The newly registered async function
function Async.register(func)
    ExpUtil.assert_not_runtime()
    ExpUtil.assert_argument_type(func, "function", 1, "func")

    local id = ExpUtil.get_function_name(func)
    Async._functions[id] = func
    Async._queue_pressure[id] = 0

    return setmetatable({ id = id }, Async._metatable)
end

--- Prototype Methods.
-- Prototype methods of the class instances
-- @section async-prototype

--- Run an async function on the next tick, this is the default and can be used to bypass permission groups
-- @param ... The arguments to call the function with
function Async._prototype:start_soon(...)
    assert(not on_tick_mutex, "Cannot queue new async call during execution of another")
    assert(Async._functions[self.id], "Async function is not registered")
    Async._queue_pressure[self.id] = Async._queue_pressure[self.id] + 1

    async_next[#async_next + 1] = {
        id = self.id,
        args = { ... },
    }
end

--- Run an async function after the given number of ticks
-- @tparam number ticks The number of ticks to call the function after
-- @param ... The arguments to call the function with
function Async._prototype:start_after(ticks, ...)
    ExpUtil.assert_argument_type(ticks, "number", 1, "ticks")
    assert(not on_tick_mutex, "Cannot queue new async call during execution of another")
    assert(Async._functions[self.id], "Async function is not registered")
    Async._queue_pressure[self.id] = Async._queue_pressure[self.id] + 1

    add_to_queue{
        id = self.id,
        args = { ... },
        tick = game.tick + ticks,
    }
end

--- Run an async function on the next tick if the function is not already queued, allows singleton task/thread behaviour
-- @param ... The arguments to call the function with
function Async._prototype:start_task(...)
    assert(not on_tick_mutex, "Cannot queue new async call during execution of another")
    assert(Async._functions[self.id], "Async function is not registered")
    if Async._queue_pressure[self.id] > 0 then return end
    self:start_soon(...)
end

--- Run an async function on this tick, then queue it based on its return value
-- @param ... The arguments to call the function with
function Async._prototype:start_now(...)
    assert(not on_tick_mutex, "Cannot queue new async call during execution of another")
    assert(Async._functions[self.id], "Async function is not registered")
    local status, rtn1, rtn2 = Async._functions[self.id](...)
    if status == Async.status.continue then
        self:start_soon(table.unpack(rtn1))
    elseif status == Async.status.delay then
        self:start_after(rtn1, table.unpack(rtn2))
    elseif status == Async.status.complete or status == nil then
        -- The function has finished execution, raise the custom event
        script.raise_event(Async.on_function_complete, {
            event = Async.on_function_complete,
            tick = game.tick,
            async_id = self.id,
            returned = rtn1,
        })
    else
        error("Async function " .. self.id .. " returned an invalid status: " .. table.inspect(status))
    end
end

--- Status Returns.
-- Return values used by async functions
-- @section async-status

local empty_table = setmetatable({}, {
    __index = function() error("Field 'Returned' is Immutable") end,
}) -- File scope to allow for reuse

--- Default status, will raise on_function_complete
-- @param ... The return value of the async call
function Async.status.complete(...)
    if ... == nil then
        return Async.status.complete, empty_table
    end
    return Async.status.complete, { ... }
end

--- Will queue the function to be called again on the next tick using the new arguments
-- @param ... The arguments to call the function with
function Async.status.continue(...)
    if ... == nil then
        return Async.status.continue, empty_table
    end
    return Async.status.continue, { ... }
end

--- Will queue the function to be called again on a later tick using the new arguments
-- @param ... The arguments to call the function with
function Async.status.delay(ticks, ...)
    ExpUtil.assert_argument_type(ticks, "number", 1, "ticks")
    if ... == nil then
        return Async.status.continue, ticks, empty_table
    end
    return Async.status.delay, ticks, { ... }
end

--- Executes an async function and processes the return value
local function exec(pending, tick, new_next, new_queue)
    local status, rtn1, rtn2 = Async._functions[pending.id](table.unpack(pending.args))
    if status == Async.status.continue then
        new_next[#new_next + 1] = pending
        pending.tick = nil
        pending.args = rtn1
    elseif status == Async.status.delay then
        new_queue[#new_queue + 1] = pending
        pending.tick = tick + rtn1
        pending.args = rtn2
    elseif status == Async.status.complete or status == nil then
        -- The function has finished execution, raise the custom event
        Async._queue_pressure[pending.id] = Async._queue_pressure[pending.id] - 1
        script.raise_event(Async.on_function_complete, {
            event = Async.on_function_complete,
            tick = tick,
            async_id = pending.id,
            returned = rtn1,
        })
    else
        error("Async function " .. pending.id .. " returned an invalid status: " .. table.inspect(status))
    end
end

local new_next, new_queue = {}, {} -- File scope to allow for reuse
--- Each tick, run all next tick functions, then check if any in the queue need to be executed
local function on_tick()
    if async_next == nil then return end
    local tick = game.tick

    -- Execute all pending functions
    for index = 1, #async_next, 1 do
        exec(async_next[index], tick, new_next, new_queue)
        async_next[index] = nil
    end

    for index = #async_queue, 1, -1 do
        local pending = async_queue[index]
        if pending.tick > tick then
            break
        end
        exec(pending, tick, new_next, new_queue)
        async_queue[index] = nil
    end

    -- Queue any functions that did not complete
    for index = 1, #new_next, 1 do
        async_next[index] = new_next[index]
        new_next[index] = nil
    end

    for index = 1, #new_queue, 1 do
        add_to_queue(new_next[index])
        new_next[index] = nil
    end
end

--- On load, check the queue status and update the pressure values
function Async.on_load()
    if storage.exp_async_next == nil then return end
    async_next = storage.exp_async_next
    async_queue = storage.exp_async_queue
    for _, pending in ipairs(async_next) do
        local count = Async._queue_pressure[pending.id]
        if count == nil then
            log("Warning: Pending async function missing after load: " .. pending.id)
            Async._functions[pending.id] = function() end -- NOP
            count = 0
        end
        Async._queue_pressure[pending.id] = count + 1
    end

    for _, pending in ipairs(async_queue) do
        local count = Async._queue_pressure[pending.id]
        if count == nil then
            log("Warning: Pending async function missing after load: " .. pending.id)
            Async._functions[pending.id] = function() end -- NOP
            count = 0
        end
        Async._queue_pressure[pending.id] = count + 1
    end
end

--- On server startup initialise the storage data
function Async.on_init()
    if storage.exp_async_next == nil then
        storage.exp_async_next = {}
        storage.exp_async_queue = {}
    end
    Async.on_load()
end

Async.events[defines.events.on_tick] = on_tick
Async.events[Clustorio.events.on_server_startup] = Async.on_init
return Async
