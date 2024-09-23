--[[-- Control Module - Warnings
    - Adds a way to give and remove warnings to players.
    @control Warnings
    @alias Warnings

    @usage
    -- import the module from the control modules
    local Warnings = require 'modules.control.warnings' --- @dep modules.control.warnings

    -- This will add a warning to the player
    Warnings.add_warning('MrBiter', 'Cooldude2606', 'Killed too many biters')

    -- This will remove a warning from a player, second name is just who is doing the action
    Warnings.remove_warning('MrBiter', 'Cooldude2606')

    -- Script warning as similar to normal warning but are designed to have no effect for a short amount of time
    -- this is so it can be used for greifer protection without being too agressive
    Warnings.add_script_warning('MrBiter', 'Killed too many biters')

    -- Both normal and script warnings can also be cleared, this will remove all warnings
    Warnings.clear_warnings('MrBiter', 'Cooldude2606')
]]

local Event = require 'utils.event' --- @dep utils.event
local Game = require 'utils.game' --- @dep utils.game
local Global = require 'utils.global' --- @dep utils.global
local config = require 'config.warnings' --- @dep config.warnings

local valid_player = Game.get_player_from_any

--- Stores the quickbar filters for a player
local PlayerData = require 'expcore.player_data' --- @dep expcore.player_data
local PlayerWarnings = PlayerData.Required:combine('Warnings')
PlayerWarnings:set_metadata{
    stringify = function(value)
        if not value then return 'You have no warnings' end
        local count = 0
        for _ in pairs(value) do count = count + 1 end
        return 'You have '..count..' warnings'
    end
}

local Warnings = {
    user_warnings=PlayerWarnings,
    user_script_warnings={},
    events = {
        --- When a warning is added to a player
        -- @event on_warning_added
        -- @tparam number player_index the index of the player who recived the warning
        -- @tparam string by_player_name the name of the player who gave the warning
        -- @tparam string reason the reason that the player was given a warning
        -- @tparam number warning_count the new number of warnings that the player has
        on_warning_added = script.generate_event_name(),
        --- When a warning is removed from a player
        -- @event on_warning_removed
        -- @tparam number player_index the index of the player who is having the warning removed
        -- @tparam string warning_by_name the name of the player who gave the warning
        -- @tparam string removed_by_name the name of the player who is removing the warning
        -- @tparam number warning_count the new number of warnings that the player has
        -- @tparam number batch_count the number of warnings removed in this batch, always one when not a batch
        -- @tparam number batch the index of this event in a batch, always one when not a batch
        on_warning_removed = script.generate_event_name(),
        --- When a warning is added to a player, by the script
        -- @event on_script_warning_added
        -- @tparam number player_index the index of the player who recived the warning
        -- @tparam string reason the reason that the player was given a warning
        -- @tparam number warning_count the new number of warnings that the player has
        on_script_warning_added = script.generate_event_name(),
        --- When a warning is removed from a player, by the script
        -- @event on_script_warning_removed
        -- @tparam number player_index the index of the player who is having the warning removed
        -- @tparam number warning_count the new number of warnings that the player has
        on_script_warning_removed = script.generate_event_name(),
    }
}

local user_script_warnings = Warnings.user_script_warnings
Global.register(user_script_warnings, function(tbl)
    Warnings.user_script_warnings = tbl
    user_script_warnings = tbl
end)

--- Gets an array of warnings that the player has, always returns a list even if empty
-- @tparam LuaPlayer player the player to get the warning for
-- @treturn table an array of all the warnings on this player, contains tick, by_player_name and reason
function Warnings.get_warnings(player)
    return PlayerWarnings:get(player.name, {})
end

--- Gets the number of warnings that a player has on them
-- @tparam LuaPlayer player the player to count the warnings for
-- @treturn number the number of warnings that the player has
function Warnings.count_warnings(player)
    local warnings = PlayerWarnings:get(player.name, {})
    return #warnings
end

--- Adds a warning to a player, when a warning is added a set action is done based on the number of warnings and the config file
-- @tparam LuaPlayer player the player to add a warning to
-- @tparam string by_player_name the name of the player who is doing the action
-- @tparam[opt='Non given.'] string reason the reason that the player is being warned
-- @treturn number the number of warnings that the player has
function Warnings.add_warning(player, by_player_name, reason)
    player = valid_player(player)
    if not player then return end
    if not by_player_name then return end

    reason = reason or 'None given.'

    local warning_count
    PlayerWarnings:update(player.name, function(_, warnings)
        local warning = {
            by_player_name = by_player_name,
            reason = reason
        }

        if not warnings then
            warning_count = 1
            return {warning}
        else
            table.insert(warnings, warning)
            warning_count = #warnings
        end
    end)

    script.raise_event(Warnings.events.on_warning_added, {
        name = Warnings.events.on_warning_added,
        tick = game.tick,
        player_index = player.index,
        warning_count = warning_count,
        by_player_name = by_player_name,
        reason = reason
    })

    local action = config.actions[warning_count]
    if action then
        local _type = type(action)
        if _type == 'function' then
            action(player, by_player_name, warning_count)
        elseif _type == 'table' then
            local current = table.deepcopy(action)
            table.insert(current, 2,by_player_name)
            table.insert(current, 3,warning_count)
            player.print(current)
        elseif type(action) == 'string' then
            player.print(action)
        end
    end

    return warning_count
end

--- Event trigger for removing a waring due to it being looped in clear warnings
-- @tparam LuaPlayer player the player who is having a warning removed
-- @tparam string warning_by_name the name of the player who made the warning
-- @tparam string removed_by_name the name of the player who is doing the action
-- @tparam number warning_count the number of warnings that the player how has
-- @tparam number batch the index of this event in a batch, always one when not a batch
-- @tparam number batch_count the number of reports removed in this batch, always one when not a batch
local function warning_removed_event(player, warning_by_name, removed_by_name, warning_count, batch, batch_count)
    script.raise_event(Warnings.events.on_warning_removed, {
        name = Warnings.events.on_warning_removed,
        tick = game.tick,
        player_index = player.index,
        warning_count = warning_count,
        warning_by_name = warning_by_name,
        removed_by_name = removed_by_name,
        batch_count = batch_count or 1,
        batch = batch or 1
    })
end

--- Removes a warning from a player, always removes the earliest warning, fifo
-- @tparam LuaPlayer player the player to remove a warning from
-- @tparam string by_player_name the name of the player who is doing the action
-- @treturn number the number of warnings that the player has
function Warnings.remove_warning(player, by_player_name)
    player = valid_player(player)
    if not player then return end
    if not by_player_name then return end

    local warning, warning_count
    PlayerWarnings:update(player.name, function(_, warnings)
        if not warnings then return end
        warning = table.remove(warnings, 1)
        warning_count = #warnings
    end)

    if not warning then return end
    warning_removed_event(player, warning.by_player_name, by_player_name, warning_count)

    return warning_count
end

--- Removes all warnings from a player, will trigger remove event for each warning
-- @tparam LuaPlayer player the player to clear the warnings from
-- @tparam string by_player_name the name of the player who is doing the action
-- @treturn boolean true when warnings were cleared succesfully
function Warnings.clear_warnings(player, by_player_name)
    player = valid_player(player)
    if not player then return end
    if not by_player_name then return end

    local warnings = PlayerWarnings:get(player)
    if not warnings then return end

    local warning_count = #warnings
    for n, warning in pairs(warnings) do
        warning_removed_event(player, warning.by_player_name, by_player_name, warning_count-n, n, warning_count)
    end

    PlayerWarnings:remove(player)
    return true
end

--- Gets an array of all the script warnings that a player has
-- @tparam LuaPlayer player the player to get the script warnings of
-- @treturn table a table of all the script warnings a player has, contains tick and reason
function Warnings.get_script_warnings(player)
    return user_script_warnings[player.name] or {}
end

--- Gets the number of script warnings that a player has on them
-- @tparam LuaPlayer player the player to count the script warnings of
-- @treturn number the number of script warnings that the player has
function Warnings.count_script_warnings(player)
    local warnings = user_script_warnings[player.name] or {}
    return #warnings
end

--- Adds a script warning to a player, this may add a full warning if max script warnings is met
-- @tparam LuaPlayer player the player to add a script warning to
-- @tparam[opt='Non given.'] string reason the reason that the player is being warned
-- @treturn number the number of script warnings that the player has
function Warnings.add_script_warning(player, reason)
    player = valid_player(player)
    if not player then return end

    reason = reason or 'Non given.'

    local warnings = user_script_warnings[player.name]
    if not warnings then
        warnings = {}
        user_script_warnings[player.name] = warnings
    end

    table.insert(warnings, {
        tick = game.tick,
        reason = reason
    })

    local warning_count = #warnings

    script.raise_event(Warnings.events.on_script_warning_added, {
        name = Warnings.events.on_script_warning_added,
        tick = game.tick,
        player_index = player.index,
        warning_count = warning_count,
        reason = reason
    })

    if warning_count > config.script_warning_limit then
        Warnings.add_warning(player, '<server>', reason)
    end

    return warning_count
end

--- Script warning removed event trigger due to it being looped in clear script warnings
-- @tparam LuaPlayer player the player who is having a script warning removed
-- @tparam number warning_count the number of warnings that the player has
local function script_warning_removed_event(player, warning_count)
    script.raise_event(Warnings.events.on_script_warning_removed, {
        name = Warnings.events.on_script_warning_removed,
        tick = game.tick,
        player_index = player.index,
        warning_count = warning_count
    })
end

--- Removes a script warning from a player
-- @tparam LuaPlayer player the player to remove a script warning from
-- @treturn number the number of script warnings that the player has
function Warnings.remove_script_warning(player)
    player = valid_player(player)
    if not player then return end

    local warnings = user_script_warnings[player.name]
    if not warnings then return end

    table.remove(warnings, 1)

    script_warning_removed_event(player)

    return #warnings
end

--- Removes all script warnings from a player, emits event for each warning removed
-- @tparam LuaPlayer player the player to clear the script warnings from
function Warnings.clear_script_warnings(player)
    player = valid_player(player)
    if not player then return end

    local warnings = user_script_warnings[player.name]
    if not warnings then return end

    local warning_count = #warnings
    for n, _ in pairs(warnings) do
        script_warning_removed_event(player, warning_count-n)
    end

    user_script_warnings[player.name] = nil
    return true
end

-- script warnings are removed after a certain amount of time to make them even more lienient
local script_warning_cool_down = config.script_warning_cool_down*3600
Event.on_nth_tick(script_warning_cool_down/4, function()
    local cutoff = game.tick - script_warning_cool_down
    for player_name, script_warnings in pairs(user_script_warnings) do
        if #script_warnings > 0 then
            for _, warning in pairs(script_warnings) do
                if warning.tick < cutoff then
                    Warnings.remove_script_warning(player_name)
                end
            end
        end
    end
end)

return Warnings