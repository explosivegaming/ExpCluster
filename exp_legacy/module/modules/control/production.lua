--[[-- Control Module - Production
    - Common functions used to track production of items
    @control Production
    @alias Production

    @usage
    -- import the module from the control modules
    local Production = require 'modules.control.production' --- @dep modules.control.production

    -- This will return the less precise index from the one given
    -- this means that one_second will return one_minute or ten_hours will return fifty_hours
    -- the other precision work like wise
    Production.precision_up(defines.flow_precision_index.one_second)

    -- The get production function is used to get production, consumion and net
    -- it may be used for any item and with any precision level, use total for total
    Production.get_production(game.forces.player, 'iron-plate', defines.flow_precision_index.one_minute)

    -- The fluctuations works by compearing recent production with the average over time
    -- again any precision may be used, apart from one_thousand_hours as there would be no valid average
    Production.get_fluctuations(game.forces.player, 'iron-plate', defines.flow_precision_index.one_minute)

    -- ETA is calculated based on what function you use but all share a similar method
    -- for production eta it will take current production average given by the precision
    -- and work out how many ticks it will require to make the required amount (1000 by default)
    Production.get_production_eta(game.forces.player, 'iron-plate', defines.flow_precision_index.one_minute, 250000)

    -- Both get_color and format_number are helper functions to help format production stats
    -- get_color will return green, orange, red, or grey based on the active_value
    -- the passive_value is used when active_value is 0 and can only return orange, red, or grey
    Production.get_color(clamp, active_value, passive_value)

]]

local Colors = require 'utils.color_presets' --- @dep utils.color_presets
local format_number = require('util').format_number --- @dep util

local precision_index = defines.flow_precision_index
local Production = {}

--- Precision.
-- Functions which are used to do basic things
-- @section precision

--- Gets the next lesser precision index value, eg 5 seconds -> 1 minute
-- @tparam defines.flow_precision_index precision
-- @treturn[1] defines.flow_precision_index the next precision value
-- @treturn[1] number the multiplicive difference between the values
function Production.precision_up(precision)
    if precision == precision_index.five_seconds then return precision_index.one_minute, 60
    elseif precision == precision_index.one_minute then return precision_index.ten_minutes, 10
    elseif precision == precision_index.ten_minutes then return precision_index.one_hour, 6
    elseif precision == precision_index.one_hour then return precision_index.ten_hours, 10
    elseif precision == precision_index.ten_hours then return precision_index.fifty_hours, 5
    elseif precision == precision_index.fifty_hours then return precision_index.two_hundred_fifty_hours, 5
    elseif precision == precision_index.two_hundred_fifty_hours then return precision_index.one_thousand_hours, 4
    end
end

--- Gets the next greater precision index value, eg 1 minute -> 5 seconds
-- @tparam defines.flow_precision_index precision
-- @treturn[1] defines.flow_precision_index the next precision value
-- @treturn[1] number the multiplicive difference between the values
function Production.precision_down(precision)
    if precision == precision_index.one_minute then return precision_index.five_seconds, 60
    elseif precision == precision_index.ten_minutes then return precision_index.one_minute, 10
    elseif precision == precision_index.one_hour then return precision_index.ten_minutes, 6
    elseif precision == precision_index.ten_hours then return precision_index.one_hour, 10
    elseif precision == precision_index.fifty_hours then return precision_index.ten_hours, 5
    elseif precision == precision_index.two_hundred_fifty_hours then return precision_index.fifty_hours, 5
    elseif precision == precision_index.one_thousand_hours then return precision_index.two_hundred_fifty_hours, 4
    end
end

--- Gets the number of tick that precision is given over, eg 1 minute -> 3600 ticks
-- @tparam defines.flow_precision_index precision
-- @treturn number the number of ticks in this time
function Production.precision_ticks(precision)
    if precision == precision_index.five_seconds then return 300
    elseif precision == precision_index.one_minute then return 3600
    elseif precision == precision_index.ten_minutes then return 36000
    elseif precision == precision_index.one_hour then return 216000
    elseif precision == precision_index.ten_hours then return 2160000
    elseif precision == precision_index.fifty_hours then return 10800000
    elseif precision == precision_index.two_hundred_fifty_hours then return 54000000
    elseif precision == precision_index.one_thousand_hours then return 216000000
    end
end

--- Statistics.
-- Functions used to get information about production
-- @section stats

--- Returns the production data for the whole game time
-- @tparam LuaForce force the force to get the data for
-- @tparam string item_name the name of the item that you want the data about
-- @treturn table contains total made, used and net
function Production.get_production_total(force, item_name)
    local stats = force.item_production_statistics
    local made = stats.get_input_count(item_name) or 0
    local used = stats.get_output_count(item_name) or 0

    return {
        made=made,
        used=used,
        net=made-used
    }

end

--- Returns the production data for the given precision game time
-- @tparam LuaForce force the force to get the data for
-- @tparam string item_name the name of the item that you want the data about
-- @tparam defines.flow_precision_index precision the precision that you want the data given to
-- @treturn table contains made, used and net
function Production.get_production(force, item_name, precision)
    local stats = force.item_production_statistics.get_flow_count
    local made = stats{name=item_name, input=true, precision_index=precision} or 0
    local used = stats{name=item_name, input=false, precision_index=precision} or 0

    return {
        made=made,
        used=used,
        net=made-used
    }

end

--- Returns the current fluctuation from the average
-- @tparam LuaForce force the force to get the data for
-- @tparam string item_name the name of the item that you want the data about
-- @tparam defines.flow_precision_index precision the precision that you want the data given to
-- @treturn table contains made, used and net
function Production.get_fluctuations(force, item_name, precision)
    local precision_up = Production.precision_up(precision)
    local current = Production.get_production(force, item_name, precision)
    local previous = Production.get_production(force, item_name, precision_up)

    return {
        made=(current.made/previous.made)-1,
        used=(current.used/previous.used)-1,
        net=(current.net/previous.net)-1,
    }

end

--- Returns the amount of ticks required to produce a certain amount
-- @tparam LuaForce force the force to get the data for
-- @tparam string item_name the name of the item that you want the data about
-- @tparam defines.flow_precision_index precision the precision that you want the data given to
-- @tparam[opt=1000] number required the number of items that are required to be made
-- @treturn number the number of ticks required to produce this ammount of items
function Production.get_production_eta(force, item_name, precision, required)
    required = required or 1000
    local ticks = Production.precision_ticks(precision)
    local production = Production.get_production(force, item_name, precision)
    return production.made == 0 and -1 or ticks*required/production.made
end

--- Returns the amount of ticks required to consume a certain amount
-- @tparam LuaForce force the force to get the data for
-- @tparam string item_name the name of the item that you want the data about
-- @tparam defines.flow_precision_index precision the precision that you want the data given to
-- @tparam[opt=1000] number required the number of items that are required to be consumed
-- @treturn number the number of ticks required to consume this ammount of items
function Production.get_consumsion_eta(force, item_name, precision, required)
    required = required or 1000
    local ticks = Production.precision_ticks(precision)
    local production = Production.get_production(force, item_name, precision)
    return production.used == 0 and -1 or ticks*required/production.used
end

--- Returns the amount of ticks required to produce but not consume a certain amount
-- @tparam LuaForce force the force to get the data for
-- @tparam string item_name the name of the item that you want the data about
-- @tparam defines.flow_precision_index precision the precision that you want the data given to
-- @tparam[opt=1000] number required the number of items that are required to be made but not used
-- @treturn number the number of ticks required to produce, but not use, this ammount of items
function Production.get_net_eta(force, item_name, precision, required)
    required = required or 1000
    local ticks = Production.precision_ticks(precision)
    local production = Production.get_production(force, item_name, precision)
    return production.net == 0 and -1 or ticks*required/production.net
end

--- Formating.
-- Functions used to format production values
-- @section formating

--- Returns a color value based on the value that was given
-- @tparam number cutoff value which separates the different colours
-- @tparam number active_value first value tested, tested against cutoff
-- @tparam number passive_value second value tested, tested against 0 when active is 0
-- @treturn table contains r,g,b keys
function Production.get_color(cutoff, active_value, passive_value)
    if active_value > cutoff then
        return Colors.light_green
    elseif active_value < -cutoff then
        return Colors.indian_red
    elseif active_value ~= 0 then
        return Colors.orange
    elseif passive_value and passive_value > 0 then
        return Colors.orange
    elseif passive_value and passive_value < 0 then
        return Colors.indian_red
    else
        return Colors.grey
    end
end

--- Returns three parts used to format a number
-- @tparam number value the value to format
-- @treturn[1] string the sign for the number
-- @treturn[1] string the surfix for any unit used
function Production.format_number(value)
    local rtn = format_number(math.round(value, 1), true)
    local surfix = rtn:sub(-1)

    if value > 0 then
        rtn = '+'..rtn
    elseif value == 0 and rtn:sub(1, 1) == '-' then
        rtn = rtn:sub(2)
    end

    if not tonumber(surfix) then
        return surfix, rtn:sub(1, -2)
    else
        return '', rtn
    end

end

return Production