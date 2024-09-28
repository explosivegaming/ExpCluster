--- Config file for the warning system, this is very similar to reports but is for the use of moderators rather than normal users.
-- @config Warnings

return {
    actions = { --- @setting actions what actions are taking at number of warnings
        -- if a localized string is used then __1__ will by_player_name and __2__ will be the current warning count (auto inserted)
        { "warnings.received", "" },
        { "warnings.received", "" },
        { "warnings.received", { "warnings.pre-kick" } },
        function(player, by_player_name, number_of_warnings)
            local str = {
                "You received a warning from ",
                by_player_name,
                ". You have ",
                number_of_warnings,
                " warnings. You were kicked for having too many warnings; you may rejoin if you wish.",
            }
            game.kick_player(player, table.concat(str, "")) -- Does not support locale strings
            -- game.kick_player(player, { "warnings.received", by_player_name, number_of_warnings, { "warnings.kick" } })
        end,
        { "warnings.received", { "warnings.pre-pre-ban" } },
        { "warnings.received", { "warnings.pre-ban" } },
        function(player, by_player_name, number_of_warnings)
            local str = {
                "You received a warning from ",
                by_player_name,
                ". You have ",
                number_of_warnings,
                " warnings. You were banned for having too many warnings; visit https://www.explosivegaming.nl to request a ban appeal.",
            }
            game.kick_player(player, table.concat(str, "")) -- Does not support locale strings
            -- game.ban_player(player, { "warnings.received", by_player_name, number_of_warnings, { "warnings.ban", { "links.website" } } })
        end,
    },
    script_warning_cool_down = 30, --- @setting script_warning_cool_down time for a script warning (given by script) to be removed (in minutes)
    script_warning_limit = 5, --- @setting script_warning_limit the number of script warnings (given by script) that are allowed before full warnings are given
}
