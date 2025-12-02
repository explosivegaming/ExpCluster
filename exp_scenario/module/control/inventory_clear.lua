--[[-- Control - Inventory Clear
Will move players items to spawn when they are banned or kicked, option to clear on leave
]]

local ExpUtil = require("modules/exp_util")
local events = require("modules.exp_legacy.config.inventory_clear")

--- @param event { player_index: number }
local function clear_items(event)
    local player = assert(game.get_player(event.player_index))
    local inventory = assert(player.get_main_inventory())
    ExpUtil.transfer_inventory_to_surface{
        inventory = inventory,
        surface = game.planets.nauvis.surface,
        name = "iron-chest",
        allow_creation = true,
    }
end

local event_handlers = {}
for _, event_name in ipairs(events) do
    event_handlers[event_name] = clear_items
end

return {
    events = event_handlers,
}
