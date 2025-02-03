--[[-- ExpUtil - FlyingText
Provides a method of creating floating text and tags in the world
]]

--- @class ExpUtil_FlyingText
local FlyingText = {}

FlyingText.color = require("modules/exp_util/include/color")

--- @class FlyingText.create_param:LuaPlayer.create_local_flying_text_param
--- @field player? LuaPlayer The player to create the text for
--- @field surface? LuaSurface The surface to create the text for
--- @field force? LuaForce The force to create the text for

--- Create flying text for a player, force, or surface; default is all online players
--- @param options FlyingText.create_param
function FlyingText.create(options)
    if options.player then
        options.player.create_local_flying_text(options)
    elseif options.force then
        for _, player in pairs(options.force.connected_players) do
            player.create_local_flying_text(options)
        end
    elseif options.surface then
        for _, player in pairs(game.connected_players) do
            if player.surface == options.surface then
                player.create_local_flying_text(options)
            end
        end
    else
        for _, player in pairs(game.connected_players) do
            player.create_local_flying_text(options)
        end
    end
end

--- @class FlyingText.create_above_entity_param:FlyingText.create_param
--- @field target_entity? LuaEntity The entity to create the text above
--- @field offset? { x: number, y: number } Offset to move the text by

--- Create flying above an entity, overrides the position option of FlyingText.create
--- @param options FlyingText.create_above_entity_param
function FlyingText.create_above_entity(options)
    local entity = assert(options.target_entity, "A target entity is required")
    local size_y = entity.bounding_box.left_top.y - entity.bounding_box.right_bottom.y
    local offset = options.offset or { x = 0, y = 0 }

    options.position = {
        x = offset.x + entity.position.x,
        y = offset.y + entity.position.y + size_y * 0.25,
    }

    FlyingText.create(options)
end

--- @class FlyingText.create_above_player_param:FlyingText.create_param
--- @field target_player? LuaPlayer The player to create the text above
--- @field offset? { x: number, y: number } Offset to move the text by

--- Create flying above a player, overrides the position option of FlyingText.create
--- @param options FlyingText.create_above_player_param
function FlyingText.create_above_player(options)
    local player = assert(options.target_player, "A target player is required")
    local entity = player.character; if not entity then return end
    local size_y = entity.bounding_box.left_top.y - entity.bounding_box.right_bottom.y
    local offset = options.offset or { x = 0, y = 0 }

    options.position = {
        x = offset.x + entity.position.x,
        y = offset.y + entity.position.y + size_y * 0.25,
    }

    FlyingText.create(options)
end

--- @class FlyingText.create_as_player_param:FlyingText.create_param
--- @field target_player? LuaPlayer The player to create the text above
--- @field offset? { x: number, y: number } Offset to move the text by

--- Create flying above a player, overrides the position and color option of FlyingText.create
--- @param options FlyingText.create_as_player_param
function FlyingText.create_as_player(options)
    local player = assert(options.target_player, "A target player is required")
    local entity = player.character; if not entity then return end
    local size_y = entity.bounding_box.left_top.y - entity.bounding_box.right_bottom.y
    local offset = options.offset or { x = 0, y = 0 }

    options.color = player.chat_color
    options.position = {
        x = offset.x + entity.position.x,
        y = offset.y + entity.position.y + size_y * 0.25,
    }

    FlyingText.create(options)
end

return FlyingText
