local Gui = require("modules/exp_gui")
local PlayerData = require("modules.exp_legacy.expcore.player_data")

-- Used to store the state of the toolbar when a player leaves
local ToolbarState = PlayerData.Settings:combine("ToolbarState")
ToolbarState:set_metadata{
    stringify = function()
        return "Toolbar is saved on exit"
    end,
}

--- Uncompress the data to be more useable
ToolbarState:on_load(function(player_name, value)
    -- If there is no value, do nothing
    if value == nil then return end
    -- Old format, we discard it [ string[], string[], string[], boolean ]
    if type(value) ~= "string" then return end

    local decompressed = helpers.json_to_table(assert(helpers.decode_string(value), "Failed String Decode"))
    local player = assert(game.get_player(player_name))
    Gui.toolbar.set_state(player, decompressed --[[ @as ExpGui.ToolbarState ]])

    return nil -- We don't save the state, use Gui.toolbar.get_state
end)

--- Save the current state of the players toolbar menu
ToolbarState:on_save(function(player_name, _)
    local player = assert(game.get_player(player_name))
    local value = Gui.toolbar.get_state(player)
    return helpers.encode_string(helpers.table_to_json(value))
end)
