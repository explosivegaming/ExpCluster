--[[-- Commands Module - Enemy
    - Adds a command of handling enemy
    @commands Enemy
]]

local Commands = require 'expcore.commands' --- @dep expcore.commands
require 'config.expcore.command_general_parse'

Commands.new_command('kill-biters', {'expcom-enemy.description-kill'}, 'Kill all biters only')
:set_flag('admin_only')
:register(function(_, _)
    game.forces['enemy'].kill_all_units()
    return Commands.success
end)

Commands.new_command('remove-biters', {'expcom-enemy.description-remove'}, 'Remove biters and prevent generation')
:set_flag('admin_only')
:add_param('surface', true, 'surface')
:set_defaults{surface=function(player)
    return player.surface
end}
:register(function(_, surface)
    for _, entity in pairs(surface.find_entities_filtered({force='enemy'})) do
        entity.destroy()
    end

    surface.map_gen_settings.autoplace_controls['enemy-base'].size = 'none'
    return Commands.success
end)
