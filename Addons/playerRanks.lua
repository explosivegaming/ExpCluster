--[[
Explosive Gaming

This file can be used with permission but this and the credit below must remain in the file.
Contact a member of management on our discord to seek permission to use our code.
Any changes that you may make to the code are yours but that does not make the script yours.
Discord: https://discord.gg/r6dC2uK
]]
--Please Only Edit Below This Line-----------------------------------------------------------

--[[
    How to use groups:
name		The name that you can use to reference it.
disallow	If present then all ranks in this group will have this added to their disallow.
allow		If present then all ranks in this group will have this added to their allow.
highest     Assigned by the script to show the highest rank in this group.
lowest      Assigned by the script to show the lowest rank in this group.
How to add ranks:
Name		What will be used in the scripts and is often the best choice for display in text.
short_hand	What can be used when short on space but the rank still need to be displayed.
tag			The tag the player will gain when moved to the rank, it can be nil.
time		Used for auto-rank feature where you are moved to the rank after a certain play time in minutes.
colour		The RGB value that can be used to emphasise GUI elements based on rank.
power		Assigned by the script based on their index in ranks, you can insert new ranks between current ones.
group		Assigned by the script to show the group this rank is in.
disallow	A list containing input actions that the user can not perform.
allow		A list of custom commands and effects that that rank can use, all defined in the scripts.

For allow, add the allow as the key and the value as true
Example: test for 'server-interface' => allow['server-interface'] = true

For disallow, add to the list the end part of the input action
Example: defines.input_action.drop_item -> 'drop_item'
http://lua-api.factorio.com/latest/defines.html#defines.input_action
--]]

-- See ExpCore/ranks.lua for examples - you add your own and edit pre-made ones here.

local groups = Ranking._groups(true)

groups['Root']:edit('allow',false,{
    ['testing']=true
})

groups['Root']:add_rank{
    name='Owner',
    short_hand='Owner',
    tag='[Owner]',
    time=nil,
    colour={r=170,g=0,b=0},
    is_admin = true,
    is_spectator=true,
    base_afk_time=false
}
groups['Root']:add_rank{
    name='Community Manager',
    short_hand='Com Mngr',
    tag='[Com Mngr]',
    colour={r=150,g=68,b=161},
    is_admin = true,
    is_spectator=true,
    base_afk_time=false
}
groups['Root']:add_rank{
    name='Developer',
    short_hand='Dev',
    tag='[Dev]',
    colour={r=179,g=125,b=46},
    is_admin = true,
    is_spectator=true,
    base_afk_time=false
}

groups['Admin']:add_rank{
    name='Mod',
    short_hand='Mod',
    tag='[Mod]',
    colour={r=0,g=170,b=0},
    disallow={
        'server_command'
    },
    is_admin = true,
    is_spectator=true,
    base_afk_time=false
}

groups['User']:add_rank{
    name='Donator',
    short_hand='P2W',
    tag='[P2W]',
    colour={r=233,g=63,b=233},
    power=0,
    is_spectator=true,
    base_afk_time=120
}
groups['User']:add_rank{
    name='Veteran',
    short_hand='Vet',
    tag='[Veteran]',
    time=600,
    colour={r=140,g=120,b=200},
    power=1,
    base_afk_time=60
}
groups['User']:add_rank{
    name='Regular',
    short_hand='Reg',
    tag='[Regular]',
    time=180,
    colour={r=24,g=172,b=188},
    power=3,
    base_afk_time=30
}

local ranks = Ranking._ranks(true)

ranks['Root']:edit('test',true,'testing')

Ranking._base_preset{
    ['badgamernl']='Owner',
    ['arty714']='Community Manager',
    ['cooldude2606']='Developer',
    ['mark9064']='Admin'
}