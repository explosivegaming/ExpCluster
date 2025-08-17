--[[ Control - Research
Various research related event handlers

TODO Refactor this fully, this is temp to get it out of the research times gui file
]]

local config = require("modules/exp_legacy/config/research")

--- @param event EventData.on_research_finished
local function on_research_finished(event)
    local research_name = event.research.name
    if config.bonus_inventory.enabled and config.bonus_inventory.res[research_name] then
        event.research.force[config.bonus_inventory.name] = math.min((event.research.level - 1) * config.bonus_inventory.rate, config.bonus_inventory.limit)
    end

    if config.pollution_ageing_by_research and config.bonus_inventory.res[research_name] then
        game.map_settings.pollution.ageing = math.min(10, event.research.level / 5)
    end
end

--- @param event EventData.on_research_started
local function on_research_started(event)
    if config.limit_res[event.research.name] and event.research.level > config.limit_res[event.research.name] then
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

return {
    events = {
        [e.on_research_finished] = on_research_finished,
        [e.on_research_started] = on_research_started,
    }
}
