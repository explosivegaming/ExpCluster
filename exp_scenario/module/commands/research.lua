--[[-- Commands - Research
Adds a command to enable automatic research queueing
]]

local Storage = require("modules/exp_util/storage")
local Commands = require("modules/exp_commands")
local format_player_name = Commands.format_player_name_locale

local config = require("modules.exp_legacy.config.research") --- @dep config.research

--- @class ExpCommands_Research.commands
local commands = {}

local research = {
    res_queue_enable = false
}

Storage.register(research, function(tbl)
    research = tbl
end)

--- @param force LuaForce
--- @param silent boolean True when no message should be printed
local function queue_research(force, silent)
    local res_q = force.research_queue
    local res = force.technologies[config.bonus_inventory.log[config.mod_set].name]

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
local function set_auto_research(state)
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
--- @class ExpCommand_Artillery.commands.artillery: ExpCommand
--- @overload fun(player: LuaPlayer, state: boolean?)
commands.set_auto_research = Commands.new("set-auto-research", { "exp-commands_research.description" })
    :optional("state", { "exp-commands_research.arg-state" }, Commands.types.boolean)
    :add_aliases{ "auto-research" }
    :register(function(player, state)
        --- @cast state boolean?
        local enabled = set_auto_research(state)

        if enabled then
            queue_research(player.force --[[@as LuaForce]], true)
        end

        local player_name = format_player_name(player)
        game.print{ "exp-commands_research.auto-research", player_name, enabled }
    end) --[[ @as any ]]

--- @param event EventData.on_research_finished
local function on_research_finished(event)
    if not research.res_queue_enable then return end

    local force = event.research.force
    local log_research = assert(config.bonus_inventory.log[config.mod_set], "Unknown mod set: " .. tostring(config.mod_set))
    local technology = assert(force.technologies[log_research.name], "Unknown technology: " .. tostring(log_research.name))
    if technology.level > log_research.level then
        queue_research(force, event.by_script)
    end
end

local e = defines.events

return {
    commands = commands,
    events = {
        [e.on_research_finished] = on_research_finished,
    },
}
