# ExpGaming - Permission Groups

Syncs Factorio permission groups between the controller and instances, and puts players in a group based on their clusterio roles.

The controller stores groups, role mappings and assignments in `database/exp_groups/`. On start the instance fetches every group and replaces the groups in the save with them. Groups the controller does not know are deleted and their players moved to Default. After that the instance gets updates as groups change.

When a player joins, and while they are online, the controller picks their group from the first of:

- An assignment for the player.
- The enabled role mapping with the highest priority whose roles the player all holds. These are clusterio roles.
- Default.

Deleting a group deletes the role mappings and assignments that point to it and moves its players to Default.

## Config

On the instance:

| Field | Default | Description |
|---|---|---|
| `exp_groups.sync_mode` | bidirectional | `disabled` does not sync. `enabled` applies groups and player groups from the controller. `bidirectional` also sends changes made in game to the controller. |

With `bidirectional`, groups created or edited in game are sent to the controller every 300 ticks, and deleted groups right away. Moving a player to another group in game updates their assignment, if they have one.

## Permissions

| Permission | Default | Allows |
|---|---|---|
| `exp_groups.group.get` | granted | Viewing a group. |
| `exp_groups.group.list` | granted | Listing groups. |
| `exp_groups.group.subscribe` | granted | Getting group updates. |
| `exp_groups.group.create` | | Creating groups. |
| `exp_groups.group.update` | | Renaming groups and changing their permissions. |
| `exp_groups.group.delete` | | Deleting groups. |
| `exp_groups.assignment.get` | granted | Viewing the assignment for a player. |
| `exp_groups.assignment.list` | granted | Listing assignments. |
| `exp_groups.assignment.subscribe` | granted | Getting assignment updates. |
| `exp_groups.assignment.create` | | Assigning a player to a group. |
| `exp_groups.assignment.update` | | Changing the group of an assignment. |
| `exp_groups.assignment.delete` | | Removing an assignment. |
| `exp_groups.role_mapping.get` | granted | Viewing a role mapping. |
| `exp_groups.role_mapping.list` | granted | Listing role mappings. |
| `exp_groups.role_mapping.subscribe` | granted | Getting role mapping updates. |
| `exp_groups.role_mapping.create` | | Creating role mappings. |
| `exp_groups.role_mapping.update` | | Editing role mappings. |
| `exp_groups.role_mapping.delete` | | Deleting role mappings. |

## Web

The Permission Groups page lists groups, role mappings and assignments, each with a Create button. Clicking a group opens its page at `/permission_groups/:id/view`. There you can rename it, tick the input actions it allows, or delete it. The list of input actions comes from the defines exported for the default mod pack, so the page needs a mod pack export to show them.

## Lua

```lua
local ExpGroups = require("modules/exp_groups")

ExpGroups.set_emit_events(true) -- Send changes made in game to the instance
ExpGroups.initialise_groups(groups) -- Replace every group in the save
ExpGroups.receive_group_update(group)
ExpGroups.receive_assignment_update(assignment) -- Move the player to the group
```

These are called by the instance over RCON. Other modules should use the Factorio permission groups directly.

## Node

Every request has a matching permission above. Groups use `GroupCreateRequest`, `GroupUpdateRequest`, `GroupDeleteRequest`, `GroupGetRequest` and `GroupListRequest`. Assignments and role mappings have the same five. `AssignmentGetRequest` with `resolve` set returns the group the player ends up in, not only an assignment. Control connections can subscribe to `GroupUpdatedEvent`, `ManualAssignmentUpdatedEvent` and `RoleMappingUpdatedEvent`. Instances subscribe to `ResolvedAssignmentUpdatedEvent` for each player online.
