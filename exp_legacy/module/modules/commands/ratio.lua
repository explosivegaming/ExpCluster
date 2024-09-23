

local Commands = require 'expcore.commands'

local function Modules(moduleInventory) -- returns the multiplier of the modules
      local effect1 = moduleInventory.get_item_count("productivity-module") -- type 1
      local effect2 = moduleInventory.get_item_count("productivity-module-2")-- type 2
      local effect3 = moduleInventory.get_item_count("productivity-module-3") -- type 3

      local multi = effect1*4+effect2*6+effect3*10
      return multi/100+1
end

local function AmountOfMachines(itemsPerSecond, output)
      if(itemsPerSecond) then
            return itemsPerSecond/output
      end
end

Commands.new_command('ratio', {'expcom-ratio.description'}, 'This command will give the input and output ratios of the selected machine. Use the parameter for calculating the machines needed for that amount of items per second.')
:add_param('itemsPerSecond', true, 'number')
:register(function(player, itemsPerSecond)
      local machine = player.selected -- selected machine

      if not machine then --nil check
            return Commands.error{'expcom-ratio.notSelecting'}
      end

      if  machine.type ~= "assembling-machine" and machine.type ~= "furnace" then
            return Commands.error{'expcom-ratio.notSelecting'}
      end

      local recipe =  machine.get_recipe() -- recipe

      if not recipe then --nil check
            return Commands.error{'expcom-ratio.notSelecting'}
      end

      local items = recipe.ingredients -- items in that recipe
      local products = recipe.products -- output items
      local amountOfMachines
      local moduleInventory = machine.get_module_inventory()--the module Inventory of the machine
      local multi = Modules(moduleInventory) --function for the productively modals

      if itemsPerSecond then
            amountOfMachines = math.ceil( AmountOfMachines(itemsPerSecond, 1/recipe.energy*machine.crafting_speed*products[1].amount*multi)) -- amount of machines
      end

      if not amountOfMachines then
            amountOfMachines = 1  --set to 1 to make it not nil
      end

      ----------------------------items----------------------------
      for i, item in ipairs(items) do
            local sprite -- string to make the icon work either fluid ore item

            if item.type == "item" then
                  sprite = 'expcom-ratio.item-in'

            else
                  sprite = 'expcom-ratio.fluid-in'
            end

            local ips = item.amount/recipe.energy*machine.crafting_speed*amountOfMachines --math on the items/fluids per second
            Commands.print{sprite, math.round(ips, 3), item.name} -- full string
      end

      ----------------------------products----------------------------
      for i, product in ipairs(products) do
            local sprite  -- string to make the icon work either fluid ore item

            if product.type == "item" then
                   sprite = 'expcom-ratio.item-out'
            else
                  sprite = 'expcom-ratio.fluid-out'
            end

            local output = 1/recipe.energy*machine.crafting_speed*product.amount*multi  --math on the outputs per second
            Commands.print {sprite, math.round(output*amountOfMachines, 3), product.name} -- full string

      end

      if amountOfMachines ~= 1 then
            Commands.print{'expcom-ratio.machines', amountOfMachines}
      end
end)
