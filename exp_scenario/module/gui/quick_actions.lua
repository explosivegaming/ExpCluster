--[[-- Gui - Quick Actions
Adds a few buttons for common actions
]]

local Gui = require("modules/exp_gui")
local Commands = require("modules/exp_commands")
local Roles = require("modules/exp_legacy/expcore/roles")

local addon_artillery = require("modules/exp_scenario/commands/artillery")
local addon_research = require("modules/exp_scenario/commands/research")
local addon_trains = require("modules/exp_scenario/commands/trains")
local addon_teleport = require("modules/exp_scenario/commands/teleport")
local addon_waterfill = require("modules/exp_scenario/commands/waterfill")

--- @class ExpGui_QuickActions.elements
local Elements = {}

--- @type table<string, { command: ExpCommand, element: ExpElement }>
local Actions = {}

--- @param name string
--- @param command ExpCommand | function (this is needed because of the overload on commands)
--- @param on_click? ExpElement.EventHandler<EventData.on_gui_click>
local function new_quick_action(name, command, on_click)
    local element = Gui.define("quick_actions/" .. name)
        :draw{
            type = "button",
            caption = { "exp-gui_quick-actions.caption-" .. name },
            tooltip = { "exp-gui_quick-actions.tooltip-" .. name },
        }
        :style{
            width = 160,
        }
        :on_click(on_click or function(def, player, element, event)
            command(player)
        end)

    Elements[name] = element
    Actions[name] = {
        command = command --[[ @as ExpCommand ]],
        element = element,
    }
end

new_quick_action("artillery", addon_artillery.commands.artillery)
new_quick_action("trains", addon_trains.commands.set_trains_to_automatic)
new_quick_action("research", addon_research.commands.set_auto_research)

new_quick_action("spawn", addon_teleport.commands.spawn, function(def, player, element, event)
    addon_teleport.commands.spawn(player, player)
end)

new_quick_action("waterfill", addon_waterfill.commands.waterfill)

--- Container added to the left gui flow
--- @class ExpGui_QuickActions.elements.container: ExpElement
--- @field data table<LuaGuiElement, { [string]: LuaGuiElement }>
Elements.container = Gui.define("quick_actions/container")
    :draw(function(def, parent)
        --- @cast def ExpGui_QuickActions.elements.container
        local player = Gui.get_player(parent)
        local container = Gui.elements.container(parent)

        local buttons = {}
        for name, action in pairs(Actions) do
            local button = action.element(container)
            button.visible = Commands.player_has_permission(player, action.command)
            buttons[name] = button
        end

        def.data[container] = buttons
        return container.parent
    end)

--- Refresh all containers for a player
function Elements.container.refresh_player(player)
    local allowed = {}
    for name, action in pairs(Actions) do
        allowed[name] = Commands.player_has_permission(player, action.command)
    end

    for _, container in Elements.container:tracked_elements(player) do
        local buttons = Elements.container.data[container]
        for name, visible in pairs(allowed) do
            buttons[name].visible = visible
        end
    end
end

--- Add the element to the left flow with a toolbar button
Gui.add_left_element(Elements.container, false)
Gui.toolbar.create_button{
    name = "toggle_quick_actions",
    left_element = Elements.container,
    sprite = "item/repair-pack",
    tooltip = { "exp-gui_quick-actions.tooltip-main" },
    visible = function(player, element)
        return Roles.player_allowed(player, "gui/tool")
    end
}

--- @param event { player_index: number }
local function on_role_changed(event)
    local player = Gui.get_player(event)
    Elements.container.refresh_player(player)
end

return {
    elements = Elements,
    events = {
        [Roles.events.on_role_assigned] = on_role_changed,
        [Roles.events.on_role_unassigned] = on_role_changed,
    }
}
