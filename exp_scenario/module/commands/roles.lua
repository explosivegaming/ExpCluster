--[[-- Commands - Roles
Adds a commands that allow interaction with the role system
]]

local Commands = require("modules/exp_commands")
local format_player_name = Commands.format_player_name_locale
local format_text = Commands.format_rich_text_color_locale

local Roles = require("modules.exp_legacy.expcore.roles") --- @dep expcore.roles
local get_roles_ordered = Roles.get_roles_ordered
local get_player_roles = Roles.get_player_roles

--- Assigns a role to a player
Commands.new("assign-role", { "exp-commands_roles.description-assign" })
    :argument("player", { "exp-commands_roles.arg-player-assign" }, Commands.types.lower_role_player)
    :argument("role", { "exp-commands_roles.arg-role-assign" }, Commands.types.lower_role)
    :add_aliases{ "assign" }
    :add_flags{ "admin_only" }
    :register(function(player, other_player, role)
        --- @cast other_player LuaPlayer
        --- @cast role any -- TODO
        Roles.assign_player(other_player, role, player.name)
    end)

--- Unassigns a role to a player
Commands.new("unassign-role", { "exp-commands_roles.description-unassign" })
    :argument("player", { "exp-commands_roles.arg-player-unassign" }, Commands.types.lower_role_player)
    :argument("role", { "exp-commands_roles.arg-role-unassign" }, Commands.types.lower_role)
    :add_aliases{ "unassign" }
    :add_flags{ "admin_only" }
    :register(function(player, other_player, role)
        --- @cast other_player LuaPlayer
        --- @cast role any -- TODO
        Roles.unassign_player(other_player, role, player.name)
    end)

--- Lists all roles in they correct order
Commands.new("get-roles", { "exp-commands_roles.description-get" })
    :optional("player", { "exp-commands_roles.arg-player-get" }, Commands.types.player)
    :add_aliases{ "roles" }
    :register(function(player, other_player)
        --- @cast other_player LuaPlayer?
        local roles = get_roles_ordered()
        local roles_formatted = { "" } --- @type LocalisedString
        local response = { "exp-commands_roles.list-roles", roles_formatted }
        if other_player then
            roles = get_player_roles(other_player)
            response[1] = "exp-commands_roles.list-player"
            response[3] = format_player_name(other_player)
        end

        for index, role in ipairs(roles) do
            local role_name = format_text(role.name, role.custom_color or Commands.color.white)
            roles_formatted[index + 1] = { "exp-commands_roles.list-element", role_name }
        end

        local last = #roles_formatted
        --- @diagnostic disable-next-line nil-check
        roles_formatted[last] = roles_formatted[last][2]

        return Commands.status.success(response)
    end)
