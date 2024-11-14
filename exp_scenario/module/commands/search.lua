--[[-- Commands - Inventory Search
Adds commands that will search all players inventories for an item
]]

local ExpUtil = require("modules/exp_util")

local Commands = require("modules/exp_commands")
local format_player_name = Commands.format_player_name_locale

local format_number = require("util").format_number

--- A player who is of a lower role than the executing player
--- @type Commands.InputParser
local function parse_item(input, player)
    -- First Case - internal name is given
    -- Second Case - rich text is given
    local item_name = input:lower():gsub(" ", "-")
    local item = prototypes.item[item_name] or prototypes.item[input:match("%[item=([0-9a-z-]+)%]")]
    if item then
        return Commands.status.success(item)
    end
    
    -- No item found, we do not attempt to search all prototypes as this will be expensive
    return Commands.status.invalid_input{ "exp-commands_search.invalid-item", item_name }
end

--- @class SearchResult: { player: LuaPlayer, count: number, online_time: number }

--- Search all players for this item
--- @param players LuaPlayer[] Players to search
--- @param item LuaItemPrototype Item to find
--- @return SearchResult[]
local function search_players(players, item)
    local found = {} --- @type SearchResult[]
    local head = 1

    -- Check the item count of all players
    for _, player in pairs(players) do
        local item_count = player.get_item_count(item.name)
        if item_count > 0 then
            -- Add the player to the array as they have the item
            found[head] = { player = player, count = item_count, online_time = player.online_time }
            head = head + 1
        end
    end

    return found
end

--- @alias SortFunction fun(result: SearchResult): number

--- Custom sort function which only retains 5 greatest values
--- @param results SearchResult[] Players to sort
--- @param func SortFunction Function to calculate value, higher better
--- @return SearchResult[] # Top 5 results
local function sort_results(results, func)
    local sorted = {}
    local values = {}
    local threshold = 0

    -- Loop over all provided players
    for index, result in ipairs(results) do
        local value = func(result)
        -- Check if the item will make the top 5 elements
        if index <= 5 or value > threshold then
            local inserted = false
            values[result] = value

            -- Find where in the top 5 to insert the element
            for next_index, next_result in ipairs(sorted) do
                if value > values[next_result] then
                    table.insert(sorted, next_index, result)
                    inserted = true
                    break
                end
            end

            -- Update the threshold, clean up the tables, and insert if needed
            if sorted[6] then
                threshold = values[sorted[5]]
                values[sorted[6]] = nil
                sorted[6] = nil
            elseif not inserted then
                -- index <= 5 so insert at the end
                sorted[#sorted + 1] = result
                threshold = value
            end
        end
    end

    return sorted
end

local display_players_time_format = ExpUtil.format_time_factory_locale{ format = "short", hours = true, minutes = true }

--- Display to the player the top players which were found
--- @param results SearchResult[]
--- @param item LuaItemPrototype
--- @return LocalisedString
local function format_response(results, item)
    if #results == 0 then
        return { "exp-commands_search.no-results", item.name }
    end

    local response = { "", { "exp-commands_search.title", item.name } } --- @type LocalisedString
    for index, data in ipairs(results) do
        response[index + 2] = {
            "exp-commands_search.result",
            index,
            format_player_name(data.player),
            format_number(data.count, false),
            display_players_time_format(data.online_time),
        }
    end

    return response
end

--- Return the the amount of an item a player has divided by their playtime
local function combined_sort(data)
    return data.count / data.online_time
end

--- Get a list of players sorted by quantity held and play time
Commands.new("search", { "exp-commands_search.description-search" })
    :argument("item", { "exp-commands_search.arg-item" }, parse_item)
    :enable_auto_concatenation()
    :add_aliases{ "si" } -- cant use /s
    :register(function(player, item)
        --- @cast item LuaItemPrototype
        local results = search_players(game.players, item)
        local sorted = sort_results(results, combined_sort)
        return Commands.status.success(format_response(sorted, item))
    end)

--- Get a list of online players sorted by quantity held and play time
Commands.new("search-online", { "exp-commands_search.description-online" })
    :argument("item", { "exp-commands_search.arg-item" }, parse_item)
    :enable_auto_concatenation()
    :add_aliases{ "so" }
    :register(function(player, item)
        --- @cast item LuaItemPrototype
        local results = search_players(game.connected_players, item)
        local sorted = sort_results(results, combined_sort)
        return Commands.status.success(format_response(sorted, item))
    end)

--- Return the amount of an item a player has
--- @type SortFunction
local function sort_by_count(data)
    return data.count
end

--- Get a list of players sorted by the quantity of an item in their inventory
Commands.new("search-amount", { "exp-commands_search.description-amount" })
    :argument("item", { "exp-commands_search.arg-item" }, parse_item)
    :enable_auto_concatenation()
    :add_aliases{ "sa" } -- cant use /sc
    :register(function(player, item)
        --- @cast item LuaItemPrototype
        local results = search_players(game.players, item)
        local sorted = sort_results(results, sort_by_count)
        return Commands.status.success(format_response(sorted, item))
    end)

--- Return the index of the player, higher means they joined more recently
local function sort_by_recent(data)
    return data.player.index
end

--- Get a list of players who have the given item, sorted by how recently they joined
Commands.new("search-recent", { "exp-commands_search.description-recent" })
    :argument("item", { "exp-commands_search.arg-item" }, parse_item)
    :enable_auto_concatenation()
    :add_aliases{ "sr" }
    :register(function(player, item)
        --- @cast item LuaItemPrototype
        local results = search_players(game.players, item)
        local sorted = sort_results(results, sort_by_recent)
        return Commands.status.success(format_response(sorted, item))
    end)
