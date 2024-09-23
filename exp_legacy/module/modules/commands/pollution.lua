--[[-- Commands Module - Pollution Handle
    - Adds a command that allows modifying pollution
    @commands Pollution Handle
]]

local Commands = require 'expcore.commands' --- @dep expcore.commands
require 'config.expcore.command_general_parse'

Commands.new_command('pollution-clear', {'expcom-pol.description-clr'}, 'Clear pollution')
:set_flag('admin_only')
:add_alias('pol-clr')
:add_param('surface', true, 'surface')
:set_defaults{surface=function(player)
    return player.surface
end}
:register(function(player, surface)
    surface.clear_pollution()
    game.print{'expcom-pol.clr', player.name}
    return Commands.success
end)

Commands.new_command('pollution-off', {'expcom-pol.description-off'}, 'Disable pollution')
:set_flag('admin_only')
:add_alias('pol-off')
:register(function(player)
    game.map_settings.pollution.enabled = false

    for _, v in pairs(game.surfaces) do
        v.clear_pollution()
    end

    game.print{'expcom-pol.off', player.name}
    return Commands.success
end)
