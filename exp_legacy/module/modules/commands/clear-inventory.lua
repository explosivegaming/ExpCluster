--[[-- Commands Module - Clear Inventory
    - Adds a command that allows admins to clear people's inventorys
    @commands Clear-Inventory
]]

local Commands = require 'expcore.commands' --- @dep expcore.commands
local move_items_stack = _C.move_items_stack --- @dep expcore.common
require 'config.expcore.command_role_parse'

--- Clears a players inventory
-- @command clear-inventory
-- @tparam LuaPlayer player the player to clear the inventory of
Commands.new_command('clear-inventory', {'expcom-clr-inv.description'}, 'Clears a players inventory')
:add_param('player', false, 'player-role')
:add_alias('clear-inv', 'move-inventory', 'move-inv')
:register(function(_, player)
  local inv = player.get_main_inventory()
  if not inv then
    return Commands.error{'expcore-commands.reject-player-alive'}
  end
  move_items_stack(inv)
  inv.clear()
end)
