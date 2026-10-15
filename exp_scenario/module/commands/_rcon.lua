--[[-- Command Rcon - ExpGaming
Adds rcon statics for the ExpGaming modules
]]

local Commands = require("modules/exp_commands")
local add_static, add_dynamic = Commands.add_rcon_static, Commands.add_rcon_dynamic

add_static("Gui", require("modules/exp_gui"))

add_static("Roles", require("modules/exp_roles"))
add_static("ExpServerList", require("modules/exp_server_list"))
