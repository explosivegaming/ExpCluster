--- Config for the different action buttons that show on the player list;
-- each button has the button define(s) given along side an auth function, and optional reason callback;
-- if a reason callback is used then Store.set(action_name_store,player.name,'BUTTON_NAME') should be called during on_click;
-- buttons can be removed from the gui by commenting them out of the config at the bottom of this file;
-- the key used for the name of the button is the permission name used by the role system;
-- @config Player-List

local ExpUtil = require("modules/exp_util")
local Gui = require("modules/exp_gui")
local Roles = require("modules/exp_roles")
local Reports = require("modules.exp_legacy.modules.control.reports") --- @dep modules.control.reports
local Jail = require("modules/exp_scenario/control/jail")
local Colors = require("modules/exp_util/include/color")
local format_player_name = ExpUtil.format_player_name_locale

--- Accessors injected by the gui so the actions can read the selected player and set the selected action
local get_selected_player --- @type fun(player: LuaPlayer): LuaPlayer
local set_selected_action --- @type fun(player: LuaPlayer, action: string?)
local function set_accessors(player_getter, action_setter)
    get_selected_player, set_selected_action = player_getter, action_setter
end

-- gets the action player and a coloured name for the action to be used on
local function get_action_player(player)
    local selected_player = get_selected_player(player) --[[@as LuaPlayer]]
    local selected_player_color = format_player_name(selected_player)
    return selected_player, selected_player_color
end

-- teleports one player to another
local function teleport(from_player, to_player)
    local surface = to_player.physical_surface
    local position = surface.find_non_colliding_position("character", to_player.physical_position, 32, 1)
    if not position then return false end -- return false if no new position
    if from_player.driving then from_player.driving = false end -- kicks a player out a vehicle if in one
    from_player.teleport(position, surface)
    return true
end

local function new_button(sprite, tooltip)
    return Gui.define(tooltip[1])
        :draw{
            type = "sprite-button",
            style = "tool_button",
            sprite = sprite,
            tooltip = tooltip,
        }
        :style{
            padding = -1,
            height = 28,
            width = 28,
        }
end

--- Teleports the user to the action player
-- @element goto_player
local goto_player = new_button("utility/export", { "exp-gui_player-list.goto-player" })
    :on_click(function(def, player, element)
        local selected_player = get_action_player(player)
        if not player.character or not selected_player.character then
            player.print({ "exp-commands-parse.player-alive" }, Colors.orange_red)
        else
            teleport(player, selected_player)
        end
    end)

--- Teleports the action player to the user
-- @element bring_player
local bring_player = new_button("utility/import", { "exp-gui_player-list.bring-player" })
    :on_click(function(def, player, element)
        local selected_player = get_action_player(player)
        if not player.character or not selected_player.character then
            player.print({ "exp-commands-parse.player-alive" }, Colors.orange_red)
        else
            teleport(selected_player, player)
        end
    end)

--- Reports the action player, requires a reason to be given
-- @element report_player
local report_player = new_button("utility/spawn_flag", { "exp-gui_player-list.report-player" })
    :on_click(function(def, player, element)
        local selected_player = get_action_player(player)
        if Reports.is_reported(selected_player.name, player.name) then
            player.print({ "exp-commands_report.already-reported" }, Colors.orange_red)
        else
            set_selected_action(player, "exp_scenario.command.create_report")
        end
    end)

local function report_player_callback(player, reason)
    local selected_player, selected_player_color = get_action_player(player)
    local by_player_name_color = format_player_name(player)
    game.print{ "exp-commands_reports.response", selected_player_color, reason }
    local trainee = Roles.get_role_by_name("Trainee")
    for _, role in ipairs(trainee and Roles.get_higher_roles(trainee) or {}) do
        role:print{ "exp-commands_reports.response-admin", selected_player_color, by_player_name_color, reason }
    end
    Reports.report_player(selected_player.name, player.name, reason)
end

--- Jails the action player, requires a reason
-- @element jail_player
local jail_player = new_button("utility/multiplayer_waiting_icon", { "exp-gui_player-list.jail-player" })
    :on_click(function(def, player, element)
        local selected_player, selected_player_color = get_action_player(player)
        if Jail.is_jailed(selected_player) then
            player.print({ "exp-commands_jail.already-jailed", selected_player_color }, Colors.orange_red)
        else
            set_selected_action(player, "exp_scenario.command.jail")
        end
    end)

local function jail_player_callback(player, reason)
    local selected_player, selected_player_color = get_action_player(player)
    local by_player_name_color = format_player_name(player)
    game.print{ "exp-commands_jail.jailed", selected_player_color, by_player_name_color, reason }
    Jail.jail_player(selected_player, player.name, reason)
end

--- Kicks the action player, requires a reason
-- @element kick_player
local kick_player = new_button("utility/warning_icon", { "exp-gui_player-list.kick-player" })
    :on_click(function(def, player, element)
        set_selected_action(player, "exp_scenario.gui.player_list.kick")
    end)

local function kick_player_callback(player, reason)
    local selected_player = get_action_player(player)
    game.kick_player(selected_player, reason)
end

--- Bans the action player, requires a reason
-- @element ban_player
local ban_player = new_button("utility/danger_icon", { "exp-gui_player-list.ban-player" })
    :on_click(function(def, player, element)
        set_selected_action(player, "exp_scenario.gui.player_list.ban")
    end)

local function ban_player_callback(player, reason)
    local selected_player = get_action_player(player)
    game.ban_player(selected_player, reason)
end

return {
    set_accessors = set_accessors,
    buttons = {
        ["exp_scenario.command.teleport"] = {
            auth = function(player, selected_player)
                return player.name ~= selected_player.name
            end, -- cant teleport to your self
            goto_player,
            bring_player,
        },
        ["exp_scenario.command.create_report"] = {
            auth = function(player, selected_player)
                if player == selected_player then return false end
                return not Roles.player_has_permission(selected_player, "exp_scenario.bypass.reports")
            end, -- can report any player that isn't immune
            reason_callback = report_player_callback,
            report_player,
        },
        ["exp_scenario.command.jail"] = {
            auth = Roles.player_outranks,
            reason_callback = jail_player_callback,
            jail_player,
        },
        ["exp_scenario.gui.player_list.kick"] = {
            auth = Roles.player_outranks,
            reason_callback = kick_player_callback,
            kick_player,
        },
        ["exp_scenario.gui.player_list.ban"] = {
            auth = Roles.player_outranks,
            reason_callback = ban_player_callback,
            ban_player,
        },
    },
}
