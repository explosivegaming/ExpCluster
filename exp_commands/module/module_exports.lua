--[[-- Core Module - Commands
- Factorio command making module that makes commands with better parse and more modularity

--- Adding a permission authority
-- You are only required to return a boolean, but by using the unauthorised status you can provide better feedback to the user
Commands.add_permission_authority(function(player, command)
    if command.flags.admin_only and not player.admin then
        return Commands.status.unauthorised("This command requires in-game admin")
    end
    return Commands.status.success()
end)

--- Adding a data type
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

--- Adding a command
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
local Search = require("modules/exp_commands/search")

--- @class Commands
local Commands = {
    color = ExpUtil.color,
    format_rich_text_color = ExpUtil.format_rich_text_color,
    format_rich_text_color_locale = ExpUtil.format_rich_text_color_locale,
    format_player_name = ExpUtil.format_player_name,
    format_player_name_locale = ExpUtil.format_player_name_locale,

    registered_commands = {}, --- @type table<string, Commands.ExpCommand> Stores a reference to all registered commands
    permission_authorities = {}, --- @type Commands.PermissionAuthority[] Stores a reference to all active permission authorities
    
    --- @package Stores the event handlers
    events = {
        [defines.events.on_player_locale_changed] = Search.on_player_locale_changed,
        [defines.events.on_player_joined_game] = Search.on_player_locale_changed,
        [defines.events.on_string_translated] = Search.on_string_translated,
    },
}

--- @class Commands._status: table<string, Commands.Status>
--- Contains the different status values a command can return
Commands.status = {}

--- @class Commands._types: table<string, Commands.InputParser | Commands.InputParserFactory>
--- Stores all input parsers and validators for different data types
Commands.types = {}

--- @package
function Commands.on_init() Search.prepare(Commands.registered_commands) end

--- @package
function Commands.on_load() Search.prepare(Commands.registered_commands) end

--- @alias Commands.Callback fun(player: LuaPlayer, ...: any?): Commands.Status?, LocalisedString?
--- This is a default callback that should never be called
local function default_command_callback()
    return Commands.status.internal_error("No callback registered")
end

--- @class Commands.Argument
--- @field name string The name of the argument
--- @field description LocalisedString? The description of the argument
--- @field input_parser Commands.InputParser The input parser for the argument
--- @field optional boolean True when the argument is optional
--- @field default any? The default value of the argument

--- @class Commands.Command
--- @field name string The name of the command
--- @field description LocalisedString The description of the command
--- @field help_text LocalisedString The full help text for the command
--- @field aliases string[] Aliases that the command will also be registered under
--- @field defined_at? string If present then this is an ExpCommand

--- @class Commands.ExpCommand: Commands.Command
--- @field callback Commands.Callback The callback which is ran for the command
--- @field defined_at string The file location that the command is defined at
--- @field auto_concat boolean True if the command auto concatenates tailing parameters into a single string 
--- @field min_arg_count number The minimum number of expected arguments
--- @field max_arg_count number The maximum number of expected arguments
--- @field flags table Stores flags which can be used by permission authorities
--- @field arguments Commands.Argument[] The arguments for this command
Commands._prototype = {}

Commands._metatable = {
    __index = Commands._prototype,
    __class = "ExpCommand",
}

Commands.server = setmetatable({
    index = 0,
    color = ExpUtil.color.white,
    chat_color = ExpUtil.color.white,
    name = "<server>",
    locale = "en",
    tag = "",
    connected = true,
    admin = true,
    afk_time = 0,
    online_time = 0,
    last_online = 0,
    spectator = true,
    show_on_map = false,
    valid = true,
    object_name = "LuaPlayer",
    print = rcon.print,
}, {
    -- To prevent unnecessary logging Commands.error is called here and error is filtered by command_callback
    __index = function(_, key)
        if key == "__self" or type(key) == "number" then return nil end
        Commands.error("Command does not support rcon usage, requires LuaPlayer." .. key)
        error("Command does not support rcon usage, requires LuaPlayer." .. key)
    end,
    __newindex = function(_, key)
        Commands.error("Command does not support rcon usage, requires LuaPlayer." .. key)
        error("Command does not support rcon usage, requires LuaPlayer." .. key)
    end,
}) --[[ @as LuaPlayer ]]

--- Status Returns.
-- Return values used by command callbacks

--- @alias Commands.Status fun(msg: LocalisedString?): Commands.Status, LocalisedString

--- Used to signal success from a command, data type parser, or permission authority
--- @param msg LocalisedString? An optional message to be included when a command completes (only has an effect in command callbacks)
--- @return Commands.Status, LocalisedString # Should be returned directly without modification
function Commands.status.success(msg)
    return Commands.status.success, msg == nil and { "exp-commands.success" } or msg
end

--- Used to signal an error has occurred in a command, data type parser, or permission authority
--- For data type parsers and permission authority, an error return will prevent the command from being executed
--- @param msg LocalisedString? An optional error message to be included in the output, a generic message is used if not provided
--- @return Commands.Status, LocalisedString # Should be returned directly without modification
function Commands.status.error(msg)
    return Commands.status.error, { "exp-commands.error", msg == nil and { "exp-commands.error-default" } or msg }
end

--- Used to signal the player is unauthorised to use a command, primarily used by permission authorities but can be used in a command callback
--- For permission authorities, an unauthorised return will prevent the command from being executed
--- @param msg LocalisedString? An optional error message to be included in the output, a generic message is used if not provided
--- @return Commands.Status, LocalisedString # Should be returned directly without modification
function Commands.status.unauthorised(msg)
    return Commands.status.unauthorised, { "exp-commands.unauthorized", msg == nil and { "exp-commands.unauthorized-default" } or msg }
end

--- Used to signal the player provided invalid input to an command, primarily used by data type parsers but can be used in a command callback
--- For data type parsers, an invalid_input return will prevent the command from being executed
--- @param msg LocalisedString? An optional error message to be included in the output, a generic message is used if not provided
--- @return Commands.Status, LocalisedString # Should be returned directly without modification
function Commands.status.invalid_input(msg)
    return Commands.status.invalid_input, msg == nil and { "exp-commands.invalid-input" } or msg
end

--- Used to signal an internal error has occurred, this is reserved for internal use only
--- @param msg LocalisedString A message detailing the error which has occurred, will be logged and outputted
--- @return Commands.Status, LocalisedString # Should be returned directly without modification
--- @package
function Commands.status.internal_error(msg)
    return Commands.status.internal_error, { "exp-commands.internal-error", msg }
end

--- @type table<Commands.Status, string>
local valid_command_status = {} -- Hashmap lookup for testing if a status is valid
for name, status in pairs(Commands.status) do
    valid_command_status[status] = name
end

--- Permission Authority.
-- Functions that control who can use commands

--- @alias Commands.PermissionAuthority fun(player: LuaPlayer, command: Commands.ExpCommand): boolean|Commands.Status, LocalisedString?

--- Add a permission authority, a permission authority is a function which provides access control for commands, multiple can be active at once
--- When multiple are active, all authorities must give permission for the command to execute, if any deny access then the command is not ran
--- @param permission_authority Commands.PermissionAuthority The function to provide access control to commands, see module usage.
--- @return Commands.PermissionAuthority # The function which was provided as the first argument
function Commands.add_permission_authority(permission_authority)
    for _, value in ipairs(Commands.permission_authorities) do
        if value == permission_authority then
            return permission_authority
        end
    end

    local next_index = #Commands.permission_authorities + 1
    Commands.permission_authorities[next_index] = permission_authority
    return permission_authority
end

--- Remove a permission authority, must be the same function reference which was passed to add_permission_authority
--- @param permission_authority Commands.PermissionAuthority The access control function to remove as a permission authority
function Commands.remove_permission_authority(permission_authority)
    local pas = Commands.permission_authorities
    for index, value in ipairs(pas) do
        if value == permission_authority then
            local last = #pas
            pas[index] = pas[last]
            pas[last] = nil
            return
        end
    end
end

--- Check if a player has permission to use a command, calling all permission authorities
--- @param player LuaPlayer? The player to test the permission of, nil represents the server and always returns true
--- @param command Commands.ExpCommand The command the player is attempting to use
--- @return boolean # True if the player has permission to use the command
--- @return LocalisedString? # When permission is denied, this is the reason permission was denied
function Commands.player_has_permission(player, command)
    if player == nil or player == Commands.server then return true end

    for _, permission_authority in ipairs(Commands.permission_authorities) do
        local status, msg = permission_authority(player, command)
        if type(status) == "boolean" then
            if status == false then
                local _, rtn_msg = Commands.status.unauthorised(msg)
                return false, rtn_msg
            end
        elseif status and valid_command_status[status] then
            if status ~= Commands.status.success then
                return false, msg
            end
        else
            error("Permission authority returned unexpected value: " .. ExpUtil.get_class_name(status))
        end
    end

    return true, nil
end

--- Data Type Parsing.
-- Functions that parse and validate player input

--- @alias Commands.InputParser<T> fun(input: string, player: LuaPlayer): Commands.Status, (T | LocalisedString)

--- @alias Commands.InputParserFactory<T> fun(...: any): Commands.InputParser<T>

--- Add a new input parser to the command library, this method validates that it does not already exist
--- @generic T : Commands.InputParser | Commands.InputParserFactory
--- @param data_type string The name of the data type the input parser reads in and validates, becomes a key of Commands.types
--- @param input_parser T The function used to parse and validate the data type
--- @return T # The function which was provided as the second argument
function Commands.add_data_type(data_type, input_parser)
    if Commands.types[data_type] then
        local defined_at = ExpUtil.get_function_name(Commands.types[data_type], true)
        error("Data type \"" .. tostring(data_type) .. "\" already has a parser registered: " .. defined_at, 2)
    end
    Commands.types[data_type] = input_parser
    return input_parser
end

--- Remove an input parser for a data type, must be the same string that was passed to add_input_parser
--- @param data_type string | Commands.InputParser | Commands.InputParserFactory The data type or input parser you want to remove the input parser for
function Commands.remove_data_type(data_type)
    Commands.types[data_type] = nil
    for k, v in pairs(Commands.types) do
        if v == data_type then
            Commands.types[k] = nil
            return
        end
    end
end

--- Parse and validate an input string as a given data type
--- @generic T
--- @param input string The input string
--- @param player LuaPlayer The player who gave the input
--- @param input_parser Commands.InputParser<T> The parser to apply to the input string
--- @return boolean success True when the input was successfully parsed and validated to be the correct type
--- @return Commands.Status status, T | LocalisedString result # If success is false then Remaining values should be returned directly without modification
function Commands.parse_input(input, player, input_parser)
    local status, status_msg = input_parser(input, player)
    if status == nil or not valid_command_status[status] then
        local data_type = table.get_key(Commands.types, input_parser) or ExpUtil.get_function_name(input_parser, true)
        error("Parser for data type \"" .. data_type .. "\" did not return a valid status got: " .. ExpUtil.get_class_name(status))
    end
    return status == Commands.status.success, status, status_msg
end

--- List and Search
-- Functions used to list and search for commands

--- Returns a list of all registered custom commands
--- @return table<string,Commands.ExpCommand> # A dictionary of commands
function Commands.list_all()
    return Commands.registered_commands
end

--- Returns a list of all registered custom commands which the given player has permission to use
--- @param player LuaPlayer? The player to get the command of, nil represents the server but list_all should be used
--- @return table<string,Commands.ExpCommand>  # A dictionary of commands
function Commands.list_for_player(player)
    local rtn = {}

    for name, command in pairs(Commands.registered_commands) do
        if Commands.player_has_permission(player, command) then
            rtn[name] = command
        end
    end

    return rtn
end

--- Searches all custom commands and game commands for the given keyword
--- @param keyword string The keyword to search for
--- @return table<string,Commands.Command>  # A dictionary of commands
function Commands.search_all(keyword)
    return Search.search_commands(keyword, Commands.list_all(), "en")
end

--- Searches custom commands allowed for this player and all game commands for the given keyword
--- @param keyword string The keyword to search for
--- @param player LuaPlayer? The player to search the commands of, nil represents server but search_all should be used
--- @return table<string,Commands.Command>  # A dictionary of commands
function Commands.search_for_player(keyword, player)
    return Search.search_commands(keyword, Commands.list_for_player(player), player and player.locale)
end

--- Command Output
-- Prints output to the player or rcon connection

local print_format_options = { max_line_count = 20 }
local print_settings_default = { sound_path = "utility/scenario_message", color = ExpUtil.color.white }
local print_settings_error = { sound_path = "utility/wire_pickup", color = ExpUtil.color.orange_red }

Commands.print_settings = {
    default = print_settings_default,
    error = print_settings_error,
}

--- Print a message to the user of a command, accepts any value and will print in a readable and safe format
--- @param message any The message / value to be printed
--- @param settings PrintSettings? The settings to print with
function Commands.print(message, settings)
    local player = game.player
    if not player then
        rcon.print(ExpUtil.format_any(message))
    else
        if not settings then
            settings = print_settings_default
        elseif not settings.sound_path then
            settings.sound_path = print_settings_default.sound_path
        end
        player.print(ExpUtil.format_any(message, print_format_options), settings)
    end
end

--- Print an error message to the user of a command, accepts any value and will print in a readable and safe format
--- @param message any The message / value to be printed
function Commands.error(message)
    Commands.print(message, print_settings_error)
end

--- Command Prototype
-- The prototype definition for command objects

local function assert_command_mutable(command)
    if Commands.registered_commands[command.name] then
        error("Command cannot be modified after being registered.", 3)
    end
end

--- Returns a new command object, this will not register the command but act as a way to start construction
--- @param name string The name of the command as it will be registered later
--- @param description LocalisedString? The description of the command displayed in the help message
--- @return Commands.ExpCommand
function Commands.new(name, description)
    ExpUtil.assert_argument_type(name, "string", 1, "name")
    if Commands.registered_commands[name] then
        error("Command is already defined at: " .. Commands.registered_commands[name].defined_at, 2)
    end

    return setmetatable({
        name = name,
        description = description or "",
        help_text = description, -- Will be replaced in command:register
        callback = default_command_callback, -- Will be replaced in command:register
        defined_at = ExpUtil.safe_file_path(2),
        auto_concat = false,
        min_arg_count = 0,
        max_arg_count = 0,
        flags = {},
        aliases = {},
        arguments = {},
    }, Commands._metatable)
end

--- Add a new required argument to the command of the given data type
--- @param name string The name of the argument being added
--- @param description LocalisedString? The description of the argument being added
--- @param input_parser Commands.InputParser The input parser to be used for the argument
--- @return Commands.ExpCommand
function Commands._prototype:argument(name, description, input_parser)
    assert_command_mutable(self)
    if self.min_arg_count ~= self.max_arg_count then
        error("Can not have required arguments after optional arguments", 2)
    end
    self.min_arg_count = self.min_arg_count + 1
    self.max_arg_count = self.max_arg_count + 1
    self.arguments[#self.arguments + 1] = {
        name = name,
        description = description,
        input_parser = input_parser,
        optional = false,
    }
    return self
end

--- Add a new optional argument to the command of the given data type
--- @param name string The name of the argument being added
--- @param description LocalisedString? The description of the argument being added
--- @param input_parser Commands.InputParser The input parser to be used for the argument
--- @return Commands.ExpCommand
function Commands._prototype:optional(name, description, input_parser)
    assert_command_mutable(self)
    self.max_arg_count = self.max_arg_count + 1
    self.arguments[#self.arguments + 1] = {
        name = name,
        description = description,
        input_parser = input_parser,
        optional = true,
    }
    return self
end

--- Set the defaults for optional arguments, any not provided will have their value as nil
--- @param defaults table<string, (fun(player: LuaPlayer): any) | any> The default values for the optional arguments, the key is the name of the argument
--- @return Commands.ExpCommand
function Commands._prototype:defaults(defaults)
    assert_command_mutable(self)
    local matched = {}
    for _, argument in ipairs(self.arguments) do
        if defaults[argument.name] then
            if not argument.optional then
                error("Attempting to set default value for required argument: " .. argument.name, 2)
            end
            argument.default = defaults[argument.name]
            matched[argument.name] = true
        end
    end

    -- Check that there are no extra values in the table
    for name in pairs(defaults) do
        if not matched[name] then
            error("No argument with name: " .. name, 2)
        end
    end

    return self
end

--- Set the flags for the command, these can be accessed by permission authorities to check who can use a command
--- @param flags table An array of strings or a dictionary of flag names and values, when an array is used the flags values are set to true
--- @return Commands.ExpCommand
function Commands._prototype:add_flags(flags)
    assert_command_mutable(self)
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
--- @param aliases string[] An array of string names to use as aliases to this command
--- @return Commands.ExpCommand
function Commands._prototype:add_aliases(aliases)
    assert_command_mutable(self)
    local start_index = #self.aliases
    for index, alias in ipairs(aliases) do
        self.aliases[start_index + index] = alias
    end

    return self
end

--- Enable concatenation of all arguments after the last, this should be used for user provided reason text
--- @return Commands.ExpCommand
function Commands._prototype:enable_auto_concatenation()
    assert_command_mutable(self)
    self.auto_concat = true
    return self
end

--- Register the command to the game with the given callback, this must be the final step as the object becomes immutable afterwards
--- @param callback Commands.Callback The function which is called to perform the command action
--- @return Commands.ExpCommand
function Commands._prototype:register(callback)
    assert_command_mutable(self)
    Commands.registered_commands[self.name] = self
    self.callback = callback

    -- Generates a description to be used
    local argument_names = { "" } --- @type LocalisedString
    local argument_verbose = { "" } --- @type LocalisedString
    self.help_text = { "exp-commands.help", argument_names, self.description, argument_verbose } --- @type LocalisedString
    if next(self.aliases) then
        argument_verbose[2] = { "exp-commands.aliases", table.concat(self.aliases, ", ") }
    end

    local verbose_index = #argument_verbose
    for index, argument in pairs(self.arguments) do
        if argument.optional then
            argument_names[index + 1] = { "exp-commands.optional", argument.name }
            if argument.description and argument.description ~= "" then
                verbose_index = verbose_index + 1
                argument_verbose[verbose_index] = { "exp-commands.optional-verbose", argument.name, argument.description }
            end
        else
            argument_names[index + 1] = { "exp-commands.argument", argument.name }
            if argument.description and argument.description ~= "" then
                verbose_index = verbose_index + 1
                argument_verbose[verbose_index] = { "exp-commands.argument-verbose", argument.name, argument.description }
            end
        end
    end

    -- Callback which is called by the game engine
    ---@param event CustomCommandData
    local function command_callback(event)
        event.name = self.name
        local success, traceback = xpcall(Commands._event_handler, debug.traceback, event)
        --- @cast traceback string
        if not success and not traceback:find("Command does not support rcon usage") then
            local key = "<" .. table.concat({ event.name, event.player_index or 0, event.tick }, ":") .. ">"
            local _, msg = Commands.status.internal_error(key)
            Commands.error(msg)
            log("Internal Command Error " .. key .. "\n" .. traceback)
        end
    end

    -- Registers the command under its own name
    commands.add_command(self.name, self.help_text, command_callback)

    -- Registers the command under its aliases
    for _, alias in ipairs(self.aliases) do
        commands.add_command(alias, self.help_text, command_callback)
    end

    return self
end

--- Command Runner
-- Used internally to run commands

--- Log that a command was attempted and its outcome (error / success)
--- @param comment string The main comment to include in the log
--- @param command Commands.ExpCommand The command that is being executed
--- @param player LuaPlayer The player who is running the command
--- @param parameter string The raw command parameter that was used 
--- @param detail any
local function log_command(comment, command, player, parameter, detail)
    ExpUtil.write_json("log/commands.log", {
        comment = comment,
        command_name = command.name,
        player_name = player.name,
        parameter = parameter,
        detail = detail,
    })
end

--- Extract the arguments from a string input string
--- @param raw_input string? The raw input from the player
--- @param max_args number The maximum number of allowed arguments
--- @param auto_concat boolean True when remaining arguments should be concatenated
--- @return table? # Nil if there are too many arguments
local function extract_arguments(raw_input, max_args, auto_concat)
    -- nil check when no input given
    if raw_input == nil then return {} end

    -- Extract quoted arguments
    local quoted_arguments = {}
    local input_string = raw_input:gsub('"[^"]-"', function(word)
        local no_spaces = word:gsub("%s", "%%s")
        quoted_arguments[no_spaces] = word:sub(2, -2)
        return " " .. no_spaces .. " "
    end)

    -- Extract all arguments
    local index = 0
    local arguments = {}
    for word in input_string:gmatch("%S+") do
        index = index + 1
        if index > max_args then
            -- concat the word onto the last argument
            if auto_concat == false then
                return nil -- too many args, exit early
            elseif quoted_arguments[word] then
                arguments[max_args] = arguments[max_args] .. ' "' .. quoted_arguments[word] .. '"'
            else
                arguments[max_args] = arguments[max_args] .. " " .. word
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
--- @param event CustomCommandData
--- @return nil
function Commands._event_handler(event)
    local command = Commands.registered_commands[event.name]
    if command == nil then
        error("Command not recognised: " .. event.name)
    end

    local player = Commands.server
    if event.player_index then
        player = game.players[event.player_index]
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
        return Commands.error{ "exp-commands.invalid-usage", command.name, command.description }
    end

    -- Get the arguments for the command, returns nil if there are too many arguments
    local raw_arguments = extract_arguments(event.parameter, command.max_arg_count, command.auto_concat)
    if raw_arguments == nil then
        log_command("Too many arguments", command, player, event.parameter, { minimum = command.min_arg_count, maximum = command.max_arg_count })
        return Commands.error{ "exp-commands.invalid-usage", command.name, command.description }
    end

    -- Check the minimum number of arguments is fulfilled
    if #raw_arguments < command.min_arg_count then
        log_command("Too few arguments", command, player, event.parameter, { minimum = command.min_arg_count, maximum = command.max_arg_count })
        return Commands.error{ "exp-commands.invalid-usage", command.name, command.description }
    end

    -- Parse the arguments, optional arguments will attempt to use a default if provided
    local arguments = {}
    for index, argument in ipairs(command.arguments) do
        local input = raw_arguments[index]
        if input == nil then
            -- We know this is an optional argument because the minimum count is satisfied
            assert(argument.optional == true, "Argument was required")
            if type(argument.default) == "function" then
                arguments[index] = argument.default(player)
            else
                arguments[index] = argument.default
            end
        else
            -- Parse the raw argument to get the correct data type
            local success, status, parsed = Commands.parse_input(input, player, argument.input_parser)
            if success == false then
                log_command("Input parse failed", command, player, event.parameter, { status = valid_command_status[status], index = index, argument = argument.name, reason = parsed })
                return Commands.error{ "exp-commands.invalid-argument", argument.name, parsed }
            else
                arguments[index] = parsed
            end
        end
    end

    -- Run the command, don't need xpcall here because errors are caught in command_callback
    local status, status_msg = command.callback(player, table.unpack(arguments))
    if status == nil then
        log_command("Command Ran", command, player, event.parameter)
        local _, msg = Commands.status.success()
        return Commands.print(msg)
    elseif not valid_command_status[status] then
        error("Command \"" .. command.name .. "\" did not return a valid status got: " .. ExpUtil.get_class_name(status))
    elseif status ~= Commands.status.success then
        log_command("Custom Error", command, player, event.parameter, status_msg)
        return Commands.error(status_msg)
    else
        log_command("Command Ran", command, player, event.parameter)
        return Commands.print(status_msg)
    end
end

return Commands
