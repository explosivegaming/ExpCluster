local event_handler = require("event_handler")

--- @type fun(lib: { on_init: fun(), on_load: fun(), events: { [defines.events]: fun(event: EventData) } })
local add = event_handler.add_lib

--- Command Extensions
require("modules/exp_scenario/commands/_authorities")
require("modules/exp_scenario/commands/_rcon")
require("modules/exp_scenario/commands/_types")

--- Commands with events
add(require("modules/exp_scenario/commands/protected_entities"))
add(require("modules/exp_scenario/commands/protected_tags"))
add(require("modules/exp_scenario/commands/research"))

--- Commands
require("modules/exp_scenario/commands/admin_chat")
require("modules/exp_scenario/commands/artillery")
require("modules/exp_scenario/commands/bot_queue")
require("modules/exp_scenario/commands/cheat")
require("modules/exp_scenario/commands/clear_inventory")
require("modules/exp_scenario/commands/connect")
require("modules/exp_scenario/commands/debug")
require("modules/exp_scenario/commands/enemy")
require("modules/exp_scenario/commands/home")
require("modules/exp_scenario/commands/jail")
require("modules/exp_scenario/commands/kill")
require("modules/exp_scenario/commands/lawnmower")
require("modules/exp_scenario/commands/locate")
require("modules/exp_scenario/commands/me")
require("modules/exp_scenario/commands/rainbow")
require("modules/exp_scenario/commands/ratio")
require("modules/exp_scenario/commands/repair")
require("modules/exp_scenario/commands/reports")
require("modules/exp_scenario/commands/roles")
require("modules/exp_scenario/commands/search")
require("modules/exp_scenario/commands/spectate")
require("modules/exp_scenario/commands/surface")
require("modules/exp_scenario/commands/teleport")
require("modules/exp_scenario/commands/trains")
require("modules/exp_scenario/commands/vlayer")
require("modules/exp_scenario/commands/warnings")
require("modules/exp_scenario/commands/waterfill")

--- Guis
add(require("modules/exp_scenario/gui/production"))
