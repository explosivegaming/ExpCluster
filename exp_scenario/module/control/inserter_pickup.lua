--[[-- Control Insert Pickup
Automatically pick up the items in the inserts hand when you mine it
]]

local controllers_with_inventory = {
    [defines.controllers.character] = true,
    [defines.controllers.god] = true,
    [defines.controllers.editor] = true,
}

--- @param event EventData.on_player_mined_entity
local function on_player_mined_entity(event)
    local entity = event.entity
    if not entity.valid or entity.type ~= "inserter" or entity.drop_target then
        return
    end

    local item_entity = entity.surface.find_entity("item-on-ground", entity.drop_position)

    if item_entity then
        local player = assert(game.get_player(event.player_index))
        if controllers_with_inventory[player.controller_type] then
            player.mine_entity(item_entity)
        end
    end
end

local e = defines.events

return {
    events = {
        [e.on_player_mined_entity] = on_player_mined_entity
    }
}
