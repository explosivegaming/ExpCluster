
local Search = {}
local Storage = require("modules/exp_util/storage")

--- Setup the storage to contain the pending translations and the completed ones
local pending = {} --- @type { [1]: string, [2]: string }[]
local translations = {} --- @type table<string, table<string, string>>
Storage.register({
    pending,
    translations,
}, function(tbl)
    pending = tbl[1]
    translations = tbl[2]
end)

local command_names = {} --- @type string[]
local command_objects = {} --- @type table<string, Commands.Command>
local required_translations = {} --- @type LocalisedString[]

--- Gets the descriptions of all commands, not including their aliases
--- @param custom_commands table<string, ExpCommand> The complete list of registered custom commands
function Search.prepare(custom_commands)
    local known_aliases = {} --- @type table<string, string>
    for name, command in pairs(custom_commands) do
        for _, alias in ipairs(command.aliases) do
            known_aliases[alias] = name
        end
    end

    local index = 0
    for name, locale_desc in pairs(commands.commands) do
        if not known_aliases[name] then
            index = index + 1
            command_names[index] = name
            required_translations[index] = locale_desc
            command_objects[name] = custom_commands[name] or {
                name = name,
                description = locale_desc,
                help_text = locale_desc,
                aliases = {},
            }
        end
    end

    for name, locale_desc in pairs(commands.game_commands) do
        index = index + 1
        command_names[index] = name
        required_translations[index] = locale_desc
        command_objects[name] = {
            name = name,
            description = locale_desc,
            help_text = locale_desc,
            aliases = {},
        }
    end
end

--- Called when a locale changes so the new translations can be requested
--- @param event EventData.on_player_locale_changed | EventData.on_player_joined_game
function Search.on_player_locale_changed(event)
    local player = game.players[event.player_index]
    local locale = player.locale
    if not translations[locale] then
        translations[locale] = {}
        local ids = player.request_translations(required_translations)
        assert(ids, "Translation ids was nil")
        for i, command_name in ipairs(command_names) do
            pending[ids[i]] = { locale, command_name }
        end
    end
end

--- Called when a translation request is completed
--- @param event EventData.on_string_translated
--- @return nil
function Search.on_string_translated(event)
    local info = pending[event.id]
    if not info then return end
    pending[event.id] = nil
    if not event.translated then
        return log("Failed translation for " .. info[1] .. " " .. info[2])
    end
    translations[info[1]][info[2]] = event.result:lower()
end

--- Searches all game commands and the provided custom commands for the given keyword
--- @param keyword string The keyword to search for
--- @param custom_commands table<string, ExpCommand> A dictionary of commands to search
--- @param locale string? The local to search, default is english ("en")
--- @return table<string, Commands.Command> # A dictionary of commands
function Search.search_commands(keyword, custom_commands, locale)
    local rtn = {} --- @type table<string, Commands.Command>
    keyword = keyword:lower()
    locale = locale or "en"

    local searchable_commands = translations[locale]
    if not searchable_commands then return {} end

    -- Search all custom commands
    for name, search_text in pairs(searchable_commands) do
        if search_text:match(keyword) or name:match(keyword) then
            local obj = command_objects[name]
            if not obj.defined_at or custom_commands[name] then
                rtn[name] = obj
            end
        end
    end

    return rtn
end

return Search
