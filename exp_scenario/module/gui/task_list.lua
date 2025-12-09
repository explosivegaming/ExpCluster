--[[-- Gui - Task List
Adds a task list to the game which players can add, remove and edit items on
]]

local Gui = require("modules/exp_gui")
local Roles = require("modules.exp_legacy.expcore.roles")
local config = require("modules.exp_legacy.config.gui.tasks")

local ExpUtil = require("modules/exp_util")
local format_time = ExpUtil.format_time_factory_locale{ format = "short", hours = true, minutes = true }

--- @class ExpGui_TaskList.elements
local Elements = {}

local Styles = {
    sprite22 = Gui.styles.sprite{
        size = 22
    },
    footer_button = Gui.styles.sprite{
        height = 29,
        maximal_width = 268,
        horizontally_stretchable = true,
    },
}

--- @class ExpGui_TaskList.Task
--- @field id number
--- @field last_user LuaPlayer
--- @field last_edit_tick number
--- @field editing table<number, string>
--- @field title string
--- @field body string
--- @field new boolean?
--- @field deleted boolean?

--- Check if a player can create a new task
--- @param player LuaPlayer
--- @return boolean
local function has_permission_create_task(player)
    local allow_add_task = config.allow_add_task

    if allow_add_task == "all" then
        return true
    elseif allow_add_task == "admin" then
        return player.admin
    elseif allow_add_task == "expcore.roles" then
        return Roles.player_allowed(player, config.expcore_roles_allow_add_task)
    end

    return false
end

--- Check if a player can edit an existing task
--- @param player LuaPlayer
--- @param task ExpGui_TaskList.Task
--- @return boolean
local function has_permission_edit_task(player, task)
    local allow_edit_task = config.allow_edit_task

    -- Check if editing your own task allows bypassing other permissions
    if config.user_can_edit_own_tasks and task.last_user.index == player.index then
        return true
    end

    -- Check player has permission based on value in the config
    if allow_edit_task == "all" then
        return true
    elseif allow_edit_task == "admin" then
        return player.admin
    elseif allow_edit_task == "expcore.roles" then
        return Roles.player_allowed(player, config.expcore_roles_allow_edit_task)
    end

    return false
end

--- @class ExpGui_TaskList.element.new_task_button.elements
--- @field container LuaGuiElement

--- Button displayed in the header bar, used to add a new task
--- @class ExpGui_TaskList.element.new_task_button: ExpElement
--- @field data table<LuaGuiElement, ExpGui_TaskList.element.new_task_button.elements>
--- @overload fun(parent: LuaGuiElement, container: LuaGuiElement): LuaGuiElement
Elements.new_task_button = Gui.define("task_list/new_task_button")
    :track_all_elements()
    :draw{
        type = "sprite-button",
        sprite = "utility/add",
        tooltip = { "exp-gui_task-list.tooltip-new" },
        style = "tool_button",
    }
    :style(Styles.sprite22)
    :element_data{
        container = Gui.from_argument(1)
    }
    :on_click(function(def, player, new_task_button)
        --- @cast def ExpGui_TaskList.element.new_task_button
        local container = def.data[new_task_button].container
        Elements.container.open_edit_task(container, {
            id = Elements.container.next_task_id(),
            last_edit_tick = game.tick,
            last_user = player,
            editing = {},
            title = "",
            body = "",
            new = true,
        })
    end) --[[ @as any ]]

--- Refresh the visibility based on player permissions
--- @param new_task_button LuaGuiElement
function Elements.new_task_button.refresh(new_task_button)
    local player = Gui.get_player(new_task_button)
    new_task_button.visible = has_permission_create_task(player)
end

--- Refresh the visibility based on player permissions
--- @param player LuaPlayer
function Elements.new_task_button.refresh_player(player)
    local visible = has_permission_create_task(player)
    for _, new_task_button in Elements.new_task_button:tracked_elements(player) do
        new_task_button.visible = visible
    end
end

--- @class ExpGui_TaskList.elements.view_task_button.elements
--- @field task ExpGui_TaskList.Task
--- @field container LuaGuiElement

--- Button used to view a task details, the caption is the task title
--- @class ExpGui_TaskList.element.view_task_button: ExpElement
--- @field data table<LuaGuiElement, ExpGui_TaskList.elements.view_task_button.elements>
--- @overload fun(parent: LuaGuiElement, task: ExpGui_TaskList.Task, container: LuaGuiElement): LuaGuiElement
Elements.view_task_button = Gui.define("task_list/view_task_button")
    :draw(function(def, parent, task)
        --- @cast def ExpGui_TaskList.element.view_task_button
        --- @cast task ExpGui_TaskList.Task
        return parent.add{
            type = "button",
            style = "list_box_item",
            caption = task.title,
            tooltip = { "exp-gui_task-list.tooltip-last-edit", task.last_user.name, format_time(task.last_edit_tick) },
        }
    end)
    :style{
        width = 268,
        horizontally_stretchable = true,
    }
    :element_data{
        task = Gui.from_argument(1),
        container = Gui.from_argument(2),
    }
    :on_click(function(def, player, view_task_button)
        --- @cast def ExpGui_TaskList.element.view_task_button
        local elements = def.data[view_task_button]
        Elements.container.open_view_task(elements.container, elements.task)
    end) --[[ @as any ]]

--- Refresh the title and tooltip of the view task button
--- @param view_task_button LuaGuiElement
--- @param task ExpGui_TaskList.Task
function Elements.view_task_button.refresh(view_task_button, task)
    view_task_button.caption = task.title
    view_task_button.tooltip = { "exp-gui_task-list.tooltip-last-edit", task.last_user.name, format_time(task.last_edit_tick) }
end

--- Label used to signal that no tasks are open
--- @class ExpGui_TaskList.elements.no_tasks_header: ExpElement
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.no_tasks_header = Gui.define("task_list/no_tasks_header")
    :track_all_elements()
    :draw(function(def, parent, ...)
        local subheader = Gui.elements.subframe_base(parent, "negative_subheader_frame")

        local label = subheader.add{
            type = "label",
            style = "bold_label",
            caption = { "exp-gui_task-list.caption-no-tasks" },
            tooltip = { "exp-gui_task-list.tooltip-no-tasks" },
        }

        label.style.width = 268
        label.style.horizontal_align = "center"

        return subheader
    end)
    :style{
        padding = { 2, 0 },
        bottom_margin = 0,
    } --[[ @as any ]]

--- Refresh the visibility of the no tasks label
--- @param no_tasks_header LuaGuiElement
function Elements.no_tasks_header.refresh(no_tasks_header)
    local force = Gui.get_player(no_tasks_header).force --[[ @as LuaForce ]]
    no_tasks_header.visible = not Elements.container.has_tasks(force)
end

--- Refresh the visibility of the no tasks label
--- @param player LuaPlayer
function Elements.no_tasks_header.refresh_player(player)
    local visible = not Elements.container.has_tasks(player.force --[[ @as LuaForce ]])
    for _, no_tasks_header in Elements.no_tasks_header:tracked_elements(player) do
        no_tasks_header.visible = visible
    end
end

--- Refresh the visibility of the no tasks label
--- @param force LuaForce
function Elements.no_tasks_header.refresh_force_online(force)
    local visible = not Elements.container.has_tasks(force)
    for _, no_tasks_header in Elements.no_tasks_header:online_elements(force) do
        no_tasks_header.visible = visible
    end
end

--- A table containing all of the current tasks
--- @class ExpGui_TaskList.elements.task_table: ExpElement
--- @field data table<LuaGuiElement, LuaGuiElement[]>
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.task_list = Gui.define("task_list/task_list")
    :draw(function(_, parent)
        local task_list = parent.add{
            type = "scroll-pane",
            vertical_scroll_policy = "auto",
            horizontal_scroll_policy = "never",
            style = "scroll_pane_under_subheader",
        }

        local task_list_style = task_list.style
        task_list_style.horizontally_stretchable = true
        task_list_style.maximal_height = 224
        task_list_style.padding = 0

        -- Cant modify vertical spacing on scroll pane style so need a sub flow
        task_list = task_list.add{ type = "flow", direction = "vertical" }

        task_list_style = task_list.style
        task_list_style.horizontally_stretchable = true
        task_list_style.vertical_spacing = 0
        task_list_style.padding = 0

        -- Add the no tasks header
        local no_tasks_header = Elements.no_tasks_header(task_list)
        Elements.no_tasks_header.refresh(no_tasks_header)

        return task_list
    end)
    :element_data{} --[[ @as any ]]

--- Adds a task to the task list
--- @param task_list LuaGuiElement
--- @param task ExpGui_TaskList.Task
function Elements.task_list.add_task(task_list, task)
    local container = assert(task_list.parent.parent.parent)
    local view_task_buttons = Elements.task_list.data[task_list]
    view_task_buttons[task.id] = Elements.view_task_button(task_list, task, container)
end

--- Remove a task from the task list
--- @param task_list LuaGuiElement
--- @param task ExpGui_TaskList.Task
function Elements.task_list.remove_task(task_list, task)
    local view_task_buttons = Elements.task_list.data[task_list]
    Gui.destroy_if_valid(view_task_buttons[task.id])
    view_task_buttons[task.id] = nil
end

--- Refresh a task on the list
--- @param task_list LuaGuiElement
--- @param task ExpGui_TaskList.Task
function Elements.task_list.refresh_task(task_list, task)
    local view_task_buttons = Elements.task_list.data[task_list]
    Elements.view_task_button.refresh(view_task_buttons[task.id], task)
end

--- Refresh all tasks on the list
--- @param task_list LuaGuiElement
--- @param tasks ExpGui_TaskList.Task[]
function Elements.task_list.refresh_tasks(task_list, tasks)
    local view_task_buttons = Elements.task_list.data[task_list]
    local done = {}

    -- Refresh all valid tasks
    for _, task in ipairs(tasks) do
        done[task.id] = true
        local view_task_button = view_task_buttons[task.id]
        if view_task_button then
            Elements.view_task_button.refresh(view_task_button, task)
        else
            Elements.task_list.add_task(task_list, task)
        end
    end

    -- Remove tasks buttons that are no longer required
    for id, view_task_button in pairs(view_task_buttons) do
        if not done[id] then
            view_task_button.destroy()
        end
    end
end

--- Select a task button, if nil then all buttons are reset
--- @param task_list LuaGuiElement
--- @param task ExpGui_TaskList.Task?
function Elements.task_list.select_task_button(task_list, task)
    local view_task_buttons = Elements.task_list.data[task_list]
    local task_button = task and view_task_buttons[task.id]
    if task_button and not task_button.enabled then
        return
    end
    for _, view_task_button in pairs(view_task_buttons) do
        view_task_button.enabled = true
    end
    if task_button then
        task_button.enabled = false
    end
end

--- The base footer used for view and edit
--- @class ExpGui_TaskList.elements.task_footer: ExpElement
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.task_footer = Gui.define("task_list/task_footer")
    :draw{
        type = "frame",
        direction = "vertical",
        style = "subfooter_frame",
    }
    :style{
        height = 0,
        padding = 5,
        use_header_filler = false,
    } --[[ @as any ]]

--- @class ExpGui_TaskList.elements.close_task_button.elements
--- @field container LuaGuiElement

--- Button used to close an open task details
--- @class ExpGui_TaskList.element.close_task_button: ExpElement
--- @field data table<LuaGuiElement, ExpGui_TaskList.elements.close_task_button.elements>
--- @overload fun(parent: LuaGuiElement, container: LuaGuiElement): LuaGuiElement
Elements.close_task_button = Gui.define("task_list/close_task_button")
    :draw{
        type = "sprite-button",
        sprite = "utility/collapse",
        style = "frame_action_button",
        tooltip = { "exp-gui_task-list.tooltip-close" },
    }
    :style(Styles.sprite22)
    :element_data{
        container = Gui.from_argument(1),
    }
    :on_click(function(def, player, close_task_button)
        --- @cast def ExpGui_TaskList.element.close_task_button
        local elements = def.data[close_task_button]
        Elements.container.close_footers(elements.container)
    end) --[[ @as any ]]

--- @class ExpGui_TaskList.elements.task_button.elements
--- @field task ExpGui_TaskList.Task?
--- @field container LuaGuiElement

--- Button used to edit a task
--- @class ExpGui_TaskList.element.edit_task_button: ExpElement
--- @field data table<LuaGuiElement, ExpGui_TaskList.elements.task_button.elements>
--- @overload fun(parent: LuaGuiElement, container: LuaGuiElement): LuaGuiElement
Elements.edit_task_button = Gui.define("task_list/edit_task_button")
    :draw{
        type = "button",
        caption = { "exp-gui_task-list.caption-edit" },
        tooltip = { "exp-gui_task-list.tooltip-edit" },
        style = "shortcut_bar_button",
    }
    :style(Styles.footer_button)
    :element_data{
        container = Gui.from_argument(1),
    }
    :on_click(function(def, player, edit_task_button)
        --- @cast def ExpGui_TaskList.element.edit_task_button
        local elements = def.data[edit_task_button]
        Elements.container.open_edit_task(elements.container, assert(elements.task))
    end) --[[ @as any ]]

--- Refresh the edit button
--- @param edit_task_button LuaGuiElement
--- @param task ExpGui_TaskList.Task
function Elements.edit_task_button.refresh(edit_task_button, task)
    local player = Gui.get_player(edit_task_button)
    Elements.edit_task_button.data[edit_task_button].task = task
    edit_task_button.visible = has_permission_edit_task(player, task)

    if next(task.editing) then
        local player_names = table.get_values(task.editing)
        edit_task_button.tooltip = { "exp-gui_task-list.tooltip-edit", table.concat(player_names, ", ") }
    else
        edit_task_button.tooltip = { "exp-gui_task-list.tooltip-edit-none" }
    end
end

--- Button used to delete a task
--- @class ExpGui_TaskList.element.delete_task_button: ExpElement
--- @field data table<LuaGuiElement, ExpGui_TaskList.elements.task_button.elements>
--- @overload fun(parent: LuaGuiElement, container: LuaGuiElement): LuaGuiElement
Elements.delete_task_button = Gui.define("task_list/delete_task_button")
    :draw{
        type = "button",
        caption = { "exp-gui_task-list.caption-delete" },
        tooltip = { "exp-gui_task-list.tooltip-delete" },
        style = "shortcut_bar_button_red",
    }
    :style(Styles.footer_button)
    :element_data{
        container = Gui.from_argument(1),
    }
    :on_click(function(def, player, delete_task_button)
        --- @cast def ExpGui_TaskList.element.delete_task_button
        local elements = def.data[delete_task_button]
        Elements.container.remove_task(player.force --[[ @as LuaForce ]], elements.task)
        Elements.container.close_footers(elements.container)
    end) --[[ @as any ]]

--- Refresh the delete button
--- @param delete_task_button LuaGuiElement
--- @param task ExpGui_TaskList.Task
function Elements.delete_task_button.refresh(delete_task_button, task)
    local player = Gui.get_player(delete_task_button)
    Elements.delete_task_button.data[delete_task_button].task = task
    delete_task_button.visible = has_permission_edit_task(player, task)
end

--- @class ExpGui_TaskList.elements.view_task_footer.elements
--- @field task ExpGui_TaskList.Task?
--- @field body_label LuaGuiElement
--- @field title_label LuaGuiElement
--- @field delete_task_button LuaGuiElement
--- @field edit_task_button LuaGuiElement

--- The view footer used for view task details
--- @class ExpGui_TaskList.elements.view_task_footer: ExpElement
--- @field data table<LuaGuiElement, ExpGui_TaskList.elements.view_task_footer.elements>
--- @overload fun(parent: LuaGuiElement, container: LuaGuiElement): LuaGuiElement
Elements.view_task_footer = Gui.define("task_list/view_task_footer")
    :draw(function(def, parent, container)
        --- @cast def ExpGui_TaskList.elements.view_task_footer
        local view_task_footer = Elements.task_footer(parent)

        local header_flow = view_task_footer.add{ type = "flow" }
        header_flow.add{
            type = "label",
            style = "frame_title",
            caption = { "exp-gui_task-list.caption-view-footer" },
        }
        header_flow.style.right_padding = 1
        header_flow.add{ type = "empty-widget" }.style.horizontally_stretchable = true
        Elements.close_task_button(header_flow, container)

        local title_label = view_task_footer.add{ type = "label" }
        local title_label_style = title_label.style
        title_label_style.font = "default-bold"
        title_label_style.single_line = false
        title_label_style.padding = 4

        local body_label = view_task_footer.add{ type = "label" }
        body_label.style.single_line = false
        body_label.style.padding = 4

        local action_flow = view_task_footer.add{ type = "flow" }
        local delete_task_button = Elements.delete_task_button(action_flow, container)
        local edit_task_button = Elements.edit_task_button(action_flow, container)

        def.data[view_task_footer] = {
            task = nil,
            body_label = body_label,
            title_label = title_label,
            delete_task_button = delete_task_button,
            edit_task_button = edit_task_button,
        }

        return view_task_footer
    end) --[[ @as any ]]

--- Refresh the view task with new task details
--- @param view_task_footer LuaGuiElement
--- @param task ExpGui_TaskList.Task
function Elements.view_task_footer.refresh(view_task_footer, task)
    local elements = Elements.view_task_footer.data[view_task_footer]
    Elements.delete_task_button.refresh(elements.delete_task_button, task)
    Elements.edit_task_button.refresh(elements.edit_task_button, task)
    elements.title_label.caption = task.title
    elements.body_label.caption = task.body
    elements.task = task
end

--- Refresh the view task with previously selected task
--- If task is provided, then will only update if task is the selected task
--- @param view_task_footer LuaGuiElement
--- @param task ExpGui_TaskList.Task?
function Elements.view_task_footer.update(view_task_footer, task)
    local elements = Elements.view_task_footer.data[view_task_footer]
    if elements.task and (task == nil or task == elements.task) then
        Elements.view_task_footer.refresh(view_task_footer, elements.task)
    end
end

--- Refresh the view task with the previously selected task
--- @param player LuaPlayer
function Elements.view_task_footer.update_player(player)
    for _, view_task_footer in Elements.view_task_footer:tracked_elements(player) do
        Elements.view_task_footer.update(view_task_footer)
    end
end

--- @class ExpGui_TaskList.elements.task_message_textfield.elements
--- @field confirm_task_button LuaGuiElement?

--- Textfield element used in both the task create and edit footers
--- @class ExpGui_TaskList.elements.task_message_textfield: ExpElement
--- @field data table<LuaGuiElement, ExpGui_TaskList.elements.task_message_textfield.elements>
--- @overload fun(parent: LuaGuiElement, confirm_task_button: LuaGuiElement?): LuaGuiElement
Elements.task_message_textfield = Gui.define("task_list/task_message_textfield")
    :draw{
        type = "text-box",
        text = "",
    }
    :style{
        maximal_width = 268,
        minimal_height = 100,
        horizontally_stretchable = true,
    }
    :element_data{
        confirm_task_button = Gui.from_argument(1),
    }
    :on_text_changed(function(def, player, task_message_textfield)
        --- @cast def ExpGui_TaskList.elements.task_message_textfield
        local confirm_task_button = def.data[task_message_textfield].confirm_task_button
        confirm_task_button.enabled = string.len(task_message_textfield.text) > 5
    end) --[[ @as any ]]

--- Set the confirm task button to update on text changed
--- @param task_message_textfield LuaGuiElement
--- @param confirm_task_button LuaGuiElement
function Elements.task_message_textfield.set_confirm_task_button(task_message_textfield, confirm_task_button)
    Elements.task_message_textfield.data[task_message_textfield].confirm_task_button = confirm_task_button
end

--- Refresh the task message field
--- @param task_message_textfield LuaGuiElement
--- @param task ExpGui_TaskList.Task
function Elements.task_message_textfield.refresh(task_message_textfield, task)
    local elements = Elements.task_message_textfield.data[task_message_textfield]
    local message = task.new and "" or task.title .. "\n" .. task.body
    elements.confirm_task_button.enabled = string.len(message) > 5
    task_message_textfield.text = message
    task_message_textfield.focus()
end

--- @class ExpGui_TaskList.elements.confirm_task_button.elements
--- @field task ExpGui_TaskList.Task?
--- @field task_message_textfield LuaGuiElement
--- @field container LuaGuiElement

--- Textfield element used in both the task create and edit footers
--- @class ExpGui_TaskList.elements.confirm_task_button: ExpElement
--- @field data table<LuaGuiElement, ExpGui_TaskList.elements.confirm_task_button.elements>
--- @overload fun(parent: LuaGuiElement, task_message_textfield: LuaGuiElement, container: LuaGuiElement): LuaGuiElement
Elements.confirm_task_button = Gui.define("task_list/confirm_task_button")
    :draw{
        type = "button",
        name = Gui.from_name,
        caption = { "exp-gui_task-list.caption-confirm" },
        tooltip = { "exp-gui_task-list.tooltip-confirm" },
        style = "shortcut_bar_button_green",
    }
    :style(Styles.footer_button)
    :element_data{
        task_message_textfield = Gui.from_argument(1),
        container = Gui.from_argument(2),
    }
    :on_click(function(def, player, confirm_task_button)
        --- @cast def ExpGui_TaskList.elements.confirm_task_button
        local elements = def.data[confirm_task_button]
        local task_message_textfield = elements.task_message_textfield
        local task = assert(elements.task)

        local parsed = Elements.confirm_task_button.parse(task_message_textfield.text)
        task.last_edit_tick = game.tick
        task.last_user = player
        task.title = parsed.title
        task.body = parsed.body

        Elements.container.close_footers(elements.container)

        local force = player.force --[[ @as LuaForce ]]
        if task.new then
            Elements.container.add_task(force, task)
        else
            Elements.container.refresh_force_online(force, task)
        end
    end) --[[ @as any ]]

--- Refresh the confirm task button
--- @param confirm_task_button LuaGuiElement
--- @param task ExpGui_TaskList.Task
function Elements.confirm_task_button.refresh(confirm_task_button, task)
    Elements.confirm_task_button.data[confirm_task_button].task = task
end

--- Parse a task message into its two parts
--- @param message string
--- @return { title: string, body: string }
function Elements.confirm_task_button.parse(message)
    -- Trim the spaces of the string
    local trimmed = string.gsub(message, "^%s*(.-)%s*$", "%1")
    local title, body = string.match(trimmed, "(.-)\n(.*)")
    local parsed = { title = title, body = body }
    if not title then
        -- If it doesn't match the pattern return the str as a title
        parsed.title = trimmed
        parsed.body = ""
    end
    return parsed
end

--- @class ExpGui_TaskList.elements.discard_task_button.elements
--- @field task ExpGui_TaskList.Task?
--- @field container LuaGuiElement

--- Button used to close an open task details
--- @class ExpGui_TaskList.element.discard_task_button: ExpElement
--- @field data table<LuaGuiElement, ExpGui_TaskList.elements.discard_task_button.elements>
--- @overload fun(parent: LuaGuiElement, container: LuaGuiElement): LuaGuiElement
Elements.discard_task_button = Gui.define("task_list/discard_task_button")
    :draw{
        type = "button",
        caption = { "exp-gui_task-list.caption-discard" },
        tooltip = { "exp-gui_task-list.tooltip-discard" },
        style = "shortcut_bar_button_red",
    }
    :style(Styles.footer_button)
    :element_data{
        container = Gui.from_argument(1),
    }
    :on_click(function(def, player, discard_task_button)
        --- @cast def ExpGui_TaskList.element.discard_task_button
        local elements = def.data[discard_task_button]
        local task = assert(elements.task)
        if task.new then
            Elements.container.close_footers(elements.container)
        else
            Elements.container.open_view_task(elements.container, task)
        end
    end) --[[ @as any ]]

--- Refresh the discard task button
--- @param discard_task_button LuaGuiElement
--- @param task ExpGui_TaskList.Task
function Elements.discard_task_button.refresh(discard_task_button, task)
    Elements.discard_task_button.data[discard_task_button].task = task
end

--- @class ExpGui_TaskList.elements.edit_task_footer.elements
--- @field task ExpGui_TaskList.Task?
--- @field header LuaGuiElement
--- @field task_message_textfield LuaGuiElement
--- @field discard_task_button LuaGuiElement
--- @field confirm_task_button LuaGuiElement

--- The view footer used for view task details
--- @class ExpGui_TaskList.elements.edit_task_footer: ExpElement
--- @field data table<LuaGuiElement, ExpGui_TaskList.elements.edit_task_footer.elements>
--- @overload fun(parent: LuaGuiElement, container: LuaGuiElement): LuaGuiElement
Elements.edit_task_footer = Gui.define("task_list/edit_task_footer")
    :draw(function(def, parent, container)
        --- @cast def ExpGui_TaskList.elements.edit_task_footer
        local edit_task_footer = Elements.task_footer(parent)

        local header = edit_task_footer.add{
            type = "label",
            style = "frame_title",
            caption = { "exp-gui_task-list.caption-edit-footer" },
        }

        local task_message_textfield = Elements.task_message_textfield(edit_task_footer)

        local action_flow = edit_task_footer.add{ type = "flow" }
        local discard_task_button = Elements.discard_task_button(action_flow, container)
        local confirm_task_button = Elements.confirm_task_button(action_flow, task_message_textfield, container)
        Elements.task_message_textfield.set_confirm_task_button(task_message_textfield, confirm_task_button)

        def.data[edit_task_footer] = {
            task = nil,
            header = header,
            task_message_textfield = task_message_textfield,
            discard_task_button = discard_task_button,
            confirm_task_button = confirm_task_button,
        }

        return edit_task_footer
    end) --[[ @as any ]]

--- Refresh the view task with new task details
--- @param edit_task_footer LuaGuiElement
--- @param task ExpGui_TaskList.Task
function Elements.edit_task_footer.refresh(edit_task_footer, task)
    local player = Gui.get_player(edit_task_footer)
    local elements = Elements.edit_task_footer.data[edit_task_footer]
    task.editing[player.index] = player.name

    if elements.task and elements.task ~= task then
        elements.task.editing[player.index] = nil
    end

    elements.header.caption = {
        task.new and "exp-gui_task-list.caption-create-footer" or "exp-gui_task-list.caption-edit-footer"
    }

    Elements.task_message_textfield.refresh(elements.task_message_textfield, task)
    Elements.confirm_task_button.refresh(elements.confirm_task_button, task)
    Elements.discard_task_button.refresh(elements.discard_task_button, task)
    elements.task = task
end

--- Refresh the view task with previously selected task
--- If task is provided, then will only update if task is the selected task
--- @param edit_task_footer LuaGuiElement
--- @param task ExpGui_TaskList.Task?
function Elements.edit_task_footer.update(edit_task_footer, task)
    local elements = Elements.edit_task_footer.data[edit_task_footer]
    if elements.task and (task == nil or task == elements.task) then
        Elements.edit_task_footer.refresh(edit_task_footer, elements.task)
    end
end

--- Refresh the view task with the previously selected task
--- @param player LuaPlayer
function Elements.edit_task_footer.update_player(player)
    for _, edit_task_footer in Elements.edit_task_footer:tracked_elements(player) do
        Elements.edit_task_footer.update(edit_task_footer)
    end
end

--- Clear the previously edited task
--- @param edit_task_footer LuaGuiElement
function Elements.edit_task_footer.clear(edit_task_footer)
    local elements = Elements.edit_task_footer.data[edit_task_footer]
    if elements.task then
        local player = Gui.get_player(edit_task_footer)
        elements.task.editing[player.index] = nil
        elements.task = nil
    end
end

--- @class ExpGui_TaskList.elements.container.elements
--- @field task_list LuaGuiElement
--- @field view_task_footer LuaGuiElement
--- @field edit_task_footer LuaGuiElement

--- Container added to the left gui flow
--- @class ExpGui_TaskList.elements.container: ExpElement
--- @field data table<LuaForce, ExpGui_TaskList.Task[]> | table<LuaGuiElement, ExpGui_TaskList.elements.container.elements> | table<"global_data", { next_task_id: number }>
Elements.container = Gui.define("task_list/container")
    :track_all_elements()
    :draw(function(def, parent)
        --- @cast def ExpGui_TaskList.elements.container
        local container = Gui.elements.container(parent) -- width 268
        local root = Gui.elements.container.get_root_element(container)
        local elements = {}

        -- Add the header
        local header = Gui.elements.header(container, {
            caption = { "exp-gui_task-list.caption-main" },
            tooltip = { "exp-gui_task-list.tooltip-sub" },
        })

        -- Add buttons to the header
        local new_task_button = Elements.new_task_button(header, root)
        Elements.new_task_button.refresh(new_task_button)

        -- Add the task table and footers
        elements.task_list = Elements.task_list(container)

        -- Add tasks to the list if there are any
        local player = Gui.get_player(parent)
        local force = player.force --[[ @as LuaForce ]]
        local tasks = def.data[force]
        if tasks then
            for _, task in ipairs(tasks) do
                Elements.task_list.add_task(elements.task_list, task)
            end
        end

        -- Add the footers
        elements.view_task_footer = Elements.view_task_footer(container, root)
        elements.edit_task_footer = Elements.edit_task_footer(container, root)
        elements.view_task_footer.visible = false
        elements.edit_task_footer.visible = false

        -- Set the data and return
        def.data[root] = elements --[[ @as any ]]
        return root
    end)
    :global_data{ next_task_id = 1 }
    :force_data{} --[[ @as any ]]

--- Check if a force has tasks
--- @param force LuaForce
--- @return boolean
function Elements.container.has_tasks(force)
    local tasks = Elements.container.data[force]
    return tasks and #tasks > 0
end

--- Get the next task id
--- @return number
function Elements.container.next_task_id()
    local next_task_id = Elements.container.data.global_data.next_task_id 
    Elements.container.data.global_data.next_task_id = next_task_id + 1
    return next_task_id
end

--- Add a new task for a force
--- @param force LuaForce
--- @param task ExpGui_TaskList.Task
function Elements.container.add_task(force, task)
    local tasks = Elements.container.data[force]
    tasks[#tasks + 1] = task
    task.deleted = nil
    task.new = nil

    Elements.no_tasks_header.refresh_force_online(force)
    for _, container in Elements.container:online_elements(force) do
        local task_list = Elements.container.data[container].task_list
        Elements.task_list.add_task(task_list, task)
    end
end

--- Remove a task from a force
--- @param force LuaForce
--- @param task ExpGui_TaskList.Task
function Elements.container.remove_task(force, task)
    local tasks = Elements.container.data[force]
    table.remove_element(tasks, task)
    task.deleted = true

    Elements.no_tasks_header.refresh_force_online(force)
    for _, container in Elements.container:online_elements(force) do
        local task_list = Elements.container.data[container].task_list
        Elements.task_list.remove_task(task_list, task)
    end
end

--- Open the view footer
--- @param container LuaGuiElement
--- @param task ExpGui_TaskList.Task
function Elements.container.open_view_task(container, task)
    local elements = Elements.container.data[container]
    Elements.view_task_footer.refresh(elements.view_task_footer, task)
    Elements.edit_task_footer.clear(elements.edit_task_footer)
    Elements.task_list.select_task_button(elements.task_list, task)
    elements.view_task_footer.visible = true
    elements.edit_task_footer.visible = false
end

--- Open the edit footer
--- @param container LuaGuiElement
--- @param task ExpGui_TaskList.Task
function Elements.container.open_edit_task(container, task)
    local elements = Elements.container.data[container]
    Elements.edit_task_footer.refresh(elements.edit_task_footer, task)
    Elements.task_list.select_task_button(elements.task_list, task)
    elements.edit_task_footer.visible = true
    elements.view_task_footer.visible = false
end

--- Close the footers
--- @param container LuaGuiElement
function Elements.container.close_footers(container)
    local elements = Elements.container.data[container]
    Elements.edit_task_footer.clear(elements.edit_task_footer)
    Elements.task_list.select_task_button(elements.task_list)
    elements.view_task_footer.visible = false
    elements.edit_task_footer.visible = false
end

--- Refresh all tasks for a player
--- @param player LuaPlayer
function Elements.container.refresh_player(player)
    local tasks = Elements.container.data[ player.force --[[ @as LuaForce ]] ]
    for _, container in Elements.container:tracked_elements(player) do
        local elements = Elements.container.data[container]
        Elements.task_list.refresh_tasks(elements.task_list, tasks)
        Elements.view_task_footer.update(elements.view_task_footer)
        Elements.edit_task_footer.update(elements.edit_task_footer)
    end
end

--- Refresh a tasks for a force
--- @param force LuaForce
--- @param task ExpGui_TaskList.Task
function Elements.container.refresh_force_online(force, task)
    for _, container in Elements.container:online_elements(force) do
        local elements = Elements.container.data[container]
        Elements.task_list.refresh_task(elements.task_list, task)
        Elements.view_task_footer.update(elements.view_task_footer, task)
        Elements.edit_task_footer.update(elements.edit_task_footer, task)
    end
end

--- Add the element to the left flow with a toolbar button
Gui.add_left_element(Elements.container, function(player)
    return Elements.container.has_tasks(player.force --[[ @as LuaForce ]])
end)

Gui.toolbar.create_button{
    name = "toggle_task_list",
    left_element = Elements.container,
    sprite = "utility/not_enough_repair_packs_icon",
    tooltip = { "exp-gui_task-list.tooltip-main" },
    visible = function(player, element)
        return Roles.player_allowed(player, "gui/task-list")
    end
}

--- Update the gui when the player joins because it is likely to be outdated
--- @param event EventData.on_player_joined_game
local function refresh_player_tasks(event)
    local player = Gui.get_player(event)
    Elements.container.refresh_player(player)
    Elements.no_tasks_header.refresh_player(player)
end

--- Update the gui when the player joins because it is likely to be outdated
--- @param event EventData.on_player_joined_game
local function refresh_player_permissions(event)
    local player = Gui.get_player(event)
    Elements.new_task_button.refresh_player(player)
    Elements.view_task_footer.update_player(player)
    Elements.edit_task_footer.update_player(player)
end

local e = defines.events

return {
    elements = Elements,
    events = {
        [e.on_player_joined_game] = refresh_player_tasks,
        [e.on_player_changed_force] = refresh_player_tasks,
        [Roles.events.on_role_assigned] = refresh_player_permissions,
        [Roles.events.on_role_unassigned] = refresh_player_permissions,
    }
}
