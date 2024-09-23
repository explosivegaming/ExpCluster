--[[-- Core Module - Async
- An extention of task and token to allow a single require to register and run async functions.
@core Async
@alias Async

@usage
-- To use Async you must register the allowed functions when the file is loaded, often this will just be giving access to
-- some functions within a module if you expect that at part may be blocked by in game permissions or a custom system you have made
-- you may also want to register functions that you want to have a time delay, such as waiting 2 seconds before printing a message

-- When player.admin is called (either command or gui element event) by a player who isnt admin then it will error
-- here we register the function to promote the player so that it will run async and outside the player scope
local promote_player =
Async.register(function(player)
    player.admin = true
end)

-- This will allow us to bypass the error by running one tick later outside of any player scope
Async(promote_player, game.player)

-- Here we make an sync function that we want to have a delay, note the delay is not defined here
local print_message =
Async.register(function(player, message)
    player.print(message)
end)

-- We can then call the async function with a delay using the wait function
Async.wait(60, print_message, game.player, 'One second has passed!')

]]
local Task = require 'utils.task' --- @dep utils.task
local Token = require 'utils.token' --- @dep utils.token

local Async = {}

local internal_run =
Token.register(function(params)
    local func = Token.get(params.token)
    return func(table.unpack(params.params))
end)

--[[-- Register a new async function, must called when the file is loaded
@function register
@tparam function callback the function that can be called as an async function
@treturn string the uid of the async function which can be passed to Async.run and Async.wait

@usage-- Registering a function to set the admin state of a player
local set_admin =
Async.register(function(player, state)
    if player.valid then
        player.admin = state
    end
end)

@usage-- Registering a function to print to a player
local print_to_player =
Async.register(function(player, message)
    if player.valid then
        player.print(message)
    end
end)

]]
Async.register = Token.register

--[[-- Runs an async function, you may supply any number of arguments as required by that function
@tparam string token the token of the async function you want to run
@tparam[opt] any ... the other params that you want to pass to your function

@usage-- Make a player admin regardless of if you are admin
Async.run(set_admin, player, true)

]]
function Async.run(token, ...)
    Task.queue_task(internal_run, {
        token = token,
        params = {...}
    })
end

--[[-- Runs an async function after the given number of ticks, you may supply any number of arguments as required by that function
@tparam number ticks the number of ticks that you want the function to run after
@tparam string token the token of the async function you want to run
@tparam[opt] any ... the other params that you want to pass to your function

@usage-- Print a message to a player after 5 seconds
Async.wait(300, print_to_player, 'Hello, World!')

]]
function Async.wait(ticks, token, ...)
    Task.set_timeout_in_ticks(ticks, internal_run, {
        token = token,
        params = {...}
    })
end

return setmetatable(Async, {
    __call = function(self, ...)
        self.run(...)
    end
})