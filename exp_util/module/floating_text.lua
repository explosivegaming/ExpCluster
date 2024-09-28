--[[-- Util Module - FloatingText
- Provides a method of creating floating text and tags in the world
@core FloatingText
@alias FloatingText

@usage-- Show player chat message in world
local function on_console_chat(event)
    local player = game.players[event.player_index]
    FloatingText.print_as_player(player, event.message)
end

@usage-- Show player tags above their characters
local function on_player_respawned(event)
    local player = game.players[event.player_index]
    FloatingText.create_tag_as_player(player, player.tag)
end

@usage-- Show placed an entity in alt mode
local function on_built_entity(event)
    local entity = event.created_entity
    local player = game.players[event.player_index]
    FloatingText.create_tag_above_entity(entity, player.name, player.color, true)
end

]]

local FloatingText = {}
FloatingText.color = require("modules/exp_util/include/color")

--- Print Messages.
-- Short lived messages that last at most a few seconds
-- @section floating-text_print

--- Print floating text at the given position on the given surface
-- @tparam LuaSurface surface The surface where the floating text will be created
-- @tparam MapPosition position The position to create the floating text at
-- @tparam string text The text which will be printed
-- @tparam[opt=FloatingText.color.white] Color color The colour to print the text in
-- @treturn LuaEntity The floating text entity which was created for the message
function FloatingText.print(surface, position, text, color)
    return surface.create_entity{
        text = text,
        name = "tutorial-flying-text",
        color = color or FloatingText.color.white,
        position = position,
    }
end

--- Print floating text above the given entity
-- @tparam LuaEntity The entity to create the text above
-- @tparam string text The text which will be printed
-- @tparam[opt=FloatingText.color.white] Color color The colour to print the text in
-- @treturn LuaEntity The floating text entity which was created for the message
function FloatingText.print_above_entity(entity, text, color)
    local size_y = entity.bounding_box.left_top.y - entity.bounding_box.right_bottom.y
    return entity.surface.create_entity{
        text = text,
        name = "tutorial-flying-text",
        color = color or FloatingText.color.white,
        position = {
            x = entity.position.x,
            y = entity.position.y - size_y * 0.25,
        },
    }
end

--- Print floating text above the given player
-- @tparam LuaPlayer The player to create the text above
-- @tparam string text The text which will be printed
-- @tparam[opt=FloatingText.color.white] Color color The colour to print the text in
-- @treturn LuaEntity The floating text entity which was created for the message
function FloatingText.print_above_player(player, text, color)
    return player.surface.create_entity{
        text = text,
        name = "tutorial-flying-text",
        color = color or FloatingText.color.white,
        position = {
            x = player.position.x,
            y = player.position.y - 1.5,
        },
    }
end

--- Print floating text above the given player in their chat color
-- @tparam LuaPlayer The player to create the text above
-- @tparam string text The text which will be printed
-- @treturn LuaEntity The floating text entity which was created for the message
function FloatingText.print_as_player(player, text)
    return player.surface.create_entity{
        text = text,
        name = "tutorial-flying-text",
        color = player.chat_color,
        position = {
            x = player.position.x,
            y = player.position.y - 1.5,
        },
    }
end

--- Tag Messages.
-- Long lived messages that last until their are removed
-- @section floating-text_tags

--- Create floating text at the given position on the given surface
-- @tparam LuaSurface surface The surface where the floating text will be created
-- @tparam MapPosition position The position to create the floating text at
-- @tparam string text The text which will be printed
-- @tparam[opt=FloatingText.color.white] Color color The colour to print the text in
-- @tparam[opt=false] boolean alt_mode When true, the text will only appear when a player is in alt mode
-- @treturn LuaEntity The floating text entity which was created for the message
function FloatingText.create_tag(surface, position, text, color, alt_mode)
    return rendering.draw_text{
        text = text,
        surface = surface,
        color = color or FloatingText.color.white,
        only_in_alt_mode = alt_mode,
        target = position,
    }
end

--- Create floating text above the given entity
-- @tparam LuaEntity The entity to create the text above
-- @tparam string text The text which will be printed
-- @tparam[opt=FloatingText.color.white] Color color The colour to print the text in
-- @tparam[opt=false] boolean alt_mode When true, the text will only appear when a player is in alt mode
-- @treturn LuaEntity The floating text entity which was created for the message
function FloatingText.create_tag_above_entity(entity, text, color, alt_mode)
    return rendering.draw_text{
        text = text,
        surface = entity.surface,
        color = color or FloatingText.color.white,
        only_in_alt_mode = alt_mode,
        target = entity,
        target_offset = {
            x = 0,
            y = (entity.bounding_box.left_top.y - entity.bounding_box.right_bottom.y) * -0.25,
        },
    }
end

--- Create floating text above the given player
-- @tparam LuaPlayer The player to create the text above
-- @tparam string text The text which will be printed
-- @tparam[opt=FloatingText.color.white] Color color The colour to print the text in
-- @tparam[opt=false] boolean alt_mode When true, the text will only appear when a player is in alt mode
-- @treturn LuaEntity The floating text entity which was created for the message
function FloatingText.create_tag_above_player(player, text, color, alt_mode)
    return rendering.draw_text{
        text = text,
        surface = player.surface,
        color = color or FloatingText.color.white,
        only_in_alt_mode = alt_mode,
        target = player.character,
        target_offset = {
            x = 0,
            y = -1.5,
        },
    }
end

--- Create floating text above the given player in their character color
-- @tparam LuaPlayer The player to create the text above
-- @tparam string text The text which will be printed
-- @tparam[opt=false] boolean alt_mode When true, the text will only appear when a player is in alt mode
-- @treturn LuaEntity The floating text entity which was created for the message
function FloatingText.create_tag_as_player(player, text, alt_mode)
    return rendering.draw_text{
        text = text,
        surface = player.surface,
        color = player.color,
        only_in_alt_mode = alt_mode,
        target = player.character,
        target_offset = {
            x = 0,
            y = -1.5,
        },
    }
end

return FloatingText
