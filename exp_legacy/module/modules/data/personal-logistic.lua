local Commands = require 'expcore.commands' --- @dep expcore.commands
local config = require 'config.personal_logistic' --- @dep config.personal-logistic

local pl = {}

function pl.pl(type, target, amount)
    local c
    local s

    if type == 'p' then
        c = target.clear_personal_logistic_slot
        s = target.set_personal_logistic_slot

    elseif type == 's' then
        c = target.clear_vehicle_logistic_slot
        s = target.set_vehicle_logistic_slot

    else
        return
    end

    for _, v in pairs(config.request) do
        c(v.key)
    end

    if (amount < 0) then
        return
    end

    local stats = target.force.item_production_statistics

    for k, v in pairs(config.request) do
        local v_min = math.ceil(v.min * amount)
        local v_max = math.ceil(v.max * amount)

        if v.stack and v.stack ~= 1 and v.type ~= 'weapon' then
            v_min = math.floor(v_min / v.stack) * v.stack
            v_max = math.ceil(v_max / v.stack) * v.stack
        end

        if v.upgrade_of == nil then
            if v.type then
                if stats.get_input_count(k) < config.production_required[v.type] then
                    if v_min > 0 then
                        if v_min == v_max then
                            v_min = math.floor((v_max * 0.5) / v.stack) * v.stack
                        end

                    else
                        v_min = 0
                    end
                end
            end

            s(v.key, {name=k, min=v_min, max=v_max})

        else
            if v.type then
                if stats.get_input_count(k) >= config.production_required[v.type] then
                    s(v.key, {name=k, min=v_min, max=v_max})
                    local vuo = v.upgrade_of

                    while vuo do
                        s(config.request[vuo].key, {name=vuo, min=0, max=0})
                        vuo = config.request[vuo].upgrade_of
                    end

                else
                    s(v.key, {name=k, min=0, max=v_max})
                end
            end
        end
    end
end

Commands.new_command('personal-logistic', {'expcom-personal-logistics'}, 'Set Personal Logistic (-1 to cancel all) (Select spidertron to edit spidertron)')
:add_param('amount', 'integer-range', -1, 10)
:add_alias('pl')
:register(function(player, amount)
    if player.force.technologies['logistic-robotics'].researched then
        if player.selected then
            if player.selected.name == 'spidertron' then
                pl.pl('s', player.selected, amount / 10)
                return Commands.success
            end

        else
            pl.pl('p', player, amount / 10)
            return Commands.success
        end

    else
        player.print('Personal Logistic not researched')
    end
end)

return pl
