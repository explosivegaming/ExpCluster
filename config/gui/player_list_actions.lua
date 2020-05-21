--- Config for the different action buttons that show on the player list;
-- each button has the button define(s) given along side an auth function, and optional reason callback;
-- if a reason callback is used then Store.set(action_name_store,player.name,'BUTTON_NAME') should be called during on_click;
-- buttons can be removed from the gui by commenting them out of the config at the bottom of this file;
-- the key used for the name of the button is the permission name used by the role system;
-- @config Player-List

local Gui = require 'expcore.gui' --- @dep expcore.gui
local Roles = require 'expcore.roles' --- @dep expcore.roles
local Store = require 'expcore.store' --- @dep expcore.store
local Game = require 'utils.game' --- @dep utils.game
local Reports = require 'modules.control.reports' --- @dep modules.control.reports
local Warnings = require 'modules.control.warnings' --- @dep modules.control.warnings
local Jail = require 'modules.control.jail' --- @dep modules.control.jail
local Colors = require 'utils.color_presets' --- @dep utils.color_presets
local format_chat_player_name = _C.format_chat_player_name --- @dep expcore.common
local move_items = _C.move_items --- @dep expcore.common

local selected_player_store = ''
local selected_action_store = ''
local function set_store_uids(player,action)
    selected_player_store = player
    selected_action_store = action
end

-- auth that will only allow when on player's of lower roles
local function auth_lower_role(player,selected_player_name)
    local player_highest = Roles.get_player_highest_role(player)
    local action_player_highest = Roles.get_player_highest_role(selected_player_name)
    if player_highest.index < action_player_highest.index then
        return true
    end
end

-- gets the action player and a coloured name for the action to be used on
local function get_action_player_name(player)
    local selected_player_name = Store.get(selected_player_store,player)
    local selected_player = Game.get_player_from_any(selected_player_name)
    local selected_player_color = format_chat_player_name(selected_player)
    return selected_player_name, selected_player_color
end

-- telports one player to another
local function teleport(from_player,to_player)
    local surface = to_player.surface
    local position = surface.find_non_colliding_position('character',to_player.position,32,1)
    if not position then return false end -- return false if no new position
    if from_player.driving then from_player.driving = false end -- kicks a player out a vehicle if in one
    from_player.teleport(position,surface)
    return true
end

local function new_button(sprite,tooltip)
    return Gui.element{
        type = 'sprite-button',
        style = 'tool_button',
        sprite = sprite,
        tooltip = tooltip
    }:style{
        padding = -1,
        height = 28,
        width = 28
    }
end

--- Teleports the user to the action player
-- @element goto_player
local goto_player = new_button('utility/export',{'player-list.goto-player'})
:on_click(function(player)
    local selected_player_name = get_action_player_name(player)
    local selected_player = Game.get_player_from_any(selected_player_name)
    if not player.character or not selected_player.character then
        player.print({'expcore-commands.reject-player-alive'},Colors.orange_red)
    else
        teleport(player,selected_player)
    end
end)

--- Teleports the action player to the user
-- @element bring_player
local bring_player = new_button('utility/import',{'player-list.bring-player'})
:on_click(function(player)
    local selected_player_name = get_action_player_name(player)
    local selected_player = Game.get_player_from_any(selected_player_name)
    if not player.character or not selected_player.character then
        player.print({'expcore-commands.reject-player-alive'},Colors.orange_red)
    else
        teleport(selected_player,player)
    end
end)

--- Kills the action player, if there are alive
-- @element kill_player
local kill_player = new_button('utility/too_far',{'player-list.kill-player'})
:on_click(function(player)
    local selected_player_name = get_action_player_name(player)
    local selected_player = Game.get_player_from_any(selected_player_name)
    if selected_player.character then
        selected_player.character.die()
    else
        player.print({'expcom-kill.already-dead'},Colors.orange_red)
    end
end)

--- Reports the action player, requires a reason to be given
-- @element report_player
local report_player = new_button('utility/spawn_flag',{'player-list.report-player'})
:on_click(function(player)
    local selected_player_name = get_action_player_name(player)
    if Reports.is_reported(selected_player_name,player.name) then
        player.print({'expcom-report.already-reported'},Colors.orange_red)
    else
        Store.set(selected_action_store,player,'command/report')
    end
end)

local function report_player_callback(player,reason)
    local selected_player_name, selected_player_color = get_action_player_name(player)
    local by_player_name_color = format_chat_player_name(player)
    game.print{'expcom-report.non-admin', selected_player_color,reason}
    Roles.print_to_roles_higher('Trainee',{'expcom-report.admin', selected_player_color,by_player_name_color,reason})
    Reports.report_player(selected_player_name,player.name,reason)
end

--- Gives the action player a warning, requires a reason
-- @element warn_player
local warn_player = new_button('utility/spawn_flag',{'player-list.warn-player'})
:on_click(function(player)
    Store.set(selected_action_store,player,'command/give-warning')
end)

local function warn_player_callback(player,reason)
    local selected_player_name, selected_player_color = get_action_player_name(player)
    local by_player_name_color = format_chat_player_name(player)
    game.print{'expcom-warnings.received', selected_player_color,by_player_name_color,reason}
    Warnings.add_warning(selected_player_name,player.name,reason)
end

--- Jails the action player, requires a reason
-- @element jail_player
local jail_player = new_button('utility/multiplayer_waiting_icon',{'player-list.jail-player'})
:on_click(function(player)
    local selected_player_name, selected_player_color = get_action_player_name(player)
    if Jail.is_jailed(selected_player_name) then
        player.print({'expcom-jail.already-jailed', selected_player_color},Colors.orange_red)
    else
        Store.set(selected_action_store,player,'command/jail')
    end
end)

local function jail_player_callback(player,reason)
    local selected_player_name, selected_player_color = get_action_player_name(player)
    local by_player_name_color = format_chat_player_name(player)
    game.print{'expcom-jail.give', selected_player_color,by_player_name_color,reason}
    Jail.jail_player(selected_player_name,player.name,reason)
end

--- Temp bans the action player, requires a reason
-- @element temp_ban_player
local temp_ban_player = new_button('utility/warning_white',{'player-list.temp-ban-player'})
:on_click(function(player)
    local selected_player_name, selected_player_color = get_action_player_name(player)
    if Jail.is_jailed(selected_player_name) then
        player.print({'expcom-jail.already-banned', selected_player_color},Colors.orange_red)
    else
        Store.set(selected_action_store,player,'command/temp-ban')
    end
end)

local function temp_ban_player_callback(player,reason)
    local selected_player, selected_player_color = get_action_player_name(player)
    local by_player_name_color = format_chat_player_name(player)
    game.print{'expcom-jail.temp-ban', selected_player_color,by_player_name_color,reason}
    Jail.temp_ban_player(selected_player,player.name,reason)
end

--- Kicks the action player, requires a reason
-- @element kick_player
local kick_player = new_button('utility/warning_icon',{'player-list.kick-player'})
:on_click(function(player)
    Store.set(selected_action_store,player,'command/kick')
end)

local function kick_player_callback(player,reason)
    local selected_player = get_action_player_name(player)
    game.kick_player(selected_player,reason)
end

--- Bans the action player, requires a reason. Player's items placed in spawn chests
-- @element ban_player
local ban_player = new_button('utility/danger_icon',{'player-list.ban-player'})
:on_click(function(player)
    Store.set(selected_action_store,player,'command/ban')
end)

local function ban_player_callback(player,reason)
    local selected_player = get_action_player_name(player)
    local inv = player.get_main_inventory()
    move_items(inv.get_contents())
    inv.clear()
    game.ban_player(selected_player,reason)
end

return {
    set_store_uids = set_store_uids,
    buttons = {
        ['command/teleport'] = {
            auth=function(player,selected_player)
                return player.name ~= selected_player.name
            end, -- cant teleport to your self
            goto_player,
            bring_player
        },
        ['command/kill'] = {
            auth=function(player,selected_player)
                if player.name == selected_player.name then
                    return true
                elseif Roles.player_allowed(player,'command/kill/always') then
                    return auth_lower_role(player,selected_player)
                end
            end, -- player must be lower role, or your self
            kill_player
        },
        ['command/report'] = {
            auth=function(player,selected_player)
                if not Roles.player_allowed(player,'command/give-warning') then
                    return not Roles.player_has_flag(selected_player,'report-immune')
                end
            end, -- can report any player that isn't immune and you aren't able to give warnings
            reason_callback=report_player_callback,
            report_player
        },
        ['command/give-warning'] = {
            auth=auth_lower_role, -- warn a lower user, replaces report
            reason_callback=warn_player_callback,
            warn_player
        },
        ['command/jail'] = {
            auth=auth_lower_role,
            reason_callback=jail_player_callback,
            jail_player
        },
        ['command/temp-ban'] = {
            auth=auth_lower_role,
            reason_callback=temp_ban_player_callback,
            temp_ban_player
        },
        ['command/kick'] = {
            auth=auth_lower_role,
            reason_callback=kick_player_callback,
            kick_player
        },
        ['command/ban'] = {
            auth=auth_lower_role,
            reason_callback=ban_player_callback,
            ban_player
        }
    }
}
