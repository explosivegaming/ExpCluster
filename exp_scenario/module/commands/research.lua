--[[-- Commands - Research
Adds a command to enable automatic research queueing
]]

local Storage = require("modules/exp_util/storage")
local Commands = require("modules/exp_commands")
local format_player_name = Commands.format_player_name_locale

local config = require("modules.exp_legacy.config.research") --- @dep config.research

--- @class Command.Research
local module = {}

local research = {
    res_queue_enable = false
}

Storage.register(research, function(tbl)
    research = tbl
end)

--- @param force LuaForce
--- @param silent boolean True when no message should be printed
function module.res_queue(force, silent)
    local res_q = force.research_queue
    local res = force.technologies[config.bonus_inventory.res[config.mod_set].name]

    if #res_q < config.queue_amount then
        for i = #res_q, config.queue_amount - 1 do
            force.add_research(res)

            if not silent then
                game.print{ "exp-commands_research.queue", res.name, res.level + i }
            end
        end
    end
end

--- @param state boolean? use nil to toggle current state
--- @return boolean # New auto research state
function module.set_auto_research(state)
    local new_state
    if state == nil then
        new_state = not research.res_queue_enable
    else
        new_state = state ~= false
    end

    research.res_queue_enable = new_state
    return new_state
end

--- Sets the auto research state
Commands.new("set-auto-research", { "exp-commands_research.description" })
    :optional("state", { "exp-commands_research.arg-state" }, Commands.types.boolean)
    :add_aliases{ "auto-research" }
    :register(function(player, state)
        --- @cast state boolean?
        local enabled = module.set_auto_research(state)

        if enabled then
            module.res_queue(player.force --[[@as LuaForce]], true)
        end

        local player_name = format_player_name(player)
        game.print{ "exp-commands_research.auto-research", player_name, enabled }
    end)

--- @param event EventData.on_research_finished
local function on_research_finished(event)
    if not research.res_queue_enable then return end

    local force = event.research.force
    if config.bonus_inventory.res[config.mod_set] and force.technologies[config.bonus_inventory.res[config.mod_set].name] and force.technologies[config.bonus_inventory.res[config.mod_set].name].level > config.bonus_inventory.res[config.mod_set].level then
        module.res_queue(force, event.by_script)
    end
end

local e = defines.events
--- @package
module.events = {
    [e.on_research_finished] = on_research_finished,
}

return module
