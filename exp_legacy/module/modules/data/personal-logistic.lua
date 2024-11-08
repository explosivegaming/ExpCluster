local Commands = require("modules/exp_commands")
local config = require("modules.exp_legacy.config.personal_logistic") --- @dep config.personal-logistic

local function pl(type, target, amount)
    local c
    local s

    if type == "p" then
        c = target.clear_personal_logistic_slot
        s = target.set_personal_logistic_slot
    elseif type == "s" then
        c = target.clear_vehicle_logistic_slot
        s = target.set_vehicle_logistic_slot
    else
        return
    end

    for _, v in pairs(config.request) do
        c(config.start + v.key)
    end

    if (amount < 0) then
        return
    end

    local stats = target.force.get_item_production_statistics(target.surface)

    for k, v in pairs(config.request) do
        local v_min = math.ceil(v.min * amount)
        local v_max = math.ceil(v.max * amount)

        if v.stack ~= nil and v.stack ~= 1 and v.type ~= "weapon" then
            v_min = math.floor(v_min / v.stack) * v.stack
            v_max = math.ceil(v_max / v.stack) * v.stack
        end

        if v.upgrade_of == nil then
            if v.type ~= nil then
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

            s(config.start + v.key, { name = k, min = v_min, max = v_max })
        else
            if v.type ~= nil then
                if stats.get_input_count(k) >= config.production_required[v.type] then
                    s(config.start + v.key, { name = k, min = v_min, max = v_max })
                    local vuo = v.upgrade_of

                    while (vuo ~= nil) do
                        s(config.start + config.request[vuo].key, { name = vuo, min = 0, max = 0 })
                        vuo = config.request[vuo].upgrade_of
                    end
                else
                    s(config.start + v.key, { name = k, min = 0, max = v_max })
                end
            end
        end
    end
end

Commands.new("personal-logistic", "Set Personal Logistic (-1 to cancel all) (Select spidertron to edit spidertron)")
    :argument("amount", "", Commands.types.integer_range(-1, 10))
    :add_aliases{ "pl" }
    :register(function(player, amount)
        --- @cast amount number
        if player.force.technologies["logistic-robotics"].researched then
            if player.selected ~= nil then
                if player.selected.name == "spidertron" then
                    pl("s", player.selected, amount / 10)
                end
            else
                pl("p", player, amount / 10)
            end
        else
            return Commands.status.error("Personal Logistic not researched")
        end
    end)
