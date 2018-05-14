--[[
Explosive Gaming

This file can be used with permission but this and the credit below must remain in the file.
Contact a member of management on our discord to seek permission to use our code.
Any changes that you may make to the code are yours but that does not make the script yours.
Discord: https://discord.gg/r6dC2uK
]]
--Please Only Edit Below This Line-----------------------------------------------------------

local science_packs = {
    'science-pack-1',
    'science-pack-2',
    'science-pack-3',
    'military-science-pack',
    'production-science-pack',
    'high-tech-science-pack',
    'space-science-pack'
}

local function _global(reset)
    global.addons = not reset and global.addons or {}
    global.addons.science = not reset and global.addons.science or {_base={update=0,_update=0,made={0,0,0,0,0,0,0},_made={0,0,0,0,0,0,0}}}
    return global.addons.science
end

Gui.left.add{
    name='science',
    caption='item/lab',
    tooltip={'science.tooltip'},
    draw=function(frame)
        local data = _global()
        local player = Game.get_player(frame.player_index)
        if not data[player.force.name] then 
            data[player.force.name] = table.deepcopy(data._base)
        end
        data = data[player.force.name]
        frame.caption = {'science.name'}
        frame.add{
            type='label',
            caption={'science.total'},
            style='caption_label'
        }
        local totals = frame.add{
            type='flow',
            direction='vertical'
        }
        frame.add{
            type='label',
            caption={'science.time'},
            style='caption_label'
        }
        local times = frame.add{
            type='flow',
            direction='vertical'
        }
        if data.update < game.tick-100 then
            data._update = data.update
            data._made = table.deepcopy(data.made)
            for i,name in pairs(science_packs) do
                data.made[i] = player.force.item_production_statistics.get_input_count(name)
            end
            data.update = game.tick
        end
        for i,name in pairs(science_packs) do
            local made = data.made[i]
            if made > 0 then
                totals.add{
                    type='label',
                    caption={'science.format',{'science.'..name},made}
                }
                local _made = string.format('%.2f',(made-data._made[i])/((data.update-data._update)/(3600*game.speed)))
                times.add{
                    type='label',
                    caption={'science.format',{'science.'..name},_made}
                }
            end
        end
    end,
    can_open=function(player)
        if player.force.item_production_statistics.get_input_count('science-pack-1') > 0 then return true
        else return {'science.none'} end
    end
}

Event.register(defines.events.on_research_finished,function(event) Gui.left.update('science') end)
Sync.add_update('science',function()
    local _return = {}
    local _data = _global()
    for force_name,data in pairs(_data) do
        if force_name ~= '_base' then
            _return[force_name] = {totals={},times={}}
            for i,name in pairs(science_packs) do
                local made = data.made[i]
                _return[force_name].totals[name] = made
                local _made = string.format('%.2f',(made-data._made[i])/((data.update-data._update)/(3600*game.speed)))
                _return[force_name].times[name] = _made
            end
        end
    end
    return _return
end)