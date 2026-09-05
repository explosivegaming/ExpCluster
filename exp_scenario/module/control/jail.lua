--[[-- Control - Jail
Adds a way to jail players, the jail role suppresses all of their other roles
]]

local Roles = require("modules/exp_roles")

--- @class ExpScenario_Jail
local Jail = {
    --- Raised when a player is put into jail
    --- @type EventData.ExpScenario_Jail.on_player_jailed
    on_player_jailed = script.generate_event_name(),
    --- Raised when a player is taken out of jail
    --- @type EventData.ExpScenario_Jail.on_player_unjailed
    on_player_unjailed = script.generate_event_name(),
}

--- @class EventData.ExpScenario_Jail.on_player_jailed : EventData
--- @field player_index uint
--- @field by_player_name string
--- @field reason string

--- @class EventData.ExpScenario_Jail.on_player_unjailed : EventData
--- @field player_index uint
--- @field by_player_name string

--- The role given to jailed players, it has a higher priority than every other role
--- @return ExpRoles.Role
local function get_jail_role()
    return (assert(Roles.get_role_by_name("Jail"), "The Jail role does not exist"))
end

--- Check if a player is in jail
--- @param player LuaPlayer
--- @return boolean
function Jail.is_jailed(player)
    return get_jail_role():has_player(player)
end

--- Put a player into jail, which suppresses all of their other roles
--- @param player LuaPlayer
--- @param by_player_name string
--- @param reason string
--- @return boolean # False when the player was already in jail
function Jail.jail_player(player, by_player_name, reason)
    local role = get_jail_role()
    if role:has_player(player) then return false end

    -- Stop whatever the player is doing, the jail permission group stops them from starting again
    player.walking_state = { walking = false, direction = player.walking_state.direction }
    player.riding_state = { acceleration = defines.riding.acceleration.nothing, direction = player.riding_state.direction }
    player.mining_state = { mining = false }
    player.shooting_state = { state = defines.shooting.not_shooting, position = player.shooting_state.position }
    player.picking_state = false
    player.repair_state = { repairing = false, position = player.repair_state.position }

    role:assign(player, { by_player_name = by_player_name, silent = true })

    script.raise_event(Jail.on_player_jailed, {
        player_index = player.index,
        by_player_name = by_player_name,
        reason = reason,
    })

    return true
end

--- Take a player out of jail, which restores all of their other roles
--- @param player LuaPlayer
--- @param by_player_name string
--- @return boolean # False when the player was not in jail
function Jail.unjail_player(player, by_player_name)
    local role = get_jail_role()
    if not role:has_player(player) then return false end

    role:unassign(player, { by_player_name = by_player_name, silent = true })

    script.raise_event(Jail.on_player_unjailed, {
        player_index = player.index,
        by_player_name = by_player_name,
    })

    return true
end

return Jail
