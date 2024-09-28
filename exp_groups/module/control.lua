local clusterio_api = require("modules/clusterio/api")
local Global = require("modules/exp_util/global")
local Groups = require("modules/exp_groups")

local pending_updates = {}
Global.register(pending_updates, function(tbl)
    pending_updates = tbl
end)

local function on_permission_group_added(event)
    if not event.player_index then return end
    pending_updates[event.group.name] = {
        created = true,
        sync_all = true,
        tick = event.tick,
        permissions = {},
        players = {},
    }
end

local function on_permission_group_deleted(event)
    if not event.player_index then return end
    local existing = pending_updates[event.group_name]
    pending_updates[event.group_name] = nil
    if not existing or not existing.created then
        clusterio_api.send_json("exp_groups-permission_group_delete", {
            group = event.group_name,
        })
    end
end

local function on_permission_group_edited(event)
    if not event.player_index then return end
    local pending = pending_updates[event.group.name]
    if not pending then
        pending = {
            tick = event.tick,
            permissions = {},
            players = {},
        }
        pending_updates[event.group.name] = pending
    end
    pending.tick = event.tick

    if event.type == "add-permission" then
        if not pending.sync_all then
            pending.permissions[event.action] = true
        end
    elseif event.type == "remove-permission" then
        if not pending.sync_all then
            pending.permissions[event.action] = false
        end
    elseif event.type == "enable-all" then
        pending.sync_all = true
    elseif event.type == "disable-all" then
        pending.sync_all = true
    elseif event.type == "add-player" then
        local player = game.get_player(event.other_player_index) --- @cast player -nil
        pending.players[player.name] = true
    elseif event.type == "remove-player" then
        local player = game.get_player(event.other_player_index) --- @cast player -nil
        pending.players[player.name] = nil
    elseif event.type == "rename" then
        pending.created = true
        pending.sync_all = true
        local old = pending_updates[event.old_name]
        if old then pending.players = old.players end
        on_permission_group_deleted{
            tick = event.tick, player_index = event.player_index, group_name = event.old_name,
        }
    end
end

local function send_updates()
    local tick = game.tick - 600 -- 10 Seconds
    local done = {}
    for group_name, pending in pairs(pending_updates) do
        if pending.tick < tick then
            done[group_name] = true
            if pending.sync_all then
                clusterio_api.send_json("exp_groups-permission_group_create", {
                    group = group_name, defiantion = Groups.get_group(group_name):to_json(true),
                })
            else
                if next(pending.players) then
                    clusterio_api.send_json("exp_groups-permission_group_edit", {
                        type = "assign_players", group = group_name, changes = table.get_keys(pending.players),
                    })
                end
                local add, remove = {}, {}
                for permission, state in pairs(pending.permissions) do
                    if state then
                        add[#add + 1] = permission
                    else
                        remove[#remove + 1] = permission
                    end
                end

                if next(add) then
                    clusterio_api.send_json("exp_groups-permission_group_edit", {
                        type = "add_permissions", group = group_name, changes = Groups.actions_to_names(add),
                    })
                end
                if next(remove) then
                    clusterio_api.send_json("exp_groups-permission_group_edit", {
                        type = "remove_permissions", group = group_name, changes = Groups.actions_to_names(remove),
                    })
                end
            end
        end
    end

    for group_name in pairs(done) do
        pending_updates[group_name] = nil
    end
end

return {
    events = {
        [defines.events.on_permission_group_added] = on_permission_group_added,
        [defines.events.on_permission_group_deleted] = on_permission_group_deleted,
        [defines.events.on_permission_group_edited] = on_permission_group_edited,
    },
    on_nth_tick = {
        [300] = send_updates,
    },
}
