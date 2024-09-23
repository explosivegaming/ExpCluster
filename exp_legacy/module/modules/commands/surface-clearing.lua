--[[-- Commands Module - Clear Item On Ground
    - Adds a command that clear item on ground so blueprint can deploy safely
    @commands Clear Item On Ground
]]

local copy_items_stack = _C.copy_items_stack --- @dep expcore.common
local Commands = require 'expcore.commands' --- @dep expcore.commands
require 'config.expcore.command_general_parse'

Commands.new_command('clear-item-on-ground', {'expcom-surface-clearing.description-ci'}, 'Clear Item On Ground')
:add_param('range', false, 'integer-range', 1, 1000)
:register(function(player, range)
    for _, e in pairs(player.surface.find_entities_filtered{position=player.position, radius=range, name='item-on-ground'}) do
        if e.stack then
            -- calling move_items_stack(e.stack) will crash to desktop
            -- https://forums.factorio.com/viewtopic.php?f=7&t=110322
            copy_items_stack{e.stack}
            e.stack.clear()
        end
    end

    return Commands.success
end)

Commands.new_command('clear-blueprint', {'expcom-surface-clearing.description-cb'}, 'Clear Blueprint')
:add_param('range', false, 'integer-range', 1, 1000)
:register(function(player, range)
    for _, e in pairs(player.surface.find_entities_filtered{position=player.position, radius=range, type='entity-ghost'}) do
        e.destroy()
    end

    return Commands.success
end)
