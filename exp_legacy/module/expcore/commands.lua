--[[-- Core Module - Commands
- Factorio command making module that makes commands with better parse and more modularity
@core Commands
@alias Commands

@usage--- Full code example, see below for explanation
Commands.new_command('repeat-name', 'Will repeat you name a number of times in chat.')
:add_param('repeat-count', 'number-range-int', 1, 5) -- required int in range 1 to 5 inclusive
:add_param('smiley', true, function(input, player, reject) -- optional boolean default false
    if not input then return end
    input = input:lower()
    if input == 'true' or input == 'yes' then return true end
    return false
end)
:set_defaults{ smiley = false }
:set_flag('admin_only') -- command is admin only
:add_alias('name', 'rname') -- allow alias: name and rname
:register(function(player, repeat_count, smiley, raw)
    game.print(player.name..' used a command with input: '..raw)

    local msg = ') '..player.name
    if smiley then
        msg = ':'..msg
    end

    for 1 = 1, repeat_count do
        Command.print(1..msg)
    end
end)

@usage--- Example Command Explanation:
-- Making commands basics, the commands can be set up with any number of params and flags that you want,
-- you can add aliases for the commands and set default values for optional params and of course register your command callback.
-- In our example we will have a command that will repeat the users name in chat X amount of times and only allow admins to use it.

-- First we create the new command, note this will not register the command to the game this is done at the end.
-- We will call the command "repeat-name" and set the help message as follows:
Commands.new_command('repeat-name', 'Will repeat you name a number of times in chat.')

-- Now for our first param, we have named it "repeat-count" and it will be a required value, between 1 and 5 inclusive:
-- By using "number-range-int" we are saying to use this parser to convert our input text, common ones exist in config.expcore.command_general_parse
:add_param('repeat-count', 'number-range-int', 1, 5)

-- Our second param needs a custom parser, meaning it isnt defined with add_parser, this is an option for when it is unlikely for
-- any other command to use the same input type. In the example it is a boolean type and we are just showing it here as part of the example.
-- As for the param its self it will be called "smiley" and will be optional with a default value of false:
:add_param('smiley', true, function(input, player, reject)
    -- Since it is optional the input can be nil, in which case we just return
    if not input then return end
    -- If it is not nil then we check for a truthy value
    if input == 'true' or input == 'yes' then return true end
    -- Note that because we did not return nil or reject then false will be passed to command callback, see example parse
    return false
end)

-- Once all params are defined you can add some default values for your optional params, the default value will be used only
-- when no value is given as input, if an invalid value is given then the command will fail and the default will not be used, the
-- default can also be a function which is passed the player as an argument and should return a value to be the default.
-- Here we set the default for "smiley" to false:
:set_defaults{smiley=false}

-- Another example of defaults if we have: item, amount[opt], player[opt]
:set_defaults{
    amount = 50, -- More than one value can be set at a time
    player = function(player) return player end -- Default is the player using the command
}

-- Now the params are set up we can alter how the command works, we can set auth flags, add aliases, or enable "auto concat":
:set_flag('admin_only') -- In our case we want "admin_only" to be set to true so only admins can use the command
:add_alias('name', 'rname') -- We also add two aliases here: "name" and "rname" which point to this command
-- :enable_auto_concat() -- We do not use this in our case but this can also be used to enable the "auto concat" feature

-- And finally we want to register a callback to this command, the callback is what defines what the command does, can be as complex as you
-- want it to be, or as simple as our example; the command receives two params plus all param you have defined:
-- 1) the player who used the command
-- 2) in our case repeat_count which will be a number
-- 3) in our case smiley which will be a boolean
-- 4) the raw input; this param is always last as is always present as a catch all
:register(function(player, repeat_count, smiley, raw)
    -- This is to show the value for raw as this is an example command, the log file will also show this
    game.print(player.name..' used a command with input: '..raw)
    local msg = ') '..player.name

    if smiley then
        msg = ':'..msg
    end

    for 1 = 1, repeat_count do
        -- this print function will return ANY value to the user in a desync safe manor, this includes if the command was used through rcon
        Command.print(1..msg)
    end
    -- See below for what can be used here
end)

-- Values that can be returned from register callback
Commands.print(any, colour[opt]) -- This will return any value value to the user including if it is ran through rcon console
Commands.error(message[opt]) -- This returns a warning to the user, aka an error that does not prevent execution of the command
return Commands.error(message[opt]) -- This returns an error to the user, and will halt the command execution, ie no success message is returned
Commands.success(message[opt]) -- Used to return a success message however don't use this method, see below
return Commands.success(message[opt]) -- Will return the success message to the user and your given message, halts execution
return <any> -- If any value is returned then it will be returned to the player via a Commands.success call

@usage--- Example Authenticator:
-- The command system is best used when you can control who uses commands;
-- to do this you need to define an authenticator which is ran every time a command is run;
-- in this example I will show a simple one that requires certain commands to require the user to be a game admin.

-- For our admin only example we will set a flag to true when we want it to be admin only;
-- when we define the command will will use :set_flag('admin_only');
-- then inside the authenticator we will test if the flag is present using: if flags.admin_only then

-- When the authenticator is called by the command handler it will be passed 4 arguments:
-- 1) player - the player who used the command
-- 2) command - the name of the command that is being used
-- 3) flags - the flags which have been set for this command, flags are set with :set_flag(name, value)
-- 4) reject - the reject function which is the preferred method to prevent execution of the command

-- No return is required to allow the command to execute but it is best practice to return true;
-- we do this in two cases in our authenticator:
-- 1) when the "admin_only" flag is not set, which we take assume that any one can use it
-- 2) when the "admin_only" flag is set, and the player is admin

-- When want to prevent execution of the command we must reject it, listed is how that can be done:
-- 1) return false -- this is the most basic rejection and should only be used while testing
-- 2) return reject -- returning the reject function is as a fail safe in case you forget to call it, same as returning false
-- 3) reject() -- this will block execution while allowing further code to be ran in your authenticator
-- 4) reject('This command is for admins only!') -- using reject as a function allows a error message to be returned
-- 5) return reject() -- using return on either case above is best practice as you should execute all your code before rejecting

-- Example Code:
Commands.add_authenticator(function(player, command, flags, reject)
    -- Check if the command is admin only
    if flags.admin_only then
        -- Return true if player is admin, or reject and return error message
        return player.admin or reject('This command is for admins only!')
    else
        -- Return true if command was not admin only
        return true
    end
end)

@usage--- Example Parser:
-- Before you make a command it is important to understand the most powerful feature of this command handler;
-- when you define a command you are able to type the params and have then be parsed and validated before your command is executed;
-- This module should be paired with a general command parse but you may want to create your own.

-- For our example we will create a parse to accept only integer numbers in a given range:
-- 1) we will give it the name "number-range-int" this is the "type" that the input is expected to be
-- 2) when we define the type we will also define the min and max of the range so we can use the function more than once
:add_param('repeat_count', 'number-range-int', 5, 10) -- "repeat_count" is a required "number-range-int" in a range 5 to 10 inclusive

-- The command parse will be passed 3 arguments plus any other which you define, in our case:
-- 1) input - the input that has been given by the user for this param, the role of this function is to transform this value
-- nb: the input is a string but can be nil if the param is marked as optional
-- 2) player - the player who is using the command, this is always present
-- 3) reject - the reject function to throw an error to the user, this is always present
-- 4) range_min - the range min, this is user defined and has the value given when the param is defined
-- 5) range_max - the range max, this is user defined and has the value given when the param is defined

-- When returning from the param parse you have a few options with how to do this:
-- 1) you return the new value for the param (any non nil value) this value is then passed to the command callback
-- 2) not returning will cause a generic invalid error and the command is rejected, not recommenced
-- 3) return reject -- this is just a failsafe in case the function is not called, same as no return
-- 4) return reject() -- will give a shorter error message as you pass a nil custom error
-- 5) return reject('Number entered is not in range: '..range_min..', '..range_max) -- returns a custom error to the user
-- nb: if you do not return reject after you call it then you will still be returning nil so there will be a duplicate error message

-- It should be noted that if you want to expand on an existing parse you can use Commands.parse(type, input, player, reject)
-- this function will either return a new value for the input or nil, if it is nil you should return nil to prevent duplicate
-- error messages to the user:
input = Commands.parse('number-int', input, player, reject)
if not input then return end -- nil check

-- Example Code:
Commands.add_parse('number-range-int', function(input, player, reject, range_min, range_max)
    local rtn = tonumber(input) and math.floor(tonumber(input)) or nil -- converts input to number
    if not rtn or rtn < range_min or rtn > range_max then
        -- the input is either not a number or is outside the range
        return reject('Number entered is not in range: '..range_min..', '..range_max)
    else
        -- returns the input as a number value rather than a string, thus the param is now the correct type
        return rtn
    end
end)

]]

local Game = require 'utils.game' --- @dep utils.game
local player_return, write_json = _C.player_return, _C.write_json --- @dep expcore.common
local trace = debug.traceback

local Commands = {
    --- Constant values used by the command system
    defines = {
        error = 'CommandError',
        unauthorized = 'CommandErrorUnauthorized',
        success = 'CommandSuccess'
    },
    --- An array of all custom commands that are registered
    commands = {},
    --- When true any authenticator error will result in authorization failure, more secure
    authorization_failure_on_error = false,
    --- An array of all custom authenticators that are registered
    authenticators = {},
    --- Used to store default functions which are common parse function such as player or number in range
    parsers = {},
    --- Returns a value to the player, different to success as this does not signal the end of your command
    print = player_return,
    --- The command prototype which stores all command defining functions
    _prototype = {},
}

--- Authentication.
-- Functions that control who can use commands
-- @section auth

--[[-- Adds an authorization function, function used to check if a player if allowed to use a command
@tparam function authenticator The function you want to register as an authenticator
@treturn number The index it was inserted at, used to remove the authenticator

@usage-- If the admin_only flag is set, then make sure the player is an admin
local admin_authenticator =
Commands.add_authenticator(function(player, command, flags, reject)
    if flags.admin_only and not player.admin then
        return reject('This command is for admins only!')
    else
        return true
    end
end)

]]
function Commands.add_authenticator(authenticator)
    local next_index = #Commands.authenticators + 1
    Commands.authenticators[next_index] = authenticator
    return next_index
end

--[[-- Removes an authorization function, can use the index or the function value
@tparam function|number authenticator The authenticator to remove, either the index return from add_authenticator or the function used
@treturn boolean If the authenticator was found and removed successfully

@usage-- Removing the admin authenticator, can not be done during runtime
Commands.remove_authenticator(admin_authenticator)

]]
function Commands.remove_authenticator(authenticator)
    if type(authenticator) == 'number' then
        -- If a number is passed then it is assumed to be the index
        if Commands.authenticators[authenticator] then
            Commands.authenticators[authenticator] = nil
            return true
        end
    else
        -- will search the array and remove the key
        for index, value in pairs(Commands.authenticators) do
            if value == authenticator then
                Commands.authenticators[index] = nil
                return true
            end
        end
    end
    return false
end

--[[-- Mostly used internally, calls all authenticators, returns if the player is authorized
@tparam LuaPlayer player The player who is using the command, passed to authenticators
@tparam string command_name The name of the command being used, passed to authenticators
@treturn[1] boolean true Player is authorized
@treturn[1] string commands Define value for success
@treturn[2] boolean false Player is unauthorized
@treturn[2] string|locale_string The reason given by the failed authenticator

@usage-- Test if a player can use "repeat-name"
local authorized, status = Commands.authorize(game.player, 'repeat-name')

]]
function Commands.authorize(player, command_name)
    local command_data = Commands.commands[command_name]
    if not command_data then return false end
    if not player then return true end

    -- This is the reject function given to authenticators
    local failure_message
    local function reject(message)
        failure_message = message or {'expcore-commands.unauthorized'}
        return Commands.defines.unauthorized
    end

    -- This is the internal error function used when an authenticator errors
    local function authenticator_error(err)
        log('[ERROR] Authorization failed: '..trace(err))
        if Commands.authorization_failure_on_error then
            return reject('Internal Error')
        end
    end

    -- Loops over each authenticator, if any return false then then command will not be ran
    for _, authenticator in pairs(Commands.authenticators) do
        -- player: LuaPlayer, command: string, flags: table, reject: function(error_message: string)
        local _, rtn = xpcall(authenticator, authenticator_error, player, command_name, command_data.flags, reject)
        if rtn == false or rtn == Commands.defines.unauthorized or rtn == reject or failure_message ~= nil then
            if failure_message == nil then failure_message = {'expcore-commands.unauthorized'} end
            return false, failure_message
        end
    end

    return true, Commands.defines.success
end

--- Parse.
-- Functions that help with parsing
-- @section parse

--[[-- Adds a parse function which can be called by name (used in add_param)
nb: this is not required as you can use the callback directly this just allows it to be called by name
@tparam string name The name of the parse, should describe a type of input such as number or player, must be unique
@tparam function parser The function that is ran to parse the input string
@treturn boolean Was the parse added, will be false if the name is already used

@usage-- Adding a parse to validate integers in a given range
Commands.add_parse('number-range-int', function(input, player, reject, range_min, range_max)
    local rtn = tonumber(input) and math.floor(tonumber(input)) or nil -- converts input to number
    if not rtn or rtn < range_min or rtn > range_max then
        -- The input is either not a number or is outside the range
        return reject('Number entered is not in range: '..range_min..', '..range_max)
    else
        -- Returns the input as a number rather than a string, thus the param is now the correct type
        return rtn
    end
end)

]]
function Commands.add_parse(name, parser)
    if Commands.parsers[name] then return false end
    Commands.parsers[name] = parser
    return true
end

--[[-- Removes a parse function, see add_parse for adding them, cant be done during runtime
@tparam string name The name of the parse to remove

@usage-- Removing a parse
Commands.remove_parse('number-range-int')

]]
function Commands.remove_parse(name)
    Commands.parsers[name] = nil
end

--[[-- Intended to be used within other parse functions, runs a parse and returns success and new value
@tparam string name The name of the parse to call, must be a registered parser
@tparam string input The input to pass to the parse, must be a string but not necessarily the original input
@tparam LuaPlayer player The player that is using the command, pass directly from your arguments
@tparam function reject The reject function, pass directly from your arguments
@treturn any The new value for the input, if nil is return then either there was an error or the input was nil

@usage-- Parsing an int after first checking it is a number
Commands.add_parse('number', function(input, player, reject)
    local number = tonumber(input)
    if number then return number end
    return reject('Input must be a number value')
end)

Commands.add_parse('number-int', function(input, player, reject)
    local number = Commands.parse('number', input, player, reject)
    if not number then return end
    return math.floor(number)
end)

]]
function Commands.parse(name, input, player, reject, ...)
    if not Commands.parsers[name] then return end
    local success, rtn = pcall(Commands.parsers[name], input, player, reject, ...)
    if not success then error(rtn, 2) return end
    if not rtn or rtn == Commands.defines.error then return end
    return rtn
end

--- Getters.
-- Functions that get commands
-- @section getters

--[[-- Gets all commands that a player is allowed to use, game commands are not included
@tparam[opt] LuaPlayer player The player that you want to get commands of, nil will return all commands
@treturn table All commands that that player is allowed to use, or all commands

@usage-- Get the commands you are allowed to use
local commands = Commands.get(game.player)

@usage-- Get all commands that are registered
local commands = Commands.get()

]]
function Commands.get(player)
    player = Game.get_player_from_any(player)

    if not player then
        return Commands.commands
    end

    local allowed = {}

    for name, command_data in pairs(Commands.commands) do
        if Commands.authorize(player, name) then
            allowed[name] = command_data
        end
    end

    return allowed
end

--[[-- Searches command names and help messages to find possible commands, game commands are included
@tparam string keyword The word which you are trying to find in your search
@tparam[opt] LuaPlayer player The player to get allowed commands of, if nil all commands are searched
@treturn table All commands that contain the key word, and allowed by the player if a player was given

@usage-- Get all commands which "repeat"
local commands = Commands.search('repeat')

@usage-- Get all commands which "repeat" and you are allowed to use
local commands = Commands.search('repeat', game.player)

]]
function Commands.search(keyword, player)
    local custom_commands = Commands.get(player)
    local matches = {}
    keyword = keyword:lower()

    -- Loops over custom commands
    for name, command_data in pairs(custom_commands) do
        -- combines name help and aliases into one message to be searched
        local search = string.format('%s %s %s %s', name, command_data.help, command_data.searchable_description, table.concat(command_data.aliases, ' '))

        if search:lower():match(keyword) then
            matches[name] = command_data
        end
    end

    -- Loops over the names of game commands
    for name, description in pairs(commands.game_commands) do
        if name:lower():match(keyword) then
            -- because game commands lack some stuff that the custom ones have they are formatted
            matches[name] = {
                name = name,
                help = description,
                description = '',
                aliases = {}
            }
        end
    end

    return matches
end

--- Creation.
-- Functions that create a new command
-- @section creation

--[[-- Creates a new command object to added details to, this does not register the command to the game api
@tparam string name The name of the command to be created
@tparam string help The help message for the command
@treturn table This will be used with other functions to define the new command

@usage-- Define a new command
Commands.new_command('repeat-name', 'Will repeat you name a number of times in chat.')

]]
function Commands.new_command(name, help, descr)
    local command = setmetatable({
        name = name,
        help = help,
        searchable_description = descr or '',
        callback = function() Commands.internal_error(false, name, 'No callback registered') end,
        auto_concat = false,
        min_param_count = 0,
        max_param_count = 0,
        flags   = {}, -- stores flags that can be used by auth
        aliases = {}, -- stores aliases to this command
        params  = {}, -- [param_name] = {optional: boolean, default: any, parse: function, parse_args: table}
    }, {
        __index = Commands._prototype
    })

    Commands.commands[name] = command

    return command
end

--[[-- Adds a new param to the command this will be displayed in the help and used to parse the input
@tparam string name The name of the new param that is being added to the command
@tparam[opt=false] boolean optional Is this param optional, these must be added after all required params
@tparam[opt] ?string|function parse This function will take the input and return a new value, if not given no parse is done
@tparam[opt] any ... Extra args you want to pass to the parse function; for example if the parse is general use
@treturn table Pass through to allow more functions to be called

@usage-- Adding a required param which has a parser pre-defined
command:add_param('repeat-count', 'number-range-int', 1, 5)

@usage-- Adding an optional param which has a custom parse, see Commands.add_parse for details
command:add_param('smiley', true, function(input, player, reject)
    if not input then return end
    return input:lower() == 'true' or input:lower() == 'yes' or false
end)

]]
function Commands._prototype:add_param(name, optional, parse, ...)
    local parse_args = {...}
    if type(optional) ~= 'boolean' then
        parse_args = {parse, ...}
        parse = optional
        optional = false
    end

    self.params[name] = {
        optional   = optional,
        parse      = parse or function(string) return string end,
        parse_args = parse_args
    }

    self.max_param_count = self.max_param_count + 1
    if not optional then
        self.min_param_count = self.min_param_count + 1
    end

    return self
end

--[[-- Add default values to params, only as an effect if the param is optional, if default value is a function it is called with the acting player
@tparam table defaults A table which is keyed by the name of the param and the value is the default value for that param
@treturn table Pass through to allow more functions to be called

@usage-- Adding default values
command:set_defaults{
    smiley = false,
    -- not in example just used to show arguments given
    player_name = function(player)
        return player.name
    end
}

]]
function Commands._prototype:set_defaults(defaults)
    for name, value in pairs(defaults) do
        if self.params[name] then
            self.params[name].default = value
        end
    end
    return self
end

--[[-- Adds a flag to the command which is passed via the flags param to the authenticators, can be used to assign command roles or usage type
@tparam string name The name of the flag to be added, set to true if no value is given
@tparam[opt=true] any value The value for the flag, can be anything that the authenticators are expecting
@treturn table Pass through to allow more functions to be called

@usage-- Setting a custom flag
command:set_flag('admin_only', true)

@usage-- When value is true it does not need to be given
command:set_flag('admin_only')

]]
function Commands._prototype:set_flag(name, value)
    self.flags[name] = value or true
    return self
end

--[[-- Adds an alias, or multiple, that will be registered to this command, eg /teleport can be used as /tp
@tparam string ... Any amount of aliases that you want this command to be callable with
@treturn table Pass through to allow more functions to be called

@usage-- Added multiple aliases to a command
command:add_alias('name', 'rname')

]]
function Commands._prototype:add_alias(...)
    local start_index = #self.aliases
    for index, alias in ipairs{...} do
        self.aliases[start_index+index] = alias
    end
    return self
end

--[[-- Enables auto concatenation for this command, all params after the last are added to the last param, useful for reasons or other long text input
nb: this will disable max param checking as they will be concatenated onto the end of that last param
@treturn table Pass through to allow more functions to be called

@usage-- Enable auto concat for a command
command:enable_auto_concat()

]]
function Commands._prototype:enable_auto_concat()
    self.auto_concat = true
    return self
end

--[[-- Adds the callback to the command and registers: aliases, params and help message with the base game api
nb: this must be the last function ran on the command and must be done for the command to work
@tparam function callback The callback for the command, will receive the player running command, and any params added with add_param

@usage-- Registering your command to the base game api
command:register(function(player, repeat_count, smiley, raw)
    local msg = ') '..player.name
    if smiley then msg = ':'..msg end

    for 1 = 1, repeat_count do
        Command.print(1..msg)
    end
end)

]]
function Commands._prototype:register(callback)
    self.callback = callback

    -- Generates a description to be used
    local description = ''
    for param_name, param_details in pairs(self.params) do
        if param_details.optional then
            description = string.format('%s [%s]', description, param_name)
        else
            description = string.format('%s <%s>', description, param_name)
        end
    end
    self.description = description

    -- Last resort error handler for commands
    local function command_error(err)
        Commands.internal_error(false, self.name, trace(err))
    end

    -- Callback that the game will call
    local function command_callback(event)
        event.name = self.name
        xpcall(Commands.run_command, command_error, event)
    end

    -- Registers the command under its own name
    local help = {'expcore-commands.command-help', description, self.help}
    commands.add_command(self.name, help, command_callback)

    -- Adds any aliases that it has
    for _, alias in pairs(self.aliases) do
        if not commands.commands[alias] and not commands.game_commands[alias] then
            commands.add_command(alias, help, command_callback)
        end
    end
end

--- Status.
-- Functions that indicate status
-- @section status

--[[-- Sends a value to the player, followed by a command complete message, returning a value will trigger this automatically
@tparam[opt] any value The value to return to the player, if nil then only the success message is returned
@treturn Commands.defines.success Return this to the command handler to prevent two success messages

@usage-- Print a custom success message
return Commands.success('Your message has been printed')

@usage-- Returning the value has the same result
return 'Your message has been printed'

]]
function Commands.success(value)
    if value ~= nil then player_return(value) end
    player_return({'expcore-commands.command-ran'}, 'cyan')
    return Commands.defines.success
end

--[[-- Sends a value to the player, different to success as this does not signal the end of your command
@function print
@tparam any value The value that you want to return to the player
@tparam table colour The colour of the message that the player sees

@usage-- Output a message to the player
Commands.print('Your command is in progress')

]]

--[[-- Sends an error message to the player and when returned will stop execution of the command
nb: this is for non fatal errors meaning there is no log of this event, use during register callback
@tparam[opt=''] string error_message An optional error message that can be sent to the user
@tparam[opt=utility/wire_pickup] string play_sound The sound to play for the error
@treturn Commands.defines.error Return this to command handler to terminate execution

@usage-- Send an error message to the player, and stops further code running
return Commands.error('The player you selected is offline')

]]
function Commands.error(error_message, play_sound)
    error_message = error_message or ''
    player_return({'expcore-commands.command-fail', error_message}, 'orange_red')
    if play_sound ~= false then
        play_sound = play_sound or 'utility/wire_pickup'
        if game.player then game.player.play_sound{path=play_sound} end
    end
    return Commands.defines.error
end

--[[-- Sends an error to the player and logs the error, used internally please avoid direct use
nb: use error(error_message) within your callback to trigger do not trigger directly as code execution may still continue
@tparam boolean success The success value returned from pcall, or just false to trigger error
@tparam string command_name The name of the command this is used within the log
@tparam string error_message The error returned by pcall or some other error, this is logged and not returned to player
@treturn boolean The opposite of success so true means to cancel execution, used internally

@usage-- Used in the command system to log handler errors
local success, err = pcall(command_data.callback, player, table.unpack(params))
if Commands.internal_error(success, command_data.name, err) then
    return command_log(player, command_data, 'Internal Error: Command Callback Fail', raw_params, command_event.parameter, err)
end

]]
function Commands.internal_error(success, command_name, error_message)
    if not success then
        Commands.error('Internal Error, Please contact an admin', 'utility/cannot_build')
        log{'expcore-commands.command-error-log-format', command_name, error_message}
    end
    return not success
end

--- Logs command usage to file
local function command_log(player, command, comment, params, raw, details)
    local player_name = player and player.name or '<Server>'
    write_json('log/commands.log', {
        player_name  = player_name,
        command_name = command.name,
        comment      = comment,
        details      = details,
        params       = params,
        raw          = raw
    })
end

--- Main event function that is ran for all commands, used internally please avoid direct use
-- @tparam table command_event Passed directly from the add_command function
-- @usage Commands.run_command(event)
function Commands.run_command(command_event)
    local command_data = Commands.commands[command_event.name]
    -- Player can be nil when it is the server
    local player
    if command_event.player_index and command_event.player_index > 0 then
        player = game.players[command_event.player_index]
    end

    -- Check if the player is allowed to use the command
    local authorized, auth_fail = Commands.authorize(player, command_data.name)
    if not authorized then
        command_log(player, command_data, 'Failed Auth', {}, command_event.parameter)
        Commands.error(auth_fail, 'utility/cannot_build')
        return
    end

    -- Check for parameter being nil
    if command_data.min_param_count > 0 and not command_event.parameter then
        command_log(player, command_data, 'No Params Given', {}, command_event.parameter)
        Commands.error{'expcore-commands.invalid-inputs', command_data.name, command_data.description}
        return
    end

    -- Extract quoted arguments
    local raw_input = command_event.parameter or ''
    local quote_params = {}
    local input_string = raw_input:gsub('"[^"]-"', function(word)
        local no_spaces = word:gsub('%s', '%%s')
        quote_params[no_spaces] = word:sub(2, -2)
        return ' '..no_spaces..' '
    end)

    -- Extract unquoted arguments
    local raw_params = {}
    local last_index = 0
    local param_number = 0
    for word in input_string:gmatch('%S+') do
        param_number = param_number + 1
        if param_number > command_data.max_param_count then
            -- there are too many params given to the command
            if not command_data.auto_concat then
                -- error as they should not be more
                command_log(player, command_data, 'Invalid Input: Too Many Params', raw_params, raw_input)
                Commands.error{'expcore-commands.invalid-inputs', command_data.name, command_data.description}
                return
            else
                -- concat to the last param
                if quote_params[word] then
                    raw_params[last_index] = raw_params[last_index]..' "'..quote_params[word]..'"'
                else
                    raw_params[last_index] = raw_params[last_index]..' '..word
                end
            end
        else
            -- new param that needs to be added
            if quote_params[word] then
                last_index = last_index + 1
                raw_params[last_index] = quote_params[word]
            else
                last_index = last_index + 1
                raw_params[last_index] = word
            end
        end
    end

    -- Check the param count
    local param_count = #raw_params
    if param_count < command_data.min_param_count then
        command_log(player, command_data, 'Invalid Input: Not Enough Params', raw_params, raw_input)
        Commands.error{'expcore-commands.invalid-inputs', command_data.name, command_data.description}
        return
    end

    -- Parse the arguments
    local index = 1
    local params = {}
    for param_name, param_data in pairs(command_data.params) do
        local parse_callback = param_data.parse
        -- If its a string this get it from the parser table
        if type(parse_callback) == 'string' then
            parse_callback = Commands.parsers[parse_callback]
        end

        -- If its not a function throw and error
        if type(parse_callback) ~= 'function' then
            Commands.internal_error(false, command_data.name, 'Invalid param parse '..tostring(param_data.parse))
            command_log(player, command_data, 'Internal Error: Invalid Param Parse', params, raw_input, tostring(param_data.parse))
            return
        end

        -- This is the reject function given to parse callbacks
        local function reject(error_message)
            error_message = error_message or ''
            command_log(player, command_data, 'Invalid Param Given', raw_params, input_string)
            return Commands.error{'expcore-commands.invalid-param', param_name, error_message}
        end

        -- input: string, player: LuaPlayer, reject: function, ... extra args
        local success, param_parsed = pcall(parse_callback, raw_params[index], player, reject, table.unpack(param_data.parse_args))
        if Commands.internal_error(success, command_data.name, param_parsed) then
            return command_log(player, command_data, 'Internal Error: Param Parse Fail', params, raw_input, param_parsed)
        end

        if param_data.optional == true and raw_params[index] == nil then
            -- If the param is optional and nil then it is set to default
            param_parsed = param_data.default
            if type(param_parsed) == 'function' then
                success, param_parsed = pcall(param_parsed, player)
                if Commands.internal_error(success, command_data.name, param_parsed) then
                    return command_log(player, command_data, 'Internal Error: Default Value Fail', params, raw_input, param_parsed)
                end
            end

        elseif param_parsed == nil or param_parsed == Commands.defines.error or param_parsed == reject then
            -- No value was returned or error was returned, if nil then give generic error
            if param_parsed ~= Commands.defines.error then
                command_log(player, command_data, 'Invalid Param Given', raw_params, raw_input, param_name)
                Commands.error{'expcore-commands.command-error-param-format', param_name, 'please make sure it is the correct type'}
            end
            return

        end

        -- Add the param to the table to be passed to the command callback
        params[index] = param_parsed
        index = index + 1
    end

    -- Run the command
    -- player: LuaPlayer, ... command params, raw: string
    params[command_data.max_param_count+1] = raw_input
    local success, rtn = pcall(command_data.callback, player, table.unpack(params))
    if Commands.internal_error(success, command_data.name, rtn) then
        return command_log(player, command_data, 'Internal Error: Command Callback Fail', raw_params, command_event.parameter, rtn)
    end

    -- Give output to the player
    if rtn == Commands.defines.error or rtn == Commands.error then
        return command_log(player, command_data, 'Custom Error', raw_params, raw_input)
    elseif rtn ~= Commands.defines.success and rtn ~= Commands.success then
        Commands.success(rtn)
    end
    command_log(player, command_data, 'Success', raw_params, raw_input)
end

return Commands
