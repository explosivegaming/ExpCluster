--[[-- Commands - Debug
Adds a command that opens the debug frame
]]

local DebugView = require("modules.exp_legacy.modules.gui.debug.main_view") --- @dep modules.gui.debug.main_view
local Commands = require("modules/exp_commands")

--- Opens the debug gui.
Commands.new("debug", { "exp-commands_debug.description" })
    :register(DebugView.open_debug)
