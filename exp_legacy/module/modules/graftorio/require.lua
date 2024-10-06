local Commands = require("modules.exp_legacy.expcore.commands")
local config = require("modules.exp_legacy.config.graftorio")
local statics = require("modules.exp_legacy.modules.graftorio.statics")
local general = require("modules.exp_legacy.modules.graftorio.general")
local forcestats = nil

local table_to_json = helpers.table_to_json

if config.modules.forcestats then
    forcestats = require("modules.exp_legacy.modules.graftorio.forcestats")
end

Commands.new_command("collectdata", "Collect data for RCON usage")
    :add_param("location", true)
    :register(function()
        -- this must be first as it overwrites the stats
        -- also makes the .other table for all forces
        statics.collect_statics()
        if config.modules.other then
            general.collect_other()
        end
        if config.modules.forcestats then
            --- @cast forcestats -nil
            forcestats.collect_production()
            forcestats.collect_loginet()
        end
        rcon.print(table_to_json(general.data.output))
        return Commands.success()
    end)
