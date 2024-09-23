--[[-- Commands Module - Help
    - Adds a better help command that allows searching of descriotions and names
    @commands Help
]]

local Commands = require 'expcore.commands' --- @dep expcore.commands
local Global = require 'utils.global' --- @dep utils.global
require 'config.expcore.command_general_parse'

local results_per_page = 5

local search_cache = {}
Global.register(search_cache, function(tbl)
    search_cache = tbl
end)

--- Searches for a keyword in all commands you are allowed to use.
-- @command chelp
-- @tparam string keyword the keyword that will be looked for
-- @tparam number page the page of help to view, must be in range of pages
Commands.new_command('search-help', {'expcom-chelp.description'}, 'Searches for a keyword in all commands you are allowed to use.')
:add_alias('chelp', 'shelp', 'commands')
:add_param('keyword', true)
:add_param('page', true, 'integer')
:set_defaults{keyword='', page=1}
:register(function(player, keyword, page)
    local player_index = player and player.index or 0

    -- if keyword is a number then treat it as page number
    if tonumber(keyword) then
        page = math.floor(tonumber(keyword))
        keyword = ''
    end

    -- gets a value for pages, might have result in cache
    local pages
    local found = 0

    if search_cache[player_index] and search_cache[player_index].keyword == keyword:lower() then
        pages = search_cache[player_index].pages
        found = search_cache[player_index].found

    else
        pages = {{}}
        local current_page = 1
        local page_count = 0
        local commands = Commands.search(keyword, player)

        -- loops other all commands returned by search, includes game commands
        for _, command_data in pairs(commands) do
            -- if the number of results if greater than the number already added then it moves onto a new page
            if page_count >= results_per_page then
                page_count = 0
                current_page = current_page + 1
                table.insert(pages, {})
            end

            -- adds the new command to the page
            page_count = page_count + 1
            found = found + 1
            local alias_format = #command_data.aliases > 0 and {'expcom-chelp.alias', table.concat(command_data.aliases, ', ')} or ''
            table.insert(pages[current_page], {
                'expcom-chelp.format',
                command_data.name,
                command_data.description,
                command_data.help,
                alias_format
            })
        end

        -- adds the result to the cache
        search_cache[player_index] = {
            keyword=keyword:lower(),
            pages=pages,
            found=found
        }
    end

    -- print the requested page
    keyword = keyword == '' and '<all>' or keyword
    Commands.print({'expcom-chelp.title', keyword}, 'cyan')

    if pages[page] then
        for _, command in pairs(pages[page]) do
            Commands.print(command)
        end

        Commands.print({'expcom-chelp.footer', found, page, #pages}, 'cyan')

    else
        Commands.print({'expcom-chelp.footer', found, page, #pages}, 'cyan')
        return Commands.error{'expcom-chelp.out-of-range', page}
    end

    -- blocks command complete message
    return Commands.success
end)

-- way to access global
return search_cache
