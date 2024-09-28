--- Config file for the tasks gui
-- @config Tasks

return {
    -- Adding tasks
    allow_add_task = "all", --- @setting allow_add_task dictates who is allowed to add new tasks; values: all, admin, expcore.roles, none
    expcore_roles_allow_add_task = "gui/task-list/add", --- @setting expcore_roles_allow_add_task if expcore.roles is used then this is the required permission

    -- Editing tasks
    allow_edit_task = "expcore.roles", --- @setting allow_edit_task dictates who is allowed to edit existing tasks; values: all, admin, expcore.roles, none
    expcore_roles_allow_edit_task = "gui/task-list/edit", --- @setting expcore_roles_allow_edit_task if expcore.roles is used then this is the required permission
    user_can_edit_own_tasks = true, --- @settings if true then the user who made the task can edit it regardless of the allow_edit_task setting
}
