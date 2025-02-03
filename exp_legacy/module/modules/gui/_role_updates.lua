local Gui = require("modules/exp_gui")
local Roles = require("modules.exp_legacy.expcore.roles")
local Event = require("modules/exp_legacy/utils/event")

--- @diagnostic disable invisible
Event.add(Roles.events.on_role_assigned, Gui._ensure_consistency)
Event.add(Roles.events.on_role_unassigned, Gui._ensure_consistency)
