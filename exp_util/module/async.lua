--[[-- ExpUtil - Async
Provides a method of spreading work across multiple ticks and running functions at a later time

--- Bypass permission groups
-- This is a simple example, you should have some kind of validation to prevent security flaws
local function setAdmin(player, state)
    player.admin = state
end

local set_admin_async = Async.register(setAdmin)
set_admin_async(game.players[1], true)

--- Functions stored in storage table
-- Async functions and return values are safe to store in storage
-- However they must be registered during the control stage
local function say_hello(name)
    game.print("Hello " .. name)
end

storage.say_hello_async = Async.register(say_hello)

-- The function can be called just like any other function
storage.say_hello_async("John")

-- Run the function this tick rather than the default of next tick
storage.say_hello_async:start_now("Dave")

-- Call the function after 60 ticks
storage.say_hello_async:start_after(60, "Steve")

-- You can cancel any task or function call that hasn't returned
-- You can store this task in storage to cancel at any time, or poll if it returned
local task = storage.say_hello_async:start_after(30, "Kevin")
task:cancel()

--- Creating multi tick tasks (best used with storage data)
-- This allows you to split large tasks across multiple ticks to prevent lag
local my_task = Async.register(function(words)
    game.print(table.remove(words))
    if #words > 0 then
        return Async.status.continue(words)
    end
end)

my_task:start_task{ "foo", "bar", "baz" } -- Queues the task
my_task:start_task{ "A", "B", "C" } -- Does nothing, task is already running
my_task:start_soon{ "1", "2", "3" } -- Ignores the already running instance and starts a second one
my_task:start_now{ "X", "Y", "Z" } -- Same as start_soon but will run once this tick then queues the remainder

--- Actions with variable delays
-- on_nth_tick is great for consistent delays, but tasks allow for variable delays
local linear_backoff = Async.register(function(startingDelay, remainingWork)
    game.print("Working... " .. remainingWork)
    if remainingWork > 0 then
        local newDelay = startingDelay + 1
        return Async.status.delay(newDelay, newDelay, remainingWork - 1)
    end
end)

linear_backoff(1, 10)

--- Getting return values
-- You can capture the return values of an async function using another async function
-- Note that you can not chain calls to return_to only one return capture is allowed
local fill_table_async = Async.register(function(tbl, val, remainingWork)
    table.insert(tbl, val)
    if remainingWork > 0 then
        return Async.status.continue(tbl, val, remainingWork - 1)
    else
        return Async.status.complete(tbl)
    end
end)

local function print_table_size(tbl)
    game.print("Table has length of " .. #tbl)
end

local print_table_size_async = Async.register(print_table_size)
fill_table_async({}, "foo", 10):return_to(print_table_size_async)

]]

local ExpUtil = require("modules/exp_util")

--- @class ExpUtil_Async
local Async = {
    _queue_pressure = {}, --- @type table<string, number> Stores the count of each function in the queue to avoid queue iteration during start_task
    _registered = {}, --- @type table<string, AsyncFunctionOpen> Stores a reference to all registered functions
}

--- @class ExpUtil_Async.status: table<string, Async.Status>
--- Stores the allowed return types from a async function
Async.status = {}

--- @class Async.AsyncFunction
--- @field id number The id of this async function
--- @operator call: Async.AsyncReturn
Async._function_prototype = {}

Async._function_metatable = {
    __call = nil, -- Async._function_prototype.start_soon,
    __index = Async._function_prototype,
    __class = "AsyncFunction",
}

--- @class Async.AsyncReturn<F>
--- @field func_id number The id of the async function to be called
--- @field args any[] The arguments to call the function with
--- @field tick number? If present, the function will be called on this game tick
--- @field next_id number? The id of the async function to be called with the return value
--- @field canceled boolean? True if the call has been canceled
--- @field returned any[]? The return values of the function call
Async._return_prototype = {} -- Prototype of the async return type

Async._return_metatable = {
    __index = Async._return_prototype,
    __class = "AsyncReturn",
}

script.register_metatable("AsyncFunction", Async._function_metatable)
script.register_metatable("AsyncReturn", Async._return_metatable)

--- Storage Variables

local resolve_next --- @type Async.AsyncReturn[] Stores a queue of async functions to be executed on the next tick
local resolve_queue --- @type Async.AsyncReturn[] Stores a queue of async functions to be executed on a later tick

--- Insert an item into the priority queue
--- @param pending Async.AsyncReturn
--- @return Async.AsyncReturn
local function add_to_next_tick(pending)
    resolve_next[#resolve_next + 1] = pending
    return pending
end

--- Insert an item into the priority queue
--- @param pending Async.AsyncReturn
--- @return Async.AsyncReturn
local function add_to_resolve_queue(pending)
    local tick = pending.tick
    for index = #resolve_queue, 1, -1 do
        if resolve_queue[index].tick >= tick then
            resolve_queue[index + 1] = pending
            return pending
        else
            resolve_queue[index + 1] = resolve_queue[index]
        end
    end

    resolve_queue[1] = pending
    return pending
end

--- Async Return.
-- Similar to a JS promise, it is returned after starting a task and allows awaiting and cancellation
-- Because it would result inefficient code, it is not possible to chain calls to after

--- Cancel an async function from being called
function Async._return_prototype:cancel()
    self.canceled = true
end

--- Assign an async function to be called on completion of this function
--- @param async_func Async.AsyncFunction The function which will be called using start_soon
function Async._return_prototype:return_to(async_func)
    self.next_id = async_func.id
    if self.returned then
        async_func(table.unpack(self.returned))
    end
end

--- Async Function.
-- Functions which can be put in storage and used as tasks to be completed over multiple ticks

--- @alias AsyncFunctionOpen fun(...: any): Async.Status?, any?, any?

--- Register a new async function
--- @param func AsyncFunctionOpen The function which becomes the async function
--- @return Async.AsyncFunction # The newly registered async function
function Async.register(func)
    ExpUtil.assert_not_runtime()
    ExpUtil.assert_argument_type(func, "function", 1, "func")

    local id = ExpUtil.get_function_name(func)
    Async._registered[id] = func
    Async._queue_pressure[id] = 0

    return setmetatable({ id = id }, Async._function_metatable)
end

--- Run an async function on the next tick, this is the default and can be used to bypass permission groups
--- @param ... any The arguments to call the function with
--- @return Async.AsyncReturn
function Async._function_prototype:start_soon(...)
    assert(Async._registered[self.id], "Async function is not registered")
    Async._queue_pressure[self.id] = Async._queue_pressure[self.id] + 1
    return add_to_next_tick(setmetatable({
        func_id = self.id,
        args = { ... },
    }, Async._return_metatable))
end

--- Run an async function after the given number of ticks
--- @param ticks number The number of ticks to call the function after
--- @param ... any The arguments to call the function with
--- @return Async.AsyncReturn
function Async._function_prototype:start_after(ticks, ...)
    ExpUtil.assert_argument_type(ticks, "number", 1, "ticks")
    assert(ticks > 0, "Ticks must be a positive number")
    assert(Async._registered[self.id], "Async function is not registered")
    Async._queue_pressure[self.id] = Async._queue_pressure[self.id] + 1
    return add_to_resolve_queue(setmetatable({
        func_id = self.id,
        args = { ... },
        tick = game.tick + ticks,
    }, Async._return_metatable))
end

--- Run an async function on the next tick if the function is not already queued, allows singleton task/thread behaviour
--- @param ... any The arguments to call the function with
--- @return Async.AsyncReturn | nil
function Async._function_prototype:start_task(...)
    assert(Async._registered[self.id], "Async function is not registered")
    if Async._queue_pressure[self.id] > 0 then return end
    return self:start_soon(...)
end

--- Run an async function on this tick, then queue it based on its return value
--- @param ... any The arguments to call the function with
--- @return Async.AsyncReturn
function Async._function_prototype:start_now(...)
    assert(Async._registered[self.id], "Async function is not registered")
    local status, rtn1, rtn2 = Async._registered[self.id](...)
    if status == Async.status.continue then
        return self:start_soon(table.unpack(rtn1))
    elseif status == Async.status.delay then
        return self:start_after(rtn1, table.unpack(rtn2))
    elseif status == Async.status.complete or status == nil then
        return setmetatable({
            func_id = self.id,
            args = { ... },
            returned = rtn1,
        }, Async._return_metatable)
    else
        error("Async function " .. self.id .. " returned an invalid status: " .. table.inspect(status))
    end
end

--- Status Returns.
-- Return values used by async functions

--- @alias Async.Status (fun(...: any): Async.Status, any[]) | (fun(...: any): Async.Status, number, any[])

local empty_table = setmetatable({}, {
    __index = function() error("Field 'Returned' is Immutable") end,
    __newindex = function() error("Field 'Returned' is Immutable") end,
})

--- Default status, will raise on_function_complete
--- @param ... any The return value of the async call
--- @return Async.Status, any[]
--- @type Async.Status
function Async.status.complete(...)
    if ... == nil then
        return Async.status.complete, empty_table
    end
    return Async.status.complete, { ... }
end

--- Will queue the function to be called again on the next tick using the new arguments
--- @param ... any The arguments to call the function with
--- @return Async.Status, any[]
--- @type Async.Status
function Async.status.continue(...)
    if ... == nil then
        return Async.status.continue, empty_table
    end
    return Async.status.continue, { ... }
end

--- Will queue the function to be called again on a later tick using the new arguments
--- @param ticks number The number of ticks to delay for
--- @param ... any The arguments to call the function with
--- @return Async.Status, number, any[]
--- @type Async.Status
function Async.status.delay(ticks, ...)
    ExpUtil.assert_argument_type(ticks, "number", 1, "ticks")
    assert(ticks > 0, "Ticks must be a positive number")
    if ... == nil then
        return Async.status.continue, ticks, empty_table
    end
    return Async.status.delay, ticks, { ... }
end

--- Status Returns.

--- @type Async.AsyncReturn[], Async.AsyncReturn[]
local new_next, new_queue = {}, {} -- File scope to allow for reuse

--- Executes an async function and processes the return value
--- @param pending Async.AsyncReturn
--- @param tick number
local function exec(pending, tick)
    local async_func = Async._registered[pending.func_id]
    if pending.canceled or async_func == nil then return end
    local status, rtn1, rtn2 = async_func(table.unpack(pending.args))
    if status == Async.status.continue then
        resolve_next[#resolve_next + 1] = pending
        pending.tick = nil
        pending.args = rtn1
    elseif status == Async.status.delay then
        resolve_queue[#resolve_queue + 1] = pending
        pending.tick = tick + rtn1
        pending.args = rtn2
    elseif status == Async.status.complete or status == nil then
        -- The function has finished execution, raise the custom event
        Async._queue_pressure[pending.func_id] = Async._queue_pressure[pending.func_id] - 1
        pending.returned = rtn1
        if pending.next_id then
            resolve_next[#resolve_next + 1] = setmetatable({
                func_id = pending.next_id,
                args = rtn1,
            }, Async._return_metatable)
        end
    else
        error("Async function " .. pending.func_id .. " returned an invalid status: " .. table.inspect(status))
    end
end

--- Each tick, run all next tick functions, then check if any in the queue need to be executed
local function on_tick()
    if resolve_next == nil then return end
    local tick = game.tick

    -- Swap the references around so it is safe to iterate the arrays
    local real_next, real_queue = resolve_next, resolve_queue
    resolve_next, resolve_queue = new_next, new_queue

    -- Execute all pending async functions
    for index = 1, #real_next, 1 do
        exec(real_next[index], tick)
        real_next[index] = nil
    end

    for index = #real_queue, 1, -1 do
        local pending = real_queue[index]
        if pending.tick > tick and not pending.canceled then
            break
        end
        exec(pending, tick)
        real_queue[index] = nil
    end

    -- Swap the references back to normal
    resolve_next, resolve_queue = real_next, real_queue

    -- Queue any functions that were added during the execution of the others
    for index = 1, #new_next, 1 do
        resolve_next[index] = new_next[index]
        new_next[index] = nil
    end

    for index = 1, #new_queue, 1 do
        add_to_resolve_queue(new_queue[index])
        new_queue[index] = nil
    end
end

--- On load, check the queue status and update the pressure values
--- @package
function Async.on_load()
    if storage.exp_async_next == nil then return end
    resolve_next = storage.exp_async_next
    resolve_queue = storage.exp_async_queue

    -- Rebuild the queue pressure table
    for _, pending in ipairs(resolve_next) do
        local count = Async._queue_pressure[pending.func_id]
        if count then
            Async._queue_pressure[pending.func_id] = count + 1
        else
            log("Warning: Pending async function missing after load: " .. pending.func_id)
        end
    end

    for _, pending in ipairs(resolve_queue) do
        local count = Async._queue_pressure[pending.func_id]
        if count then
            Async._queue_pressure[pending.func_id] = count + 1
        else
            log("Warning: Pending async function missing after load: " .. pending.func_id)
        end
    end
end

--- On init and server startup initialise the storage data
--- @package
function Async.on_init()
    if storage.exp_async_next == nil then
        --- @type Async.AsyncReturn[]
        storage.exp_async_next = {}
        --- @type Async.AsyncReturn[]
        storage.exp_async_queue = {}
    end
    Async.on_load()
end

local e = defines.events
local events = {
    [e.on_tick] = on_tick,
    [e.on_singleplayer_init] = Async.on_init,
    [e.on_multiplayer_init] = Async.on_init,
}

Async._function_metatable.__call = Async._function_prototype.start_soon
Async.events = events --- @package
return Async
