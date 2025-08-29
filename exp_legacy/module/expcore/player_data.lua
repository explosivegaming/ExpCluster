--[[-- Core Module - PlayerData
- A module used to store player data in a central datastore to minimize data requests and saves.
@core PlayerData

@usage-- Adding a colour setting for players
local PlayerData = require("modules.exp_legacy.expcore.player_data")
local PlayerColors = PlayerData.Settings:combine('Color')

-- Set the players color when their data is loaded
PlayerColors:on_load(function(player_name, color)
    local player = game.players[player_name]
    player.color = color
end)

-- Overwrite the saved color with the players current color
PlayerColors:on_save(function(player_name, _)
    local player = game.players[player_name]
    return player.color -- overwrite existing data with the current color
end)

@usage-- Add a playtime statistic for players
local Event = require("modules/exp_legacy/utils/event")
local PlayerData = require("modules.exp_legacy.expcore.player_data")
local Playtime = PlayerData.Statistics:combine('Playtime')

-- When playtime reaches an hour interval tell the player and say thanks
Playtime:on_update(function(player_name, playtime)
    if playtime % 60 == 0 then
        local hours = playtime / 60
        local player = game.players[player_name]
        player.print('Thanks for playing on our servers, you have played for '..hours..' hours!')
    end
end)

-- Update playtime for players, data is only loaded for online players so update_all can be used
Event.add_on_nth_tick(3600, function()
    Playtime:update_all(function(player_name, playtime)
        return playtime + 1
    end)
end)

]]

local Async = require("modules/exp_util/async")
local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event
local Datastore = require("modules.exp_legacy.expcore.datastore") --- @dep expcore.datastore
local Commands = require("modules/exp_commands")

local table_to_json = helpers.table_to_json
local write_file = helpers.write_file

--- Common player data that acts as the root store for player data
local PlayerData = Datastore.connect("PlayerData", true) -- saveToDisk
PlayerData:set_serializer(Datastore.name_serializer) -- use player name

--- Store and enum for the data saving preference
local DataSavingPreference = PlayerData:combine("DataSavingPreference")
local PreferenceEnum = { "All", "Statistics", "Settings", "Required" }
for k, v in ipairs(PreferenceEnum) do PreferenceEnum[v] = k end

DataSavingPreference:set_default("All")
DataSavingPreference:set_metadata{
    name = { "expcore-data.preference" },
    tooltip = { "expcore-data.preference-tooltip" },
    value_tooltip = { "expcore-data.preference-value-tooltip" },
}

--- Sets your data saving preference
Commands.new("data-preference", { "expcore-data.description-preference" })
    :optional("option", { "expcore-data.arg-option" }, Commands.types.enum(PreferenceEnum))
    :register(function(player, option)
        --- @cast option "All" | "Statistics" | "Settings" | "Required" | nil
        if option then
            DataSavingPreference:set(player, option)
            return Commands.status.success{ "expcore-data.set-preference", option }
        else
            return Commands.status.success{ "expcore-data.get-preference", DataSavingPreference:get(player) }
        end
    end)

--- Gets your data and writes it to a file
Commands.new("save-data", { "expcore-data.description-data" })
    :register(function(player)
        player.print{ "expcore-data.get-data" }
        write_file("expgaming_player_data.json", table_to_json(PlayerData:get(player, {})), false, player.index)
    end)

--- Async function called after 5 seconds with no player data loaded
local check_data_loaded_async =
    Async.register(function(player)
        local player_data = PlayerData:get(player)
        if not player_data or not player_data.valid then
            player.print{ "expcore-data.data-failed" }
            Datastore.ingest("request", "PlayerData", player.name, '{"valid":false}')
        end
    end)

--- When player data loads tell the player if the load had failed previously
PlayerData:on_load(function(player_name, player_data, existing_data)
    if not player_data or player_data.valid == false then return end
    if existing_data and existing_data.valid == false then
        game.players[player_name].print{ "expcore-data.data-restore" }
    end
    player_data.valid = true
end)

--- Remove data that the player doesnt want to have stored
PlayerData:on_save(function(player_name, player_data)
    local data_preference = DataSavingPreference:get(player_name)
    data_preference = PreferenceEnum[data_preference]
    if data_preference == PreferenceEnum.All then
        player_data.valid = nil
        return player_data
    end

    local saved_player_data = { PlayerRequired = player_data.PlayerRequired, DataSavingPreference = PreferenceEnum[data_preference] }
    if data_preference <= PreferenceEnum.Settings then saved_player_data["PlayerSettings"] = player_data.PlayerSettings end
    if data_preference <= PreferenceEnum.Statistics then saved_player_data["PlayerStatistics"] = player_data.PlayerStatistics end

    return saved_player_data
end)

--- Display your data preference when your data loads
DataSavingPreference:on_load(function(player_name, data_preference)
    game.players[player_name].print{ "expcore-data.get-preference", data_preference or DataSavingPreference.default }
end)

--- Load player data when they join
Event.add(defines.events.on_player_joined_game, function(event)
    local player = game.players[event.player_index]
    check_data_loaded_async:start_after(300, player)
    PlayerData:request(player)
end)

--- Unload player data when they leave
Event.add(defines.events.on_player_left_game, function(event)
    local player = game.players[event.player_index]
    local player_data = PlayerData:get(player)
    if player_data and player_data.valid == true then
        PlayerData:unload(player)
    end
end)

----- Module Return -----
return {
    All = PlayerData, -- Root for all of a players data
    Statistics = PlayerData:combine("Statistics"), -- Common place for stats
    Settings = PlayerData:combine("Settings"), -- Common place for settings
    Required = PlayerData:combine("Required"), -- Common place for required data
    DataSavingPreference = DataSavingPreference, -- Stores what data groups will be saved
    PreferenceEnum = PreferenceEnum, -- Enum for the allowed options for data saving preference
}
