--[[-- Commands Module - Bonus
    - Adds a command that allows players to have increased stats
    @data Bonus
]]

local Roles = require("modules.exp_legacy.expcore.roles") --- @dep expcore.roles
local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event
local config = require("modules.exp_legacy.config.bonus") --- @dep config.bonuses
local Commands = require("modules/exp_commands")

-- Stores the bonus for the player
local PlayerData = require("modules.exp_legacy.expcore.player_data") --- @dep expcore.player_data
local PlayerBonus = PlayerData.Settings:combine("Bonus")
PlayerBonus:set_default(0)
PlayerBonus:set_metadata{
    permission = "command/bonus",
    stringify = function(value)
        if not value or value == 0 then
            return "None set"
        end

        return value
    end,
}

--- Apply a bonus to a player
local function apply_bonus(player, stage)
    if not player.character then
        return
    end

    for k, v in pairs(config.player_bonus) do
        player[k] = v.value * stage / 10

        if v.combined_bonus then
            for i = 1, #v.combined_bonus, 1 do
                player[v.combined_bonus[i]] = v.value * stage / 10
            end
        end
    end
end

--- When store is updated apply new bonus to the player
PlayerBonus:on_update(function(player_name, player_bonus)
    apply_bonus(game.players[player_name], player_bonus or 0)
end)

--- Changes the amount of bonus you receive
Commands.new("bonus", { "bonus.description" })
    :optional("amount", { "bonus.arg-amount" }, Commands.types.integer_range(0, 10))
    :register(function(player, amount)
        --- @cast amount number?
        if amount then
            PlayerBonus:set(player, amount)
            return Commands.status.success{ "bonus.set", amount }
        else
            return Commands.status.success{ "bonus.get", PlayerBonus:get(player) }
        end
    end)

--- When a player respawns re-apply bonus
Event.add(defines.events.on_player_respawned, function(event)
    local player = game.players[event.player_index]
    apply_bonus(player, PlayerBonus:get(player))
end)

--- Remove bonus if a player no longer has access to the command
local function role_update(event)
    local player = game.players[event.player_index]
    if not Roles.player_allowed(player, "command/bonus") then
        apply_bonus(player, 0)
    end
end

--- When a player dies allow them to have instant respawn
Event.add(defines.events.on_player_died, function(event)
    local player = game.players[event.player_index]

    if Roles.player_has_flag(player, "instant-respawn") then
        player.ticks_to_respawn = 120
    end
end)

Event.add(defines.events.on_player_created, function(event)
    if event.player_index ~= 1 then
        return
    end

    for k, v in pairs(config.force_bonus) do
        game.players[event.player_index].force[k] = v.value
    end

    for k, v in pairs(config.surface_bonus) do
        game.players[event.player_index].surface[k] = v.value
    end
end)

Event.add(Roles.events.on_role_assigned, role_update)
Event.add(Roles.events.on_role_unassigned, role_update)
