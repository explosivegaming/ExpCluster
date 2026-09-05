--[[-- Commands Module - Quickbar
    - Adds a command that allows players to load Quickbar presets
    @data Quickbar
]]

local Commands = require("modules/exp_commands")
local config = require("modules.exp_legacy.config.preset_player_quickbar") --- @dep config.preset_player_quickbar

--- Stores the quickbar filters for a player
local PlayerData = require("modules.exp_legacy.expcore.player_data") --- @dep expcore.player_data
local PlayerFilters = PlayerData.Settings:combine("QuickbarFilters")
PlayerFilters:set_metadata{
    permission = "exp_scenario.command.save_quickbar",
    stringify = function(value)
        if not value then return "No filters set" end
        local count = 0
        for _ in pairs(value) do count = count + 1 end

        return count .. " filters set"
    end,
}

--- Filters are stored by a single index across the ten pages of ten slots
local slots_per_page = 10

--- Loads your quickbar preset
PlayerFilters:on_load(function(player_name, filters)
    if not filters then filters = config[player_name] end
    if not filters then return end
    local player = game.players[player_name]
    for index, item_name in pairs(filters) do
        if item_name ~= nil and item_name ~= "" then
            local page = math.ceil(index / slots_per_page)
            local slot = (index - 1) % slots_per_page + 1
            player.set_quick_bar_slot(page, slot, item_name)
        end
    end
end)

--- Saves your quickbar preset, only plain item filters can be saved
Commands.new("save-quickbar", "Saves your Quickbar preset items to file")
    :add_aliases{ "save-toolbar" }
    :register(function(player)
        local filters = {}

        for page = 1, slots_per_page do
            for slot = 1, slots_per_page do
                -- Records, remotes and specific item instances hold data which can not be saved by name
                local quick_bar_slot = player.get_quick_bar_slot(page, slot)
                if quick_bar_slot and quick_bar_slot.type == "filter" then
                    filters[(page - 1) * slots_per_page + slot] = assert(quick_bar_slot.filter).name
                end
            end
        end

        if next(filters) then
            PlayerFilters:set(player, filters)
        else
            PlayerFilters:remove(player)
        end

        return Commands.status.success{ "quickbar.saved" }
    end)
