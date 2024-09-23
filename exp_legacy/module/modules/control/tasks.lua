--[[-- Control Module - Tasks
- Stores tasks for each force.
@control Tasks
@alias Tasks

@usage-- Making and then editing a new task
local task_id = Tasks.add_task(game.player.force.name, nil, game.player.name)

Tasks.update_task(task_id, 'We need more iron!', game.player.name)

]]

local Datastore = require 'expcore.datastore' --- @dep expcore.datastore
local Global = require 'utils.global' --- @dep utils.global

--- Stores all data for the warp gui
local TaskData = Datastore.connect('TaskData')
TaskData:set_serializer(function(raw_key) return raw_key.task_id end)

local Tasks = {}

-- Global lookup table for force name to task ids
local force_tasks = {_uid=1}
Global.register(force_tasks, function(tbl)
    force_tasks = tbl
end)

--- Setters.
-- functions used to created and alter tasks
-- @section setters

--[[-- Add a new task for a force, the task can be placed into a certain position for that force
@tparam string force_name the name of the force to add the task for
@tparam[opt] string player_name the player who added this task, will cause them to be listed under editing
@tparam[opt] string task_title the task title, if not given default is used
@tparam[opt] string task_body the task body, if not given default is used
@treturn string the uid of the task which was created

@usage-- Adding a new task for your force
local task_id = Tasks.add_task(game.player.force.name, game.player.name, nil, nil)

]]
function Tasks.add_task(force_name, player_name, task_title, task_body)
    -- Get a new task id
    local task_id = tostring(force_tasks._uid)
    force_tasks._uid = force_tasks._uid + 1

    -- Get the existing tasks for this force
    local task_ids = force_tasks[force_name]
    if not task_ids then
        task_ids = {}
        force_tasks[force_name] = task_ids
    end

    -- Insert the task id into the forces tasks
    table.insert(task_ids, task_id)

    -- Add the new task to the store
    TaskData:set(task_id, {
        task_id = task_id,
        force_name = force_name,
        title = task_title or '',
        body = task_body or '',
        last_edit_name = player_name or '<server>',
        last_edit_time = game.tick,
        currently_editing = {}
    })

    return task_id
end

--[[-- Removes a task and any data that is linked with it
@tparam string task_id the uid of the task which you want to remove

@usage-- Removing a task
Tasks.remove_task(task_id)

]]
function Tasks.remove_task(task_id)
    local task = TaskData:get(task_id)
    local force_name = task.force_name
    table.remove_element(force_tasks[force_name], task_id)
    TaskData:remove(task_id)
end

--[[-- Update the message and last edited information for a task
@tparam string task_id the uid of the task to update
@tparam string player_name the name of the player who made the edit
@tparam string task_title the title of the task to update to
@tparam string task_body the body of the task to update to

@usage-- Updating the message for on a task
Task.update_task(task_id, game.player.name, 'We need more iron!', 'Build more iron outposts.')

]]
function Tasks.update_task(task_id, player_name, task_title, task_body)
    TaskData:update(task_id, function(_, task)
        task.last_edit_name = player_name
        task.last_edit_time = game.tick
        task.title = task_title
        task.body = task_body
    end)
end

--[[-- Set the editing state for a player, can be used as a warning or to display a text field
@tparam string task_id the uid of the task that you want to effect
@tparam string player_name the name of the player you want to set the state for
@tparam boolean state the new state to set editing to

@usage-- Setting your editing state to true
Tasks.set_editing(task_id, game.player.name, true)

]]
function Tasks.set_editing(task_id, player_name, state)
    TaskData:update(task_id, function(_, task)
        task.currently_editing[player_name] = state
    end)
end

--[[-- Adds an update handler for when a task is added, removed, or updated
@tparam function handler the handler which is called when a task is updated

@usage-- Add a game print when a task is updated
Tasks.on_update(function(task)
    game.print(task.force_name..' now has the task: '..task.message)
end)

]]
function Tasks.on_update(handler)
    TaskData:on_update(handler)
end

--- Getters.
-- function used to get information about tasks
-- @section getters

--[[-- Gets the task information that is linked with this id
@tparam string task_id the uid of the task you want to get
@treturn table the task information

@usage-- Getting task information outside of on_update
local task = Tasks.get_task(task_id)

]]
function Tasks.get_task(task_id)
    return TaskData:get(task_id)
end

--[[-- Gets all the task ids that a force has
@tparam string force_name the name of the force that you want the task ids for
@treturn table an array of all the task ids

@usage-- Getting the task ids for a force
local task_ids = Tasks.get_force_task_ids(game.player.force.name)

]]
function Tasks.get_force_task_ids(force_name)
    return force_tasks[force_name] or {}
end

--[[-- Gets the editing state for a player
@tparam string task_id the uid of the task you want to check
@tparam string player_name the name of the player that you want to check
@treturn boolean weather the player is currently editing this task

@usage-- Check if a player is editing a task or not
local editing = Tasks.get_editing(task_id, game.player.name)

]]
function Tasks.get_editing(task_id, player_name)
    local task = TaskData:get(task_id)
    return task.currently_editing[player_name]
end

-- Module Return
return Tasks
