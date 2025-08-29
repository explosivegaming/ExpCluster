--[[-- Gui - Server UPS
Adds a server ups counter in the top right corner and a command to toggle it
]]

local Gui = require("modules/exp_gui")
local ExpUtil = require("modules/exp_util")
local Commands = require("modules/exp_commands")

--- @class ExpServerUps.elements
local Elements = {}

--- Stores the visible state of server ups element for a player
local PlayerData = require("modules/exp_legacy/expcore/player_data")
local UsesServerUps = PlayerData.Settings:combine("UsesServerUps")
UsesServerUps:set_default(false)
UsesServerUps:set_metadata{
    permission = "command/server-ups",
    stringify = function(value) return value and "Visible" or "Hidden" end,
}

--- Change the visible state when your data loads
UsesServerUps:on_load(function(player_name, visible)
    local player = assert(game.get_player(player_name))
    Elements.server_ups.set_visible(player, visible or false)
end)

--- Label to show the server ups, drawn to screen on join
--- @class ExpServerUps.elements.server_ups: ExpElement
--- @overload fun(parent: LuaGuiElement, visible: boolean?): LuaGuiElement
Elements.server_ups = Gui.define("server_ups")
    :track_all_elements()
    :draw{
        type = "label",
        visible = Gui.from_argument(1),
    }
    :style{
        font = "default-game",
    }
    :player_data(function(def, element)
        local player = Gui.get_player(element)
        local existing = def.data[player]
        if not existing or not existing.valid then
            def.data[player] = element -- Only set if previous is invalid
        end
    end) --[[ @as any ]]

--- Refresh the caption for all online players
--- @param ups number The UPS to be displayed
function Elements.server_ups.refresh_online(ups)
    local caption = ("%.1f (%.1f%%)"):format(ups, ups * 5 / 3)
    for _, server_ups in Elements.server_ups:online_elements() do
        server_ups.caption = caption
    end
end

--- Get the main label for a player
--- @param player LuaPlayer
--- @return LuaGuiElement
function Elements.server_ups.get_main_label(player)
    return Elements.server_ups.data[player] or Elements.server_ups(player.gui.screen, UsesServerUps:get(player))
end

--- Set the visible state of the main label
--- @param player LuaPlayer
--- @param visible boolean
function Elements.server_ups.set_visible(player, visible)
    Elements.server_ups.get_main_label(player).visible = visible
end

--- Toggles if the server ups is visbile
Commands.new("server-ups", { "exp_server-ups.description" })
    :add_aliases{ "sups", "ups" }
    :register(function(player)
        local visible = not UsesServerUps:get(player)
        Elements.server_ups.set_visible(player, visible)
        UsesServerUps:set(player, visible)
    end)

--- Add an interface which can be called from rcon
Commands.add_rcon_static("exp_server_ups", {
    refresh = function(ups)
        ExpUtil.assert_argument_type(ups, "number", 1, "ups")
        Elements.server_ups.refresh_online(ups)
        return game.tick
    end
})

--- Set the location of the label
local function set_location(event)
    local player = Gui.get_player(event)
    local element = Elements.server_ups.get_main_label(player)

    local uis = player.display_scale
    local res = player.display_resolution
    element.location = { x = res.width - 363 * uis, y = 31 * uis } -- below ups and clock
end

local e = defines.events

return {
    elements = Elements,
    events = {
        [e.on_player_created] = set_location,
        [e.on_player_joined_game] = set_location,
        [e.on_player_display_resolution_changed] = set_location,
        [e.on_player_display_scale_changed] = set_location,
    },
}
