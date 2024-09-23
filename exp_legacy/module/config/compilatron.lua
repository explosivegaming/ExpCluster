--- Config file for the compliatrons including where they spawn and what messages they show
-- @config Compilatron

return {
    message_cycle=60*15, --- @setting message_cycle 15 seconds default, how often (in ticks) the messages will cycle
    locations={ --- @setting locations defines the spawn locations for all compilatrons
        ['Spawn']={x=0,y=0}
    },
    messages={ --- @setting messages the messages that each one will say, must be same name as its location
        ['Spawn']={
            {'info.website'},
            {'info.read-readme'},
            {'info.discord'},
            {'info.softmod'},
            {'info.redmew'},
            {'info.custom-commands'},
            {'info.status'},
            {'info.lhd'},
            {'info.github'},
            {'info.patreon'},
        }
    }
}