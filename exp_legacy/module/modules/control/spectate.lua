local Storage = require("modules/exp_util/storage")
local Gui = require("modules/exp_gui")

local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event

----- Locals -----
local follow_label -- Gui constructor
local following = {}
local spectating = {}
local Public = {}

----- Storage data -----
Storage.register({
    following = following,
    spectating = spectating,
}, function(tbl)
    following = tbl.following
    spectating = tbl.spectating
end)

----- Public Functions -----

--- Test if a player is in spectator mode
-- @tparam LuaPlayer player The player to test the controller type of
-- @treturn boolean Returns true if the player is in spectator mode
function Public.is_spectating(player)
    assert(player and player.valid, "Invalid player given to follower")
    return player.controller_type == defines.controllers.spectator
end

--- Puts a player into spectator mode while maintaining an association to their character
-- @tparam LuaPlayer player The player that will be placed into spectator mode
-- @treturn boolean Returns false if the player was already in spectator mode
function Public.start_spectate(player)
    assert(player and player.valid, "Invalid player given to follower")
    if spectating[player.index] or not player.character then return false end
    local character = player.character
    local opened = player.opened
    player.set_controller{ type = defines.controllers.spectator }
    player.associate_character(character)
    spectating[player.index] = character
    if opened then player.opened = opened end -- Maintain opened after controller change
    return true
end

--- Return a player from spectator mode back to their character, if their character was killed then respawn them
-- @tparam LuaPlayer player The player that will leave spectator mode
function Public.stop_spectate(player)
    assert(player and player.valid, "Invalid player given to follower")
    local character = spectating[player.index]
    spectating[player.index] = nil
    if character and character.valid then
        local opened = player.opened
        player.teleport(character.position, character.surface)
        player.set_controller{ type = defines.controllers.character, character = character }
        if opened then player.opened = opened end -- Maintain opened after controller change
    else
        player.ticks_to_respawn = 300
    end
end

--- Test if a player is in follow mode
-- @tparam LuaPlayer player The player to test the follow mode of
-- @treturn boolean Returns true if the player is in follow mode
function Public.is_following(player)
    assert(player and player.valid, "Invalid player given to follower")
    return following[player.index] ~= nil
end

--- Puts a player into spectator mode and follows an entity as it moves
-- @tparam LuaPlayer player The player that will follow the entity
-- @tparam ?LuaPlayer|LuaEntity entity The player or entity that will be followed
function Public.start_follow(player, entity)
    assert(player and player.valid, "Invalid player given to follower")
    assert(entity and entity.valid, "Invalid entity given to follower")
    local spectate = Public.start_spectate(player)

    player.close_map()
    follow_label(player.gui.screen, entity)
    player.teleport(entity.position, entity.surface)
    following[player.index] = { player, entity, entity.position, spectate }
end

--- Returns camera control to the player, will return a player to their character if start_follow placed them into spectator mode
-- @tparam LuaPlayer player The player that will regain control of their camera
function Public.stop_follow(player)
    assert(player and player.valid, "Invalid player given to follower")
    if following[player.index] and following[player.index][4] and Public.is_spectating(player) then
        Public.stop_spectate(player)
    end

    Gui.destroy_if_valid(player.gui.screen.follow_label)
    following[player.index] = nil
end

--- Returns camera control to all players, will return a player to their character if start_follow placed them into spectator mode
function Public.stop_all()
    for key, data in pairs(following) do
        Public.stop_follow(data[1])
    end
end

----- Gui -----

--- Label used to show that the player is following, also used to allow esc to stop following
follow_label = Gui.define("follow-label")
    :draw(function(def, parent, target)
        Gui.destroy_if_valid(parent.follow_label)

        local label = parent.add{
            type = "label",
            name = "follow_label",
            style = "frame_title",
            caption = "Following " .. target.name .. ".\nClick here or press esc to stop following.",
        }

        local player = Gui.get_player(parent)
        local res = player.display_resolution
        label.location = { 0, res.height - 150 }
        label.style.width = res.width
        label.style.horizontal_align = "center"
        player.opened = label

        return label
    end)
    :on_click(function(def, player, element)
        Public.stop_follow(player)
    end)
    :on_closed(function(def, player, element)
        -- Don't call set_controller during on_close as it invalidates the controller
        -- Setting an invalid position (as to not equal their current) will call stop_follow on the next tick
        following[player.index][3] = {}
    end)

----- Events -----

--- Updates the location of the player as well as doing some sanity checks
-- @tparam LuaPlayer player The player to update the position of
-- @tparam ?LuaPlayer|LuaEntity entity The player or entity being followed
local function update_player_location(player, entity, old_position)
    if player.character or not entity.valid then
        Public.stop_follow(player)
    elseif player.position.x ~= old_position.x or player.position.y ~= old_position.y then
        Public.stop_follow(player)
    else
        player.teleport(entity.position, entity.surface)
    end
end

--- Updates the locations of all players currently following something
local function update_all()
    for _, data in pairs(following) do
        update_player_location(data[1], data[2], data[3])
        data[3] = data[1].position
    end
end

-- Update the location of all players each tick
Event.add(defines.events.on_tick, update_all)

-- Check for player leaving
Event.add(defines.events.on_pre_player_left_game, function(event)
    local player = game.players[event.player_index]
    Public.stop_follow(player)
    for _, data in pairs(following) do
        if data[2] == player then
            Public.stop_follow(data[1])
        end
    end
end)

----- Module Return -----
return Public
