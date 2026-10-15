# ExpGaming - Roles

Mirrors clusterio roles into the game. Each clusterio role is a role in game with the same id, name and permissions, and a player holds the roles of the clusterio user with the same name. Permission checks in game use clusterio permission names, so `exp_scenario.command.kill` is granted in game by the same role that grants it in the web UI.

The controller is the source of truth. It stores the in game properties of each role in `database/exp_roles/role_meta.json`, keyed by role id, and creates them for any role that has none. New roles go after every existing role in the order. On start the instance fetches every role and assignment and replaces the state in the save. After that it gets updates as roles and users change. The default role, `controller.default_role_id`, is held by every player and is not stored per player.

Only the roles with the highest priority a player holds apply. A Jail role with a higher priority than the rest suppresses every other role, the default role included.

The controller grants roles by online time across the cluster. It checks on start, when a role or user changes, and when a player leaves an instance. Roles granted this way are never taken away. Players holding a role with block auto assign set are never granted roles this way.

## Config

On the instance:

| Field | Default | Description |
|---|---|---|
| `exp_roles.sync_mode` | bidirectional | `disabled` does not sync. `enabled` applies roles from the controller. `bidirectional` also sends roles assigned or unassigned in game to the controller. |

A role assigned in game applies right away. If the controller refuses it the instance takes it back off the player. Changing the mode from `disabled` applies on the next instance start.

## Permissions

The plugin has no permissions of its own. Listing roles needs `core.role.list`, subscribing to role updates needs `core.role.subscribe`, and editing the in game properties needs `core.role.update`.

## Web

The role page gets an In Game Properties section with these fields:

| Field | Default | Description |
|---|---|---|
| Order | after the last role | A lower value is a more privileged role. Ties go to the lower id. |
| Priority | 0 | Only the roles with the highest priority a player holds apply. |
| Short hand | | Short form of the name, the name when empty. |
| Tag | | Shown next to the names of players with this role. |
| Colour | | Used for the role name and tag in game. |
| Auto assign after (hours) | | Online time after which the role is granted, never when empty. |
| Block auto assign | false | Holders of this role are never granted roles automatically. |

## Lua

```lua
local ExpRoles = require("modules/exp_roles")

ExpRoles.get_role(role_id) -- Roles are looked up by clusterio id
ExpRoles.get_role_by_name("Moderator")
ExpRoles.get_roles() -- In no particular order
ExpRoles.get_ordered_roles() -- Most privileged first
ExpRoles.get_default_role()
ExpRoles.get_higher_roles(role) -- The role and those above it, default role excluded
ExpRoles.get_lower_roles(role) -- The role and those below it, default role excluded
ExpRoles.get_player_roles(player) -- Roles that apply, nil is the server which has core.admin
ExpRoles.get_player_highest_role(player)
ExpRoles.player_has_permission(player, "exp_scenario.command.kill")
ExpRoles.player_has_any_permission(player, ...)
ExpRoles.player_has_all_permission(player, ...)
ExpRoles.player_outranks(player, other)
ExpRoles.define_permission_trigger(permission, function(player, state) end) -- Run on join and role changes

role:has_permission(permission) -- core.admin grants every permission
role:is_higher_than(other)
role:has_player(player) -- Ignores priority
role:get_player_names() -- Includes players who never joined this map
role:get_players(online)
role:print(message) -- Returns how many online players got it
role:assign(player, { by_player_name, silent, local_only }) -- local_only keeps it to this map
role:unassign(player, { by_player_name, silent, local_only })

[ExpRoles.events.on_player_roles_changed] = function(event) end, -- { player_index, by_player_index, assigned, unassigned }
```

## Node

`RoleListRequest` returns every role combined with its in game properties. Control connections can subscribe to `RoleUpdatedEvent`. `RoleMetaUpdateRequest` sets the in game properties of a role.
