--- This file contains all the different settings for the warp system and gui
-- @config Warps

return {
    -- General config
    update_smoothing = 10, --- @setting update_smoothing the amount of smoothing applied to updates to the cooldown timer, higher is better, max is 60
    minimum_distance = 100, --- @setting minimum_distance the minimum distance that is allowed between warps on the same force
    default_icon = {type = 'item', name = 'discharge-defense-equipment'}, --- @setting default_icon the default icon that will be used for warps

    -- Warp cooldowns
    bypass_warp_cooldown = 'expcore.roles', --- @setting bypass_warp_cooldown dictates who the warp cooldown is applied to; values: all, admin, expcore.roles, none
    expcore_roles_bypass_warp_cooldown = 'gui/warp-list/bypass-cooldown', --- @setting expcore_roles_bypass_warp_cooldown if expcore.roles is used then this is the required permission
    cooldown_duration = 60, --- @setting cooldown_duration the duration of the warp cooldown in seconds

    -- Warp proximity
    bypass_warp_proximity = 'expcore.roles', --- @setting bypass_warp_proximity dictates who the warp proximity is applied to; values: all, admin, expcore.roles, none
    expcore_roles_bypass_warp_proximity = 'gui/warp-list/bypass-proximity', --- @setting expcore_roles_bypass_warp_proximity if expcore.roles is used then this is the required permission
    standard_proximity_radius = 4, --- @setting standard_proximity_radius the minimum distance a player is allowed to be to a warp in order to use it
    spawn_proximity_radius = 20, --- @setting spawn_proximity_radius the minimum distance a player is allowed to be from they spawn point to use warps

    -- Adding warps
    allow_add_warp = 'expcore.roles', --- @setting allow_add_warp dictates who is allowed to add warps; values: all, admin, expcore.roles, none
    expcore_roles_allow_add_warp = 'gui/warp-list/add', --- @setting expcore_roles_allow_add_warp if expcore.roles is used then this is the required permission

    -- Editing warps
    allow_edit_warp = 'expcore.roles', --- @setting allow_edit_warp dictates who is allowed to edit warps; values: all, admin, expcore.roles, none
    expcore_roles_allow_edit_warp = 'gui/warp-list/edit', --- @setting expcore_roles_allow_edit_warp if expcore.roles is used then this is the required permission
    user_can_edit_own_warps = false, --- @settings user_can_edit_own_warps if true then the user who made the warp can edit it regardless of the allow_edit_warp setting

    -- Warp area generation
    entities = { --- @setting entities The entities which are created for warp areas
        {'small-lamp', -4, -2}, {'small-lamp', -2, -4}, {'medium-electric-pole',-3,-3}, -- Top left corner
        {'small-lamp', 3, -2}, {'small-lamp', 1, -4}, {'medium-electric-pole',2,-3}, -- Top right corner
        {'small-lamp', 3, 1}, {'small-lamp', 1, 3}, {'medium-electric-pole',2,2}, -- Bottom right corner
        {'small-lamp', -4, 1}, {'small-lamp', -2, 3}, {'medium-electric-pole',-3,2}, -- Bottom left corner
    },
    tiles = { --- @setting tiles The tiles which are created for warp areas
        {'black-refined-concrete',-4,-2}, {'black-refined-concrete',-4,-1}, {'black-refined-concrete',-4,0}, {'black-refined-concrete',-4,1},
        {'black-refined-concrete',-3,-3}, {'purple-refined-concrete',-3,-2}, {'purple-refined-concrete',-3,-1}, {'purple-refined-concrete',-3,0},
        {'purple-refined-concrete',-3,1}, {'black-refined-concrete',-3,2}, {'black-refined-concrete',-2,-4}, {'purple-refined-concrete',-2,-3},
        {'purple-refined-concrete',-2,-2}, {'purple-refined-concrete',-2,-1}, {'purple-refined-concrete',-2,0}, {'purple-refined-concrete',-2,1},
        {'purple-refined-concrete',-2,2}, {'black-refined-concrete',-2,3}, {'black-refined-concrete',-1,-4}, {'purple-refined-concrete',-1,-3},
        {'purple-refined-concrete',-1,-2}, {'purple-refined-concrete',-1,-1}, {'purple-refined-concrete',-1,0}, {'purple-refined-concrete',-1,1},
        {'purple-refined-concrete',-1,2}, {'black-refined-concrete',-1,3}, {'black-refined-concrete',0,-4}, {'purple-refined-concrete',0,-3},
        {'purple-refined-concrete',0,-2}, {'purple-refined-concrete',0,-1}, {'purple-refined-concrete',0,0}, {'purple-refined-concrete',0,1},
        {'purple-refined-concrete',0,2}, {'black-refined-concrete',0,3}, {'black-refined-concrete',1,-4}, {'purple-refined-concrete',1,-3},
        {'purple-refined-concrete',1,-2}, {'purple-refined-concrete',1,-1}, {'purple-refined-concrete',1,0}, {'purple-refined-concrete',1,1},
        {'purple-refined-concrete',1,2}, {'black-refined-concrete',1,3}, {'black-refined-concrete',2,-3}, {'purple-refined-concrete',2,-2},
        {'purple-refined-concrete',2,-1}, {'purple-refined-concrete',2,0}, {'purple-refined-concrete',2,1}, {'black-refined-concrete',2,2},
        {'black-refined-concrete',3,-2}, {'black-refined-concrete',3,-1}, {'black-refined-concrete',3,0}, {'black-refined-concrete',3,1}
    }
}
