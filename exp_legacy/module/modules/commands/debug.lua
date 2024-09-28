--[[-- Commands Module - Debug
    - Adds a command that opens the debug frame
    @commands Debug
]]

local DebugView = require("modules.exp_legacy.modules.gui.debug.main_view") --- @dep modules.gui.debug.main_view
local Commands = require("modules.exp_legacy.expcore.commands") --- @dep expcore.commands

--- Opens the debug pannel for viewing tables.
-- @command debug
Commands.new_command("debug", { "expcom-debug.description" }, "Opens the debug pannel for viewing tables.")
    :register(function(player)
        DebugView.open_dubug(player)
    end)
