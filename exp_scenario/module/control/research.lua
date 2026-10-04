--[[ Control - Research
Various research related event handlers

TODO Refactor this fully, this is temp to get it out of the research times gui file
]]

local Feature = require("modules/exp_scenario/features")
local research_data = require("modules/exp_scenario/config/research_data")

local feature, config = Feature.register("research", {
    pollution_ageing_by_research = false, -- pollution ages faster with each level of the bonus inventory researches
    bonus_inventory = { -- extra inventory slots for each level of these researches
        enabled = true,
        res = Feature.set{ "mining-productivity", "mining-productivity-2", "mining-productivity-3", "mining-productivity-4" },
        rate = 5,
        limit = 20,
    },
})

local bonus_inventory_name = "character_inventory_slots_bonus"

--- @param event EventData.on_research_finished
local function on_research_finished(event)
    local research_name = event.research.name
    if config.bonus_inventory.enabled and config.bonus_inventory.res[research_name] then
        event.research.force[bonus_inventory_name] = math.min((event.research.level - 1) * config.bonus_inventory.rate, config.bonus_inventory.limit)
    end
    
    if config.pollution_ageing_by_research and config.bonus_inventory.res[research_name] then
        game.map_settings.pollution.ageing = math.min(10, event.research.level / 5)
    end
end

--- @param event EventData.on_research_started
local function on_research_started(event)
    local limit = research_data.limit_res[event.research.name]
    if limit and event.research.level > limit then
        event.research.enabled = false
        event.research.visible_when_disabled = true
        local rq = event.research.force.research_queue

        for i = #rq, 1, -1 do
            if rq[i] == event.research.name then
                table.remove(rq, i)
            end
        end

        event.research.force.cancel_current_research()
        event.research.force.research_queue = rq
    end
end

local e = defines.events

return feature:guard{
    events = {
        [e.on_research_finished] = on_research_finished,
        [e.on_research_reversed] = on_research_finished,
        [e.on_research_started] = on_research_started,
        [e.on_research_queued] = on_research_started,
    }
}
