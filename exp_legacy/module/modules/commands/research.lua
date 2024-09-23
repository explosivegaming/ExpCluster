local Global = require 'utils.global' --- @dep utils.global
local Event = require 'utils.event' --- @dep utils.event
local Commands = require 'expcore.commands' --- @dep expcore.commands
local config = require 'config.research' --- @dep config.research

local research = {}
Global.register(research, function(tbl)
    research = tbl
end)

local function res_queue(force, by_script)
    local res_q = force.research_queue
    local res = force.technologies['mining-productivity-4']

    if #res_q < config.queue_amount then
        for i=1, config.queue_amount - #res_q do
            force.add_research(res)

            if not (by_script) then
                game.print{'expcom-res.inf-q', res.name, res.level + i}
            end
        end
    end
end

Commands.new_command('auto-research', {'expcom-res.description-ares'}, 'Automatically queue up research')
:add_alias('ares')
:register(function(player)
    research.res_queue_enable = not research.res_queue_enable

    if research.res_queue_enable then
        res_queue(player.force, true)
    end

    game.print{'expcom-res.res', player.name, research.res_queue_enable}
    return Commands.success
end)

Event.add(defines.events.on_research_finished, function(event)
    if research.res_queue_enable then
        if event.research.force.rockets_launched > 0 and event.research.force.technologies['mining-productivity-4'].level > 4 then
            res_queue(event.research.force, event.by_script)
        end
    end
end)
