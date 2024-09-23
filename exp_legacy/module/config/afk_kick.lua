return {
    admin_as_active = true, --- @setting admin_as_active When true admins will be treated as active regardless of afk time
    trust_as_active = true, --- @setting trust_as_active When true trusted players (by playtime) will be treated as active regardless of afk time
    active_role = 'Veteran', --- @setting active_role When not nil a player with this role will be treated as active regardless of afk time
    afk_time = 3600*10, --- @setting afk_time The time in ticks that must pass for a player to be considered afk
    kick_time = 3600*30, --- @setting kick_time The time in ticks that must pass without any active players for all players to be kicked
    trust_time = 3600*60*10, --- @setting trust_time The time in ticks that a player must be online for to count as trusted
    update_time = 3600*30, --- @setting update_time How often in ticks the script checks for active players
}