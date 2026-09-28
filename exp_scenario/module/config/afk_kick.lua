--- Settings for kicking players when everyone online is afk
-- @config AFK-Kick

local Features = require("modules/exp_scenario/features")
local Roles = require("modules/exp_roles")

return Features.config("afk_kick", {
    admin_as_active = true, --- @setting admin_as_active When true admins will be treated as active regardless of afk time
    trust_as_active = true, --- @setting trust_as_active When true trusted players (by playtime) will be treated as active regardless of afk time
    afk_minutes = 10, --- @setting afk_minutes The time in minutes that must pass for a player to be considered afk
    kick_minutes = 30, --- @setting kick_minutes The time in minutes that must pass without any active players for all players to be kicked
    trust_minutes = 600, --- @setting trust_minutes The time in minutes that a player must be online for to count as trusted
    update_seconds = 1800, --- @setting update_seconds How often in seconds the script checks for active players
    custom_active_check = function(player)
        local veteran = Roles.get_role_by_name("Veteran")
        return veteran ~= nil and not Roles.get_player_highest_role(player):is_lower_than(veteran)
    end,
})
