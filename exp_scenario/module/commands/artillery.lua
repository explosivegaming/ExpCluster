--[[-- Commands - Artillery
Adds a command that helps shoot artillery
]]

local AABB = require("modules/exp_util/aabb")
local Commands = require("modules/exp_commands")
local Selection = require("modules.exp_legacy.modules.control.selection") --- @dep modules.control.selection
local SelectionName = "ExpCommand_Artillery"

local floor = math.floor
local abs = math.abs

--- @class ExpCommand_Artillery.commands
local commands = {}

--- @param player LuaPlayer
--- @param area BoundingBox
--- @return boolean
local function location_break(player, area)
    local surface = player.surface -- Allow remote view
    local is_charted = player.force.is_chunk_charted
    if is_charted(surface, { x = floor(area.left_top.x / 32), y = floor(area.left_top.y / 32) }) then
        return true
    elseif is_charted(surface, { x = floor(area.left_top.x / 32), y = floor(area.right_bottom.y / 32) }) then
        return true
    elseif is_charted(surface, { x = floor(area.right_bottom.x / 32), y = floor(area.left_top.y / 32) }) then
        return true
    elseif is_charted(surface, { x = floor(area.right_bottom.x / 32), y = floor(area.right_bottom.y / 32) }) then
        return true
    else
        return false
    end
end

--- Toggle player selection mode for artillery
--- @class ExpCommand_Artillery.commands.artillery: ExpCommand
--- @overload fun(player: LuaPlayer)
commands.artillery = Commands.new("artillery", { "exp-commands_artillery.description" })
    :register(function(player)
        if Selection.is_selecting(player, SelectionName) then
            Selection.stop(player)
            return Commands.status.success{ "exp-commands_artillery.exit" }
        else
            Selection.start(player, SelectionName)
            return Commands.status.success{ "exp-commands_artillery.enter" }
        end
    end) --[[ @as any ]]

--- when an area is selected to add protection to the area
Selection.on_selection(SelectionName, function(event)
    --- @cast event EventData.on_player_selected_area
    local area = AABB.expand(event.area)
    local player = game.players[event.player_index]
    local surface = event.surface

    if not (player.cheat_mode or location_break(player, event.area)) then
        player.print{ "exp-commands_artillery.invalid_area" }
        return
    end

    local entities = surface.find_entities_filtered{
        area = area,
        type = { "unit-spawner", "turret" },
        force = "enemy"
    }

    local count = 0
    local hits = {} --- @type MapPosition[]
    for _, entity in ipairs(entities) do
        local skip = false

        for _, pos in ipairs(hits) do
            local x = abs(entity.position.x - pos.x)
            local y = abs(entity.position.y - pos.y)
            if x * x + y * y < 36 then
                skip = true
                break
            end
        end

        if not skip then
            surface.create_entity{
                name = "artillery-flare",
                position = entity.position,
                force = player.force,
                life_time = 240,
                movement = { 0, 0 },
                height = 0,
                vertical_speed = 0,
                frame_speed = 0
            }

            count = count + 1
            hits[count] = entity.position

            if count > 400 then
                break
            end
        end
    end
end)

return {
    commands = commands,
}
