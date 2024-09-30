--- Will move players items to spawn when they are banned or kicked, option to clear on leave
-- @addon Inventory-Clear

local ExpUtil = require("modules/exp_util")
local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event
local events = require("modules.exp_legacy.config.inventory_clear") --- @dep config.inventory_clear

local function clear_items(event)
    local player = game.players[event.player_index]
    local inventory = assert(player.get_main_inventory())
    ExpUtil.transfer_inventory_to_surface{
        inventory = inventory,
        surface = game.surfaces[1],
        name = "iron-chest",
        allow_creation = true,
    }
end

for _, event_name in ipairs(events) do Event.add(event_name, clear_items) end
