--[[-- Control - Help Bubbles
Adds friendly biters that walk around and give helpful messages
]]

local Async = require("modules/exp_util/async")
local Storage = require("modules/exp_util/storage")
local config = require("modules.exp_legacy.config.compilatron")

--- @type table<string, Async.AsyncReturn>
local persistent_locations = {}
Storage.register(persistent_locations, function(tbl)
    persistent_locations = tbl
end)

--- @class speech_bubble_task_param
--- @field entity LuaEntity
--- @field messages LocalisedString[]
--- @field previous_message LuaEntity?
--- @field current_message_index number

--- Used by create_entity within speech_bubble_async
local speech_bubble_param = {
    name = "compi-speech-bubble",
    position = { 0, 0 },
}

--- Cycle between a set category of messages above an entity
local speech_bubble_task =
    Async.register(function(task)
        --- @cast task speech_bubble_task_param
        local entity = task.entity
        if not entity.valid then
            return Async.status.complete()
        end

        local index = task.current_message_index
        if index > #task.messages then
            index = 1
        end

        local previous_message = task.previous_message
        if previous_message and previous_message.valid then
            previous_message.destroy()
        end

        speech_bubble_param.source = entity
        speech_bubble_param.text = task.messages[index]
        task.previous_message = entity.surface.create_entity(speech_bubble_param)

        task.current_message_index = index + 1
        return Async.status.delay(config.message_cycle, task)
    end)

--- Register an entity to start spawning speech bubbles
--- @param entity LuaEntity the entity which will have messages spawn from it
--- @param messages LocalisedString[] the messages which should be shown
--- @param starting_index number? the message index to start at, default 1
--- @return Async.AsyncReturn
local function register_entity(entity, messages, starting_index)
    return speech_bubble_task{
        entity = entity,
        messages = messages,
        current_message_index = starting_index or 1,
    }
end

--- Check all persistent locations from the config are active
local function check_persistent_locations()
    for name, location in pairs(config.locations) do
        local task = persistent_locations[name]
        if task and not task.completed then
            goto continue
        end

        local surface = game.get_surface(location.spawn_surface)
        if not surface then
            goto continue
        end

        local position = surface.find_non_colliding_position(location.entity_name, location.spawn_position, 1.5, 0.5)
        if not position then
            goto continue
        end

        local entity = surface.create_entity{ name = location.entity_name, position = position, force = game.forces.neutral }
        if not entity then
            goto continue
        end

        persistent_locations[name] = register_entity(entity, location.messages)
        ::continue::
    end
end

return {
    on_nth_tick = {
        [config.message_cycle] = check_persistent_locations,
    },
    register_entity = register_entity,
}
