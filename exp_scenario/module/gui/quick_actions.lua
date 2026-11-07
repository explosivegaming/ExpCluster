--[[-- Gui - Quick Actions
Adds a few buttons for common actions
]]

local Gui = require("modules/exp_gui")
local Commands = require("modules/exp_commands")
local Feature = require("modules/exp_scenario/features")
local Roles = require("modules/exp_roles")

local addon_artillery = require("modules/exp_scenario/commands/artillery")
local addon_trains = require("modules/exp_scenario/commands/trains")
local addon_teleport = require("modules/exp_scenario/commands/teleport")
local addon_waterfill = require("modules/exp_scenario/commands/waterfill")
local addon_surface = require("modules/exp_scenario/commands/surface")
local addon_lawnmower = require("modules/exp_scenario/commands/lawnmower")
local addon_home = require("modules/exp_scenario/commands/home")
local addon_vlayer = require("modules/exp_scenario/commands/vlayer")
local addon_repair = require("modules/exp_scenario/commands/repair")

--- @class ExpGui_QuickActions.elements
local Elements = {}

--- @type table<string, { command: ExpCommand, element: ExpElement }>
local Actions = {}

--- @param command ExpCommand | function (this is needed because of the overload on commands)
--- @param locale table<string, string>
--- @param on_click? ExpElement.EventHandler<EventData.on_gui_click>
local function new_quick_action(command, locale, on_click)
    local command_name = command.name

    local element = Gui.define("quick_actions/" .. command_name)
        :draw{
            type = "button",
            caption = { locale.caption },
            tooltip = { locale.tooltip },
        }
        :style{
            width = 160,
        }
        :on_click(on_click or function(_def, player, _element, _event)
            command(player)
        end)

    Elements[command_name] = element
    Actions[command_name] = {
        command = command --[[@as ExpCommand]],
        element = element,
    }
end

new_quick_action(addon_artillery.commands.artillery, {
    caption = "exp-commands_artillery.selection-name",
    tooltip = "exp-commands_artillery.description"
})

new_quick_action(addon_trains.commands.set_trains_to_automatic, {
    caption = "exp-commands_trains.caption",
    tooltip = "exp-commands_trains.description"
})

new_quick_action(addon_teleport.commands.spawn, {
    caption = "exp-commands_teleport.description-spawn",
    tooltip = "exp-commands_teleport.description-spawn"
}, function(def, player, element, event)
    addon_teleport.commands.spawn(player, player)
end)

new_quick_action(addon_waterfill.commands.waterfill, {
    caption = "exp-commands_waterfill.selection-name",
    tooltip = "exp-commands_waterfill.description"
})

new_quick_action(addon_lawnmower.commands.lawnmower, {
    caption = "exp-commands_lawnmower.selection-name",
    tooltip = "exp-commands_lawnmower.description"
})

new_quick_action(addon_surface.commands.clear_ground_items, {
    caption = "exp-commands_surface.caption-items",
    tooltip = "exp-commands_surface.description-items"
})

new_quick_action(addon_surface.commands.clear_blueprints_surface, {
    caption = "exp-commands_surface.caption-blueprints-surface",
    tooltip = "exp-commands_surface.description-blueprints-surface"
})

new_quick_action(addon_surface.commands.clear_blueprints, {
    caption = "exp-commands_surface.caption-blueprints",
    tooltip = "exp-commands_surface.description-blueprints"
})

new_quick_action(addon_home.commands.home, {
    caption = "exp-commands_home.caption-home",
    tooltip = "exp-commands_home.description-home"
})

new_quick_action(addon_home.commands.home_return, {
    caption = "exp-commands_home.caption-return",
    tooltip = "exp-commands_home.description-return"
})

new_quick_action(addon_home.commands.set_home, {
    caption = "exp-commands_home.caption-set",
    tooltip = "exp-commands_home.description-set"
})

new_quick_action(addon_home.commands.get_home, {
    caption = "exp-commands_home.caption-get",
    tooltip = "exp-commands_home.description-get"
})

new_quick_action(addon_vlayer.commands.vlayer, {
    caption = "exp-commands_vlayer.caption",
    tooltip = "exp-commands_vlayer.description"
})

new_quick_action(addon_repair.commands.repair, {
    caption = "exp-commands_repair.selection-name",
    tooltip = "exp-commands_repair.description"
})

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
        return Roles.player_has_permission(player, "exp_scenario.gui.tool")
    end
}

--- @param event { player_index: number }
local function on_role_changed(event)
    local player = Gui.get_player(event)
    Elements.container.refresh_player(player)
end

--- Actions for commands of a disabled feature are hidden
--- @param event EventData.ExpScenario.on_config_updated
local function on_config_updated(event)
    if event.path ~= "enabled" then return end
    for _, player in pairs(game.connected_players) do
        Elements.container.refresh_player(player)
    end
end

return {
    elements = Elements,
    events = {
        [Roles.events.on_player_roles_changed] = on_role_changed,
        [Feature.events.on_config_updated] = on_config_updated,
    }
}
