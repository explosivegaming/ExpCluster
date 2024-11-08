local Commands = require("modules/exp_commands")
local config = require("modules.exp_legacy.config.graftorio")
local statics = require("modules.exp_legacy.modules.graftorio.statics")
local general = require("modules.exp_legacy.modules.graftorio.general")
local forcestats = nil

local table_to_json = helpers.table_to_json

if config.modules.forcestats then
    forcestats = require("modules.exp_legacy.modules.graftorio.forcestats")
end

Commands.new("collectdata", "Collect data for RCON usage")
    :optional("location", "", Commands.types.string) -- Not sure what this is for, i didn't write this
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
        return Commands.status.success(table_to_json(general.data.output))
    end)
