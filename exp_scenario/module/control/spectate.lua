--[[-- Control - Spectate
Lets players spectate without losing their character, and follow other players or entities
]]

local Storage = require("modules/exp_util/storage")
local Gui = require("modules/exp_gui")

--- @class ExpScenario_Spectate
local Spectate = {
    --- @package
    events = {},
}

--- @class ExpScenario_Spectate.Following
--- @field player LuaPlayer
--- @field target LuaPlayer | LuaEntity
--- @field position MapPosition Where the player was after the last update, moving away stops following
--- @field started_spectate boolean True when start_follow put the player into spectator mode
--- @field stop boolean? Set when following must end on the next tick

local following = {} --- @type table<uint, ExpScenario_Spectate.Following> Keyed by player index
local spectating = {} --- @type table<uint, LuaEntity> The character a player returns to, keyed by player index

Storage.register({
    following = following,
    spectating = spectating,
}, function(tbl)
    following = tbl.following
    spectating = tbl.spectating
end)

--- Label shown while following, clicking it or pressing escape stops following
--- @class ExpScenario_Spectate.follow_label: ExpElement
--- @overload fun(parent: LuaGuiElement, target: LuaPlayer | LuaEntity): LuaGuiElement
local follow_label = Gui.define("spectate/follow_label")
    :draw(function(_, parent, target)
        Gui.destroy_if_valid(parent.follow_label)

        local label = parent.add{
            type = "label",
            name = "follow_label",
            style = "frame_title",
            caption = { "exp_spectate.follow-label", target.name },
        }

        local player = Gui.get_player(parent)
        local res = player.display_resolution
        label.location = { 0, res.height - 150 }
        label.style.width = res.width
        label.style.horizontal_align = "center"
        player.opened = label

        return label
    end)
    :on_click(function(_, player)
        Spectate.stop_follow(player)
    end)
    :on_closed(function(_, player)
        -- set_controller can not be called during on_gui_closed, so the next update stops following
        local data = following[player.index]
        if data then data.stop = true end
    end) --[[@as any]]

--- Check if a player is in spectator mode
--- @param player LuaPlayer
--- @return boolean
function Spectate.is_spectating(player)
    return player.controller_type == defines.controllers.spectator
end

--- Put a player into spectator mode while keeping their character
--- @param player LuaPlayer
--- @return boolean # False when the player was already spectating or has no character
function Spectate.start_spectate(player)
    if spectating[player.index] or not player.character then return false end
    local character = player.character
    local opened = player.opened

    player.set_controller{ type = defines.controllers.spectator }
    player.associate_character(character)
    spectating[player.index] = character

    if opened then player.opened = opened end -- Changing controller closes the opened gui

    return true
end

--- Return a player to their character, or respawn them if it was killed
--- @param player LuaPlayer
function Spectate.stop_spectate(player)
    local character = spectating[player.index]
    spectating[player.index] = nil

    if character and character.valid then
        local opened = player.opened
        player.teleport(character.position, character.surface)
        player.set_controller{ type = defines.controllers.character, character = character }
        if opened then player.opened = opened end -- Changing controller closes the opened gui
    else
        player.ticks_to_respawn = 300
    end
end

--- Check if a player is following something
--- @param player LuaPlayer
--- @return boolean
function Spectate.is_following(player)
    return following[player.index] ~= nil
end

--- Put a player into spectator mode and keep their camera on a target as it moves
--- @param player LuaPlayer
--- @param target LuaPlayer | LuaEntity
function Spectate.start_follow(player, target)
    local started_spectate = Spectate.start_spectate(player)

    follow_label(player.gui.screen, target)
    player.teleport(target.position, target.surface)
    following[player.index] = {
        player = player,
        target = target,
        position = player.position,
        started_spectate = started_spectate,
    }
end

--- Give a player their camera back, returning them to their character if start_follow took it
--- @param player LuaPlayer
function Spectate.stop_follow(player)
    local data = following[player.index]
    if data and data.started_spectate and Spectate.is_spectating(player) then
        Spectate.stop_spectate(player)
    end

    Gui.destroy_if_valid(player.gui.screen.follow_label)
    following[player.index] = nil
end

--- Move a following player onto their target, or stop following when they have moved away or regained a character
--- @param data ExpScenario_Spectate.Following
local function update_following(data)
    local player, target = data.player, data.target
    local position = player.position
    if
        data.stop
        or player.character
        or not target.valid
        or position.x ~= data.position.x
        or position.y ~= data.position.y
    then
        Spectate.stop_follow(player)
    else
        player.teleport(target.position, target.surface)
        data.position = player.position
    end
end

local function on_tick()
    for _, data in pairs(following) do
        update_following(data)
    end
end

--- Stop following when a player leaves, and stop anyone who was following them
--- @param event EventData.on_pre_player_left_game
local function on_pre_player_left_game(event)
    local player = game.players[event.player_index]
    Spectate.stop_follow(player)
    for _, data in pairs(following) do
        if data.target == player then
            Spectate.stop_follow(data.player)
        end
    end
end

local e = defines.events

Spectate.events[e.on_tick] = on_tick
Spectate.events[e.on_pre_player_left_game] = on_pre_player_left_game

return Spectate
