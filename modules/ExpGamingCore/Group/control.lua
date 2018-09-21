--- Adds a system to manage and auto-create permission groups.
-- @module ExpGamingCore@Group
-- @author Cooldude2606
-- @license Discord: Cooldude2606@5241
-- @alais Group 

-- Module Require
local Game = require('FactorioStdLib.Game')

-- Module Define
local module_verbose = false

--- Used as an interface for factorio permissions groups
-- @type Group
-- @field _prototype the prototype of this class
-- @field groups a table of all groups, includes auto complete on the indexing
local Group = {
    _prototype = {},
    groups = setmetatable({},{
        __index=table.autokey,
        __newindex=function(tbl,key,value)
            rawset(tbl,key,Group.define(obj))
        end
    }),
    on_init = function()
        if loaded_modules['ExpGamingCore.Server@^4.0.0'] then require('ExpGamingCore.Server@^4.0.0').add_module_to_interface('Group','ExpGamingCore.Group') end
    end,
    on_post = function(self)
        -- loads the groups in config
        require(module_path..'/config',{Group=self})
    end
}

-- Function Define

--- Defines a new instance of a group
-- @usage Group.define{name='foo',disallow={'edit_permission_group','delete_permission_group','add_permission_group'}} -- returns new group
-- @usage Group{name='foo',disallow={'edit_permission_group','delete_permission_group','add_permission_group'}} -- returns new group
-- @tparam table obj contains string name and table disallow of defines.input_action
-- @treturn Group the group which has been made
function Group.define(obj)
    if not type_error(game,nil,'Cant define Group during runtime.') then return end
    if not type_error(obj.name,'string','Group creation is invalid: group.name is not a string') then return end
    if not type_error(obj.disallow,'table','Group creation is invalid: group.disallow is not a table') then return end
    verbose('Created Group: '..obj.name)
    setmetatable(obj,{__index=function(tbl,key) return Group._prototype[key] or rawget(tbl,'_raw_group') and rawget(tbl,'_raw_group')[key] or nil end})
    rawset(Group.groups,obj.name,obj)
    return obj
end

--- Used to get the group of a player or the group by name
-- @usage Group.get('foo') -- returns group foo
-- @usage Group.get(player) -- returns group of player
-- @tparam ?LuaPlayer|pointerToPlayer|string mixed can either be the name or raw group of a group or a player indenifier
-- @treturn table the group which was found or nil
function Group.get(mixed)
    local player = Game.get_player(mixed)
    if player then mixed = player.permission_group.name end
    if is_type(mixed,'table') and mixed.__self and mixed.name then mixed = mixed.name end
    return Group.groups[mixed] or game.permissions.get_group(mixed) and setmetatable({disallow={},name=mixed,_raw_group=game.permissions.get_group(mixed)},{
        __index=function(tbl,key) return Group._prototype[key] or rawget(tbl,'_raw_group') and rawget(tbl,'_raw_group')[key] or nil end
    })
end

--- Used to place a player into a group
-- @usage Group.assign(player,group)
-- @tparam ?LuaPlayer|pointerToPlayer player the player to assign the group to
-- @tparam ?string|LuaPermissionGroup the group to add the player to
-- @treturn boolean was the player assigned
function Group.assign(player,group)
    local player = Game.get_player(player)
    if not player then error('Invalid player given to Group.assign.',2) end
    local group = Group.get(group)
    if not group then error('Invalid group given to Group.assign.',2) end
    return group:add_player(player)
end

--- Used to get the factorio permission group linked to this group
-- @usage group:get_raw() -- returns LuaPermissionGroup of this group
-- @treturn LuaPermissionGroup the factorio group linked to this group
function Group._prototype:get_raw()
    if not self_test(self,'group','get_raw') then return end
    if not self._raw_group or self._raw_group.valid == false then error('No permissions group found, please to not remove groups with /permissions',2) return end
    return setmetatable({},{__index=self._raw_group})
end

--- Used to add a player to this group
-- @usage group:add_player(player) -- returns true if added
-- @tparam ?LuaPlayer|pointerToPlayer player the player to add to the group
-- @treturn boolean if the player was added
function Group._prototype:add_player(player)
    if not self_test(self,'group','add_player') then return end
    local player = Game.get_player(player)
    if not player then error('Invalid player given to group.add_player.',2) end
    local raw_group = self:get_raw()
    return raw_group.add_player(player)
end

--- Used to remove a player from this group
-- @usage group:remove_player(player) -- returns true if removed
-- @tparam ?LuaPlayer|pointerToPlayer player the player to remove from the group
-- @treturn boolean if the player was removed
function Group._prototype:remove_player(player)
    if not self_test(self,'group','remove_player') then return end
    local player = Game.get_player(player)
    if not player then error('Invalid player given to group.remove_player.',2) end
    local raw_group = self:get_raw()
    return raw_group.remove_player(player)
end

--- Gets all players in this group
-- @usage group:get_players(true) -- returns all online players
-- @tparam[opt=false] boolean online if true returns only online players
-- @treturn table table of players
function Group._prototype:get_players(online)
    if not self_test(self,'group','get_players') then return end
    local raw_group = self:get_raw()
    local rtn = {}
    if online then for _,player in pairs(raw_group.players) do if player.connected then table.insert(rtn,player) end end end
    return online and rtn or raw_group.players
end

--- Prints a message or value to all online players in this group
-- @usage group.print('Hello, World!')
-- @param rtn any value you wish to print, string not required
-- @param colour the colour to print the message in
-- @treturn number the number of players who recived the message
function Group._prototype:print(rtn,colour)
    if not self_test(self,'group','print') then return end
    local players = self:get_players()
    local ctn = 0
    for _,player in pairs(players) do if player.connected then player_return(rtn,colour,player) ctn=ctn+1 end end
    return ctn
end

-- Event Handlers Define

-- creates all permission groups and links them
script.on_event('on_init',function(event)
    for name,group in pairs(Group.groups) do
		group._raw_group = game.permissions.create_group(name)
		for _,to_remove in pairs(group.disallow) do
			group._raw_group.set_allows_action(defines.input_action[to_remove],false)
		end
    end
end)

-- Module Return
return setmetatable(Group,{__call=function(tbl,...) tbl.define(...) end})