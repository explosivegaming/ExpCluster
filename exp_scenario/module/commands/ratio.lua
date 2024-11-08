--[[-- Commands - Ratio
Adds a command to calculate the number of machines needed to fulfil a desired production
]]

local Commands = require("modules/exp_commands")

Commands.new("ratio", { "exp-command_ratio.description" })
    :optional("items-per-second", { "exp-command_ratio.arg-items-per-second" }, Commands.types.number)
    :register(function(player, items_per_second)
        --- @cast items_per_second number?

        local machine = player.selected
        if not machine then
            return Commands.status.error{ "exp-command_ratio.not-selecting" }
        end

        if machine.type ~= "assembling-machine" and machine.type ~= "furnace" then
            return Commands.status.error{ "exp-command_ratio.not-selecting" }
        end

        local recipe = machine.get_recipe()
        if not recipe then
            return Commands.status.error{ "exp-command_ratio.not-selecting" }
        end

        local products = recipe.products
        local ingredients = recipe.ingredients
        local crafts_per_second = machine.crafting_speed * machine.productivity_bonus / recipe.energy
        
        local amount_of_machines = 1
        if items_per_second then
            amount_of_machines = math.ceil(products[1].amount * crafts_per_second)
        end

        for _, ingredient in ipairs(ingredients) do
            Commands.print{
                ingredient.type == "item" and "exp-command_ratio.item-out" or "exp-command_ratio.fluid-out",
                math.round(ingredient.amount * crafts_per_second, 3),
                ingredient.name
            }
        end

        for i, product in ipairs(products) do
            Commands.print{
                product.type == "item" and "exp-command_ratio.item-out" or "exp-command_ratio.fluid-out",
                math.round(product.amount * crafts_per_second, 3),
                product.name
            }
        end

        if amount_of_machines ~= 1 then
            Commands.print{ "exp-command_ratio.machine-count", amount_of_machines }
        end
    end)
