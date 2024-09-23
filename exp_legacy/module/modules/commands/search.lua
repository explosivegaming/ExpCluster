--[[-- Commands Module - Inventory Search
    - Adds commands that will search all players inventories for an item
    @commands InventorySearch
]]

local Commands = require 'expcore.commands' --- @dep expcore.commands
local format_number = require('util').format_number --- @dep util
local format_chat_player_name = _C.format_chat_player_name --- @dep expcore.common
local format_time = _C.format_time
require 'config.expcore.command_general_parse'

--- Input parse for items by name
local function item_parse(input, _, reject)
    if input == nil then return end
    local lower_input = input:lower():gsub(' ', '-')

    -- Simple Case - internal name is given
    local item = game.item_prototypes[lower_input]
    if item then return item end

    -- Second Case - rich text is given
    local item_name = input:match('%[item=([0-9a-z-]+)%]')
    item = game.item_prototypes[item_name]
    if item then return item end

    -- No item found, we do not attempt to search all prototypes as this will be expensive
    return reject{'expcom-inv-search.reject-item', lower_input}
end

--- Search all players for this item
local function search_players(players, item)
    local head = 1
    local found = {}

    -- Check the item count of all players
    for _, player in pairs(players) do
        local item_count = player.get_item_count(item.name)
        if item_count > 0 then
            -- Add the player to the array as they have the item
            found[head] = { player=player, count=item_count, online_time=player.online_time }
            head = head + 1
        end
    end

    return found
end

--- Custom sort function which only retains 5 greatest values
local function sort_players(players, func)
    local sorted = {}
    local values = {}
    local threshold = nil

    -- Loop over all provided players
    for index, player in ipairs(players) do
        local value = func(player)
        -- Check if the item will make the top 5 elements
        if index <= 5 or value > threshold then
            local inserted = false
            values[player] = value
            -- Find where in the top 5 to insert the element
            for next_index, next_player in ipairs(sorted) do
                if value > values[next_player] then
                    table.insert(sorted, next_index, player)
                    inserted = true
                    break
                end
            end
            -- Insert the element, this can only be called when index <= 5
            if not inserted then
                sorted[#sorted+1] = player
            end
            -- Update the threshold
            if sorted[6] then
                threshold = values[sorted[5]]
                values[sorted[6]] = nil
                sorted[6] = nil
            else
                threshold = values[sorted[#sorted]]
            end
        end
    end

    return sorted
end

--- Display to the player the top players which were found
local function display_players(player, players, item)
    player.print{'expcom-inv-search.results-heading', item.name}
    for index, data in ipairs(players) do
        local player_name_color = format_chat_player_name(data.player)
        local amount = format_number(data.count)
        local time = format_time(data.online_time)
        player.print{'expcom-inv-search.results-item', index, player_name_color, amount, time}
    end
end

--- Return the amount of an item a player has
local function amount_sort(data)
    return data.count
end

--- Get a list of players sorted by the quantity of an item in their inventory
-- @command search-amount
-- @tparam LuaItemPrototype item The item to search for in players inventories
Commands.new_command('search-amount', {'expcom-inv-search.description-ia'}, 'Display players sorted by the quantity of an item held')
:add_alias('ia')
:add_param('item', false, item_parse)
:enable_auto_concat()
:register(function(player, item)
    local players = search_players(game.players, item)
    if #players == 0 then return {'expcom-inv-search.results-none', item.name} end
    local top_players = sort_players(players, amount_sort)
    display_players(player, top_players, item)
end)

--- Return the index of the player, higher means they joined more recently
local function recent_sort(data)
    return data.player.index
end

--- Get a list of players who have the given item, sorted by how recently they joined
-- @command search-recent
-- @tparam LuaItemPrototype item The item to search for in players inventories
Commands.new_command('search-recent', {'expcom-inv-search.description-ir'}, 'Display players who hold an item sorted by join time')
:add_alias('ir')
:add_param('item', false, item_parse)
:enable_auto_concat()
:register(function(player, item)
    local players = search_players(game.players, item)
    if #players == 0 then return {'expcom-inv-search.results-none', item.name} end
    local top_players = sort_players(players, recent_sort)
    display_players(player, top_players, item)
end)

--- Return the the amount of an item a player has divided by their playtime
local function combined_sort(data)
    return data.count/data.online_time
end

--- Get a list of players sorted by quantity held and play time
-- @command search
-- @tparam LuaItemPrototype item The item to search for in players inventories
Commands.new_command('search', {'expcom-inv-search.description-i'}, 'Display players sorted by the quantity of an item held and playtime')
:add_alias('i')
:add_param('item', false, item_parse)
:enable_auto_concat()
:register(function(player, item)
    local players = search_players(game.players, item)
    if #players == 0 then return {'expcom-inv-search.results-none', item.name} end
    local top_players = sort_players(players, combined_sort)
    display_players(player, top_players, item)
end)

--- Get a list of online players sorted by quantity held and play time
-- @command search-online
-- @tparam LuaItemPrototype item The item to search for in players inventories
Commands.new_command('search-online', {'expcom-inv-search.description-io'}, 'Display online players sorted by the quantity of an item held and playtime')
:add_alias('io')
:add_param('item', false, item_parse)
:enable_auto_concat()
:register(function(player, item)
    local players = search_players(game.connected_players, item)
    if #players == 0 then return {'expcom-inv-search.results-none', item.name} end
    local top_players = sort_players(players, combined_sort)
    display_players(player, top_players, item)
end)
