--[[-- Core Module - Commands
- Factorio command making module that makes commands with better parse and more modularity
@core Commands
@alias Commands

@usage-- Adding a permission authority
-- You are only required to return a boolean, but by using the unauthorised status you can provide better feedback to the user
Commands.add_permission_authority(function(player, command)
    if command.flags.admin_only and not player.admin then
        return Commands.status.unauthorised("This command requires in-game admin")
    end
    return Commands.status.success()
end)

@usage-- Adding a data type
-- You can not return nil from this function, doing so will raise an error, you must return a status
Commands.add_data_type("integer", function(input, player)
    local number = tonumber(input)
    if number == nil then
        return Commands.status.invalid_input("Value must be a valid number")
    else
        return Commands.status.success(number)
    end
end)

-- It is recommend to use exiting parsers within your own to simplify checks, but make sure to propagate failures
Commands.add_data_type("integer-range", function(input, player, minimum, maximum)
    local success, status, integer = Commands.parse_data_type("integer", input, player)
    if not success then return status, number end

    if integer < minimum or integer > maximum then
        return Commands.status.invalid_input(string.format("Integer must be in range: %d to %d", minimum, maximum))
    else
        return Commands.status.success(integer)
    end
end)

@usage-- Adding a command
Commands.new("repeat", "This is my new command, it will repeat a message a number of times")
:add_flags{ "admin_only" } -- Using the permission authority above, this makes the command admin only
:add_aliases{ "repeat-message" } -- You can add as many aliases as you want
:enable_auto_concatenation() -- This allows the final argument to be any length
:argument("count", "integer-range", 1, 10) -- Allow any value between 1 and 10
:optional("message", "string") -- This is an optional argument
:defaults{
    -- Defaults don't need to be functions, one is used here to demonstrate their use, remember player can be nil for the server
    message = function(player)
        return player and "Hello, "..player.name or "Hello, World!"
    end
}
:register(function(player, count, message)
    for i = 1, count do
        Commands.print("#"..i.." "..message)
    end
end)

]]

local ExpUtil = require("modules/exp_util")
local Color = require("modules/exp_util/include/color")

local Commands = {
    color = Color, -- A useful reference to the color utils to be used with command outputs
    _prototype = {}, -- Contains the methods for the command object
    registered_commands = {}, -- Stores a reference to all registered commands
    permission_authorities = {}, -- Stores a reference to all active permission authorities
    data_types = {}, -- Stores all input parsers and validators for different data types
    status = {}, -- Contains the different status values a command can return
}

Commands._metatable = {
    __index = Commands._prototype,
    __class = "ExpCommand"
}

Commands.player_server = setmetatable({
	index = 0,
	color = Color.white,
	chat_color = Color.white,
	name = "<server>",
	tag = "",
	connected = true,
	admin = true,
	afk_time = 0,
	online_time = 0,
	last_online = 0,
	spectator = true,
	show_on_map = false,
	valid = true,
	object_name = "LuaPlayer"
}, {
	__index = function(_, key)
		if key == "__self" or type(key) == "number" then return nil end
		Commands.error("Command does not support rcon usage, requires reading player." .. key)
		error("Command does not support rcon usage, requires reading player." .. key)
	end,
	__newindex = function(_, key)
		Commands.error("Command does not support rcon usage, requires reading player." .. key)
		error("Command does not support rcon usage, requires setting player." .. key)
	end
})

--- Status Returns.
-- Return values used by command callbacks
-- @section command-status

--- Used to signal success from a command, data type parser, or permission authority
-- @tparam[opt] LocaleString|string msg An optional message to be included when a command completes (only has an effect in command callbacks)
function Commands.status.success(msg)
    return Commands.status.success, msg or {'exp-commands.success'}
end

--- Used to signal an error has occurred in a command, data type parser, or permission authority
-- For data type parsers and permission authority, an error return will prevent the command from being executed
-- @tparam[opt] LocaleString|string msg An optional error message to be included in the output, a generic message is used if not provided
function Commands.status.error(msg)
    return Commands.status.error, {'exp-commands.error', msg or {'exp-commands.error-default'}}
end

--- Used to signal the player is unauthorised to use a command, primarily used by permission authorities but can be used in a command callback
-- For permission authorities, an error return will prevent the command from being executed
-- @tparam[opt] LocaleString|string msg An optional error message to be included in the output, a generic message is used if not provided
function Commands.status.unauthorised(msg)
    return Commands.status.unauthorised, msg or {'exp-commands.unauthorized', msg or {'exp-commands.unauthorized-default'}}
end

--- Used to signal the player provided invalid input to an command, primarily used by data type parsers but can be used in a command callback
-- For data type parsers, an error return will prevent the command from being executed
-- @tparam[opt] LocaleString|string msg An optional error message to be included in the output, a generic message is used if not provided
function Commands.status.invalid_input(msg)
    return Commands.status.invalid_input, msg or {'exp-commands.invalid-input'}
end

--- Used to signal an internal error has occurred, this is reserved for internal use
-- @tparam LocaleString|string msg A message detailing the error which has occurred, will be logged and outputted
function Commands.status.internal_error(msg)
    return Commands.status.internal_error, {'exp-commands.internal-error', msg}
end

local valid_command_status = {} -- Hashmap lookup for testing if a status is valid
for name, status in pairs(Commands.status) do
    valid_command_status[status] = name
end

--- Permission Authority.
-- Functions that control who can use commands
-- @section permission-authority

--- Add a permission authority, a permission authority is a function which provides access control for commands, multiple can be active at once
-- When multiple are active, all authorities must give permission for the command to execute, if any deny access then the command is not ran
-- @tparam function permission_authority The function to provide access control to commands, see module usage.
-- @treturn function The function which was provided as the first argument
function Commands.add_permission_authority(permission_authority)
    local next_index = #Commands.permission_authorities + 1
    Commands.permission_authorities[next_index] = permission_authority
    return permission_authority
end

--- Remove a permission authority, must be the same function reference which was passed to add_permission_authority
-- @tparam function permission_authority The access control function to remove as a permission authority
function Commands.remove_permission_authority(permission_authority)
    local pms = Commands.permission_authorities
    for index, value in pairs(pms) do
        if value == permission_authority then
            local last = #pms
            pms[index] = pms[last]
            pms[last] = nil
            return
        end
    end
end

--- Check if a player has permission to use a command, calling all permission authorities
-- @tparam LuaPlayer player The player to test the permission of, nil represents the server and always returns true
-- @tparam Command command The command the player is attempting to use
-- @treturn boolean true if the player has permission to use the command
-- @treturn LocaleString|string when permission is denied, this is the reason permission was denied
function Commands.player_has_permission(player, command)
    if player == nil or player == Commands.player_server then return true end

    for _, permission_authority in ipairs(Commands.permission_authorities) do
        local status, msg = permission_authority(player, command)
        if type(status) == "boolean" then
            if status == false then
                local _, rtn_msg = Commands.status.unauthorised(msg)
                return false, rtn_msg
            end
        elseif valid_command_status[status] then
            if status ~= Commands.status.success then
                return false, msg
            end
        else
            return false, "Permission authority returned unexpected value"
        end
    end

    return true, nil
end

--- Data Type Parsing.
-- Functions that parse and validate player input
-- @section input-parse-and-validation

--- Add a new input parser to the command library, this allows use of a data type without needing to pass the function directly
-- @tparam string data_type The name of the data type the input parser reads in and validates
-- @tparam function parser The function used to parse and validate the data type
-- @treturn string The data type passed as the first argument
function Commands.add_data_type(data_type, parser)
    if Commands.data_types[data_type] then
        error("Data type \""..tostring(data_type).."\" already has a parser registered", 2)
    end
    Commands.data_types[data_type] = parser
    return data_type
end

--- Remove an input parser for a data type, must be the same string that was passed to add_input_parser
-- @tparam string data_type The data type for which you want to remove the input parser of
function Commands.remove_data_type(data_type)
    Commands.data_types[data_type] = nil
end

--- Parse and validate an input string as a given data type
-- @tparam string|function data_type The name of the data type parser to use to read and validate the input text
-- @tparam string input The input string that will be read by the parser
-- @param ... Any other arguments that the parser is expecting
-- @treturn boolean true when the input was successfully parsed and validated to be the correct type
-- @return When The error status for why parsing failed, otherwise it is the parsed value
-- @return When first is false, this is the error message, otherwise this is the parsed value
function Commands.parse_data_type(data_type, input, ...)
    local parser = Commands.data_types[data_type]
    if type(data_type) == "function" then
        parser = data_type
    elseif parser == nil then
        return false, Commands.status.internal_error, {"exp-commands.internal-error" , "Data type \""..tostring(data_type).."\" does not have a registered parser"}
    end

    local status, parsed = parser(input, ...)
    if status == nil then
        return Commands.status.internal_error, {"exp-commands.internal-error" , "Parser for data type \""..tostring(data_type).."\" returned a nil value"}
    elseif valid_command_status[status] then
        if status ~= Commands.status.success then
            return false, status, parsed -- error_type, error_msg
        else
            return true, status, parsed -- success, parsed_data
        end
    else
        return true, Commands.status.success, status -- success, parsed_data
    end
end

--- List and Search
-- Functions used to list and search for commands
-- @section list-and-search

--- Returns a list of all registered custom commands
-- @treturn table An array of registered commands
function Commands.list_all()
    return Commands.registered_commands
end

--- Returns a list of all registered custom commands which the given player has permission to use
-- @treturn table An array of registered commands
function Commands.list_for_player(player)
    local rtn = {}

    for name, command in pairs(Commands.registered_commands) do
        if Commands.player_has_permission(player, command) then
            rtn[name] = command
        end
    end

    return rtn
end

--- Searches all game commands and the provided custom commands for the given keyword
local function search_commands(keyword, custom_commands)
    keyword = keyword:lower()
    local rtn = {}

    -- Search all custom commands
    for name, command in pairs(custom_commands) do
        local search = string.format('%s %s %s', name, command.help, table.concat(command.aliases, ' '))
        if search:lower():match(keyword) then
            rtn[name] = command
        end
    end

    -- Search all game commands
    for name, description in pairs(commands.game_commands) do
        local search = string.format('%s %s', name, description)
        if search:lower():match(keyword) then
            rtn[name] = {
                name = name,
                help = description,
                description = "",
                aliases = {}
            }
        end
    end

    return rtn
end

--- Searches all custom commands and game commands for the given keyword
-- @treturn table An array of registered commands
function Commands.search_all(keyword)
    return search_commands(keyword, Commands.list_all())
end

--- Searches custom commands allowed for this player and all game commands for the given keyword
-- @treturn table An array of registered commands
function Commands.search_for_player(keyword, player)
    return search_commands(keyword, Commands.list_for_player(player))
end

--- Command Output
-- Prints output to the player or rcon connection
-- @section player-print

--- Set the color of a message using rich text chat
-- @tparam string message The message to set the color of
-- @tparam Color color The color that the message should be
-- @treturn string The string which can be printed to game chat
function Commands.set_chat_message_color(message, color)
    local color_tag = math.round(color.r, 3)..', '..math.round(color.g, 3)..', '..math.round(color.b, 3)
    return string.format('[color=%s]%s[/color]', color_tag, message)
end

--- Set the color of a locale message using rich text chat
-- @tparam LocaleString message The message to set the color of
-- @tparam Color color The color that the message should be
-- @treturn LocaleString The locale string which can be printed to game chat
function Commands.set_locale_chat_message_color(message, color)
    local color_tag = math.round(color.r, 3)..', '..math.round(color.g, 3)..', '..math.round(color.b, 3)
    return {'color-tag', color_tag, message}
end

--- Get a string representing the name of the given player in their chat colour
-- @tparam LuaPlayer player The player to use the name and color of, nil represents the server
-- @treturn string The players name formatted as a string in their chat color
function Commands.format_player_name(player)
    local player_name = player and player.name or "<server>"
    local player_color = player and player.chat_color or Color.white
    local color_tag = math.round(player_color.r, 3)..', '..math.round(player_color.g, 3)..', '..math.round(player_color.b, 3)
    return string.format('[color=%s]%s[/color]', color_tag, player_name)
end

--- Get a locale string representing the name of the given player in their chat colour
-- @tparam LuaPlayer player The player to use the name and color of, nil represents the server
-- @treturn LocaleString The players name formatted as a locale string in their chat color
function Commands.format_locale_player_name(player)
    local player_name = player and player.name or "<server>"
    local player_color = player and player.chat_color or Color.white
    local color_tag = math.round(player_color.r, 3)..', '..math.round(player_color.g, 3)..', '..math.round(player_color.b, 3)
    return {'color-tag', color_tag, player_name}
end

--- Print a message to the user of a command, accepts any value and will print in a readable and safe format
-- @tparam any message The message / value to be printed
-- @tparam[opt] Color color The color the message should be printed in
-- @tparam[opt] string sound The sound path to be played when the message is printed
function Commands.print(message, color, sound)
    local player = game.player
    if not player then
        rcon.print(ExpUtil.format_any(message))
    else
        local formatted = ExpUtil.format_any(message, nil, 20)
        player.print(formatted, color or Color.white)
        player.play_sound{ path = sound or 'utility/scenario_message' }
    end
end

--- Print an error message to the user of a command, accepts any value and will print in a readable and safe format
-- @tparam any message The message / value to be printed
function Commands.error(message)
    return Commands.print(message, Color.orange_red, 'utility/wire_pickup')
end

--- Command Prototype
-- The prototype defination for command objects
-- @section command-prototype

--- This is a default callback that should never be called
local function default_command_callback()
    return Commands.status.internal_error('No callback registered')
end

--- Returns a new command object, this will not register the command to the game
-- @tparam string name The name of the command as it will be registered later
-- @tparam string help The help message / description of the command
-- @treturn Command A new command object which can be registered
function Commands.new(name, help)
    ExpUtil.assert_argument_type(name, "string", 1, "name")
    ExpUtil.assert_argument_type(help, "string", 2, "help")
    if Commands.registered_commands[name] then
        error("Command is already defined at: "..Commands.registered_commands[name].defined_at, 2)
    end

    return setmetatable({
        name = name,
        help = help,
        callback = default_command_callback,
        defined_at = ExpUtil.safe_file_path(2),
        auto_concat = false,
        min_arg_count = 0,
        max_arg_count = 0,
        flags = {}, -- stores flags that can be used by auth
        aliases = {}, -- stores aliases to this command
        arguments = {}, -- [{name: string, optional: boolean, default: any, data_type: function, parse_args: table}]
    }, Commands._metatable)
end

--- Get the data type parser from a name, will raise an error if it doesnt exist
local function get_parser(data_type)
    local rtn = Commands.data_types[data_type]
    if rtn == nil then
        error("Unknown data type: "..tostring(data_type), 3)
    end
    return data_type, rtn
end

--- Add a new required argument to the command of the given data type
-- @tparam string name The name of the argument being added
-- @tparam string data_type The data type of this argument, must have previously been registered with add_data_type
-- @treturn Command The command object to allow chaining method calls
function Commands._prototype:argument(name, data_type, ...)
    if self.min_arg_count ~= self.max_arg_count then
        error("Can not have required arguments after optional arguments", 2)
    end
    self.min_arg_count = self.min_arg_count + 1
    self.max_arg_count = self.max_arg_count + 1
    self.arguments[#self.arguments + 1] = {
        name = name,
        optional = false,
        data_type = data_type,
        data_type_parser = get_parser(data_type),
        parse_args = {...}
    }
    return self
end

--- Add a new optional argument to the command of the given data type
-- @tparam string name The name of the argument being added
-- @tparam string data_type The data type of this argument, must have previously been registered with add_data_type
-- @treturn Command The command object to allow chaining method calls
function Commands._prototype:optional(name, data_type, ...)
    self.max_arg_count = self.max_arg_count + 1
    self.arguments[#self.arguments + 1] = {
        name = name,
        optional = true,
        data_type = data_type,
        data_type_parser = get_parser(data_type),
        parse_args = {...}
    }
    return self
end

--- Set the defaults for optional arguments, any not provided will have their value as nil
-- @tparam table defaults A table who's keys are the argument names and values are the defaults or function which returns a default
-- @treturn Command The command object to allow chaining method calls
function Commands._prototype:defaults(defaults)
	local matched = {}
	for _, argument in ipairs(self.arguments) do
		if defaults[argument.name] then
			if not argument.optional then
				error("Attempting to set default value for required argument: " .. argument.name)
			end
			argument.default = defaults[argument.name]
			matched[argument.name] = true
		end
	end
	-- Check that there are no extra values in the table
    for name in pairs(defaults) do
        if not matched[name] then
			error("No argument with name: " .. name)
        end
    end
    return self
end

--- Set the flags for the command, these can be accessed by permission authorities to check who should use a command
-- @tparam table flags An array of string flags, or a table who's keys are the flag names and values are the flag values
-- @treturn Command The command object to allow chaining method calls
function Commands._prototype:add_flags(flags)
    for name, value in pairs(flags) do
        if type(name) == "number" then
            self.flags[value] = true
        else
            self.flags[name] = value
        end
    end
    return self
end

--- Set the aliases for the command, these are alternative names that the command can be ran under
-- @tparam table aliases An array of string names to use as aliases to this command
-- @treturn Command The command object to allow chaining method calls
function Commands._prototype:add_aliases(aliases)
    local start_index = #self.aliases
    for index, alias in ipairs(aliases) do
        self.aliases[start_index + index] = alias
    end
    return self
end

--- Enable concatenation of all arguments after the last, this should be used for user provided reason text
-- @treturn Command The command object to allow chaining method calls
function Commands._prototype:enable_auto_concatenation()
    self.auto_concat = true
    return self
end

--- Register the command to the game with the given callback, this must be the final step as the object becomes immutable afterwards
-- @tparam function callback The function which is called to perform the command action
function Commands._prototype:register(callback)
    Commands.registered_commands[self.name] = self
    self.callback = callback

    -- Generates a description to be used
    local description = {}
    for index, argument in pairs(self.arguments) do
        if argument.optional then
            description[index] = "["..argument.name.."]"
        else
            description[index] = "<"..argument.name..">"
        end
    end
    self.description = table.concat(description, " ")

    -- Callback which is called by the game engine
    local function command_callback(event)
        event.name = self.name
        local success, traceback = xpcall(Commands._event_handler, debug.traceback, event)
        if not success and not traceback:find("Command does not support rcon usage") then
            local _, msg = Commands.status.internal_error(event.tick)
            Commands.error(msg)
            log("Internal Command Error " .. event.tick .. "\n" .. traceback)
        end
    end

    -- Registers the command under its own name
    local help = {'exp-commands.command-help', self.description, self.help}
    commands.add_command(self.name, help, command_callback)

    -- Registers the command under its aliases
    for _, alias in ipairs(self.aliases) do
        commands.add_command(alias, help, command_callback)
    end
end

--- Command Runner
-- Used internally to run commands
-- @section command-runner

--- Log that a command was attempted and its outcome (error / success)
local function log_command(comment, command, player, args, detail)
    local player_name = player and player.name or '<Server>'
    ExpUtil.write_json('log/commands.log', {
        comment = comment,
        detail = detail,
        player_name = player_name,
        command_name = command.name,
        args = args
    })
end

--- Extract the arguments from a string input string
local function extract_arguments(raw_input, max_args, auto_concat)
	-- nil check when no input given
	if raw_input == nil then return {} end

    -- Extract quoted arguments
    local quoted_arguments = {}
    local input_string = raw_input:gsub('"[^"]-"', function(word)
        local no_spaces = word:gsub('%s', '%%s')
        quoted_arguments[no_spaces] = word:sub(2, -2)
        return ' '..no_spaces..' '
    end)

    -- Extract all arguments
    local index = 0
    local arguments = {}
    for word in input_string:gmatch('%S+') do
        index = index + 1
        if index > max_args then
            -- concat the word onto the last argument
            if auto_concat == false then
                return nil -- too many args, exit early
            elseif quoted_arguments[word] then
                arguments[max_args] = arguments[max_args]..' "'..quoted_arguments[word]..'"'
            else
                arguments[max_args] = arguments[max_args]..' '..word
            end
        else
            -- new argument to be added
            if quoted_arguments[word] then
                arguments[index] = quoted_arguments[word]
            else
                arguments[index] = word
            end
        end
    end

    return arguments
end

--- Internal event handler for the command event
function Commands._event_handler(event)
    local command = Commands.registered_commands[event.name]
    if command == nil then
        error("Command not recognised: "..event.name)
    end

    local player = nil -- nil represents the server until the command is called
    if event.player_index then
        player = game.get_player(event.player_index)
    end

    -- Check if the player is allowed to use the command
    local allowed, failure_msg = Commands.player_has_permission(player, command)
    if not allowed then
        log_command("Command not allowed", command, player, event.parameter)
        return Commands.error(failure_msg)
    end

    -- Check the edge case of parameter being nil
    if command.min_arg_count > 0 and event.parameter == nil then
        log_command("Too few arguments", command, player, event.parameter, { minimum = command.min_arg_count, maximum = command.max_arg_count })
        return Commands.error{'exp-commands.invalid-usage', command.name, command.description}
    end

    -- Get the arguments for the command, returns nil if there are too many arguments
    local raw_arguments = extract_arguments(event.parameter, command.max_arg_count, command.auto_concat)
    if raw_arguments == nil then
        log_command("Too many arguments", command, player, event.parameter, { minimum = command.min_arg_count, maximum = command.max_arg_count })
        return Commands.error{'exp-commands.invalid-usage', command.name, command.description}
    end

    -- Check the minimum number of arguments is fullfiled
    if #raw_arguments < command.min_arg_count then
        log_command("Too few arguments", command, player, event.parameter, { minimum = command.min_arg_count, maximum = command.max_arg_count })
        return Commands.error{'exp-commands.invalid-usage', command.name, command.description}
    end

    -- Parse the arguments, optional arguments will attempt to use a default if provided
    local arguments = {}
    for index, argument in ipairs(command.arguments) do
        local input = raw_arguments[index]
        if input == nil then
            -- We know this is an optional argument because the mimimum count is satisfied
            assert(argument.optional == true, "Argument was required")
            if type(argument.default) == "function" then
                arguments[index] = argument.default(player)
            else
                arguments[index] = argument.default
            end
        else
            -- Parse the raw argument to get the correct data type
            local success, status, parsed = Commands.parse_data_type(argument.data_type_parser, input, player, table.unpack(argument.parse_args))
            if success == false then
                log_command("Input parse failed", command, player, event.parameter, { status = valid_command_status[status], index = index, argument = argument, reason = parsed })
                return Commands.error{'exp-commands.invalid-argument', argument.name, parsed}
            else
                arguments[index] = parsed
            end
        end
    end

    -- Run the command, dont need xpcall here because errors are caught in command_callback
    local status, status_msg = command.callback(player or Commands.player_server, table.unpack(arguments))
    if valid_command_status[status] then
        if status ~= Commands.status.success then
            log_command("Custom Error", command, player, event.parameter, status_msg)
            return Commands.error(status_msg)
        else
            log_command("Command Ran", command, player, event.parameter)
            return Commands.print(status_msg)
        end
    else
        log_command("Command Ran", command, player, event.parameter)
        local _, msg = Commands.status.success()
        return Commands.print(msg)
    end
end

return Commands
