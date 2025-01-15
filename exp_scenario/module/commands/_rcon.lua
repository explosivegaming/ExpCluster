--[[-- Command Rcon - ExpCore
Adds rcon interfaces for the legacy exp core
]]

local Commands = require("modules/exp_commands")
local add_static, add_dynamic = Commands.add_rcon_static, Commands.add_rcon_dynamic

add_static("Gui", require("modules/exp_gui"))

add_static("Group", require("modules.exp_legacy.expcore.permission_groups"))
add_static("Roles", require("modules.exp_legacy.expcore.roles"))
add_static("Datastore", require("modules.exp_legacy.expcore.datastore"))
add_static("External", require("modules.exp_legacy.expcore.external"))
