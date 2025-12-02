--- Config file for the compliatrons including where they spawn and what messages they show
-- @config Compilatron

return {
    message_cycle = 60 * 15, --- @setting message_cycle 15 seconds default, how often (in ticks) the messages will cycle
    locations = {
        ["Spawn"] = {
            spawn_position = { x = 0, y = 0 },
            spawn_surface = "nauvis",
            entity_name = "small-biter",
            messages = {
                { "info.website" },
                { "info.read-readme" },
                { "info.discord" },
                { "info.softmod" },
                { "info.redmew" },
                { "info.custom-commands" },
                { "info.status" },
                { "info.lhd" },
                { "info.github" },
                { "info.patreon" },
            },
        }
    },
}
