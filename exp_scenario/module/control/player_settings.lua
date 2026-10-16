--[[-- Control - Player Settings
Sends settings of players to the controller, which keeps them between servers

The toolbar is sent compressed when a player leaves, the instance plugin
calls receive_toolbar with it when they join again
]]

local Gui = require("modules/exp_gui")
local clusterio_api = require("modules/clusterio/api")

--- @param event EventData.on_player_left_game
local function send_toolbar(event)
    local player = assert(game.get_player(event.player_index))
    local success, state = pcall(Gui.toolbar.get_state, player)
    if not success then
        log("[WARNING] Could not read the toolbar of " .. player.name .. ": " .. tostring(state))
        return
    end
    local toolbar = helpers.encode_string(helpers.table_to_json(state))
    clusterio_api.send_json("exp_scenario:toolbar", { player_name = player.name, toolbar = toolbar })
end

--- @param toolbar string
--- @return Gui.ToolbarState?
local function decode_toolbar(toolbar)
    local json = helpers.decode_string(toolbar)
    local state = json and helpers.json_to_table(json)
    if type(state) == "table" and type(state.order) == "table" and type(state.open) == "table"
    and type(state.visible) == "boolean" then
        return state --[[@as Gui.ToolbarState]]
    end
end

--- Restore the toolbar of a player, called over rcon by the instance plugin
--- @param player_name string
--- @param toolbar string From send_toolbar
local function receive_toolbar(player_name, toolbar)
    local player = game.get_player(player_name)
    if not player or not player.connected then
        return
    end

    -- Stored states can name buttons which no longer exist
    local success, err = pcall(function()
        local state = assert(decode_toolbar(toolbar), "invalid toolbar state")
        Gui.toolbar.set_state(player, state)
    end)
    if not success then
        log("[WARNING] Could not restore the toolbar of " .. player_name .. ": " .. tostring(err))
    end
end

local e = defines.events

return {
    events = {
        [e.on_player_left_game] = send_toolbar,
    },
    receive_toolbar = receive_toolbar,
}
