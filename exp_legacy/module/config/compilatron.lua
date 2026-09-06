--- Config file for the compliatrons including where they spawn and what messages they show
-- @config Compilatron
local config_server_detail = require("modules.exp_legacy.config.server_detail") --- @dep config.server_detail

return {
    message_cycle = 60 * 15, --- @setting message_cycle 15 seconds default, how often (in ticks) the messages will cycle
    locations = {
        ["Spawn"] = {
            spawn_position = { x = 0, y = 0 },
            spawn_surface = "nauvis",
            entity_name = "small-biter",
            messages = {
                { "info.website", config_server_detail["website"] },
                { "info.read-readme" },
                { "info.discord", config_server_detail["discord"] },
                { "info.softmod" },
                { "info.redmew" },
                { "info.custom-commands" },
                { "info.status", config_server_detail["status"] },
                { "info.lhd" },
                { "info.github", config_server_detail["github"] },
                { "info.patreon", config_server_detail["patreon"] },
            },
        }
    },
}
