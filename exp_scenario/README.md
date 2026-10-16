# ExpGaming - Scenario

The Explosive Gaming scenario. It adds the in-game commands, guis and control modules players see on ExpGaming servers, and loads them into every instance as the `exp_scenario` save patch module.

Most parts of the scenario are features that can be turned on and off and configured from the web interface while the game is running. Permissions in game are clusterio permissions checked through exp_roles, so the plugin needs exp_roles, exp_groups, exp_reports, exp_server_list, exp_player_statistics, exp_commands, exp_gui and exp_util loaded as well.

## Features

Each feature is registered in Lua with `Feature.register` from `module/features.lua` and declared again in `features.ts` with a title, description and the fields the web interface can edit. The defaults on both sides must match, `test/features.test.js` checks this.

The controller keeps one record per feature in `database/exp_scenario/features.json` with its enabled state and the values that differ from the default. On start it adds new features, deletes removed ones and drops stored values that no longer fit a field, logging a warning for each.

Edits are made on the Scenario Features page of the web interface. When a record changes the controller broadcasts it, and each running instance sends every value of the feature over RCON to `exp_scenario.features.receive_update`. Instances also fetch the full list when they start and when they reconnect to the controller. The Lua side keeps the last values in `storage`, so they survive saving and loading the map.

While a feature is disabled its event handlers do nothing, its commands are denied and its toolbar buttons are hidden.

| Feature | Description |
|---|---|
| `afk_kick` | Kick everyone when nobody online is active. |
| `autofill` | Fill ammo and fuel into entities when they are built. |
| `chat_auto_reply` | Reply to key words in chat and run chat commands. |
| `community_details` | Community name and links, see below. |
| `custom_start` | Map settings applied when the map is created, and the items new players start with. |
| `deconstruction_log` | Write actions of players to `log/deconstruction.log`. |
| `degrading_tiles` | Tiles wear down as players walk and build on them. |
| `death_markers` | Map markers, lights and lines to corpses, and collecting expired corpses into chests. |
| `discord_alerts` | Write alerts for the Discord bot on bans, mutes, kicks, jails and logged commands. |
| `extra_logging` | Write rockets, deaths, research, joins and leaves to a log file. |
| `greetings` | Greet players when they join and show their join message. |
| `help_bubbles` | A compilatron at spawn that cycles through tips and the community links. |
| `inventory_clear` | Move the items of banned and kicked players to a chest at spawn. |
| `lawnmower` | The `/lawnmower` command. |
| `mine_depletion` | Deconstruct mining drills when their resources run out. |
| `module_inserter` | A selection tool that fills machines with modules. |
| `nuke_protection` | Remove banned items from players without the bypass permission. |
| `player_bonus` | Points players spend on personal bonuses. |
| `pollution_grading` | Scale the pollution overlay. |
| `popups` | Flying text for chat messages and damage. |
| `protection` | Stop players removing protected entities placed by others. |
| `repair` | The `/repair` command. |
| `research` | Research effects such as bonus inventory slots. |
| `research_milestones` | A gui tracking research against target times. |
| `rocket_info` | A gui with rocket launch statistics and silo progress. |
| `science_production` | A gui with the production of each science pack. |
| `spawn_area` | Build the spawn area when the first player joins. |
| `station_auto_name` | Name train stops when they are built. |
| `task_list` | A shared list of tasks. |
| `warp_list` | Warp points players can travel between. |
| `vlayer` | A shared virtual surface for solar panels, accumulators and storage. |

`community_details` holds the community name and the Discord, website, status page, GitHub and Patreon links. Chat replies, the readme gui, the help bubbles and the greeting read them. They are always used, the enabled switch has no effect.

Some settings are not features. Data tables such as the bonuses in `config/player_bonus.lua` and the research targets in `config/research_data.lua` are only changed by editing the module.

### Adding a feature

Register it in the Lua file that uses it and guard the handlers:

```lua
local Feature = require("modules/exp_scenario/features")
local feature, config = Feature.register("my_feature", {
    show_message = true,
    role_id = Feature.optional("number"),
    item_names = Feature.set{ "iron-plate" },
    section = { count = 1 }, -- edited as "section.count"
})

return feature:guard{ events = { ... } }
```

Commands take `:add_flags{ feature = feature }`. Read `config` where it is used, the table is updated in place. Then add an entry with the same name and defaults to `features` in `features.ts`, or the web interface can not configure it. Values read while the file loads, such as `on_nth_tick` periods, can not be changed at runtime and are left out of `features.ts`.

## Seed

The Seed roles and groups button on the Roles page creates the roles and Factorio permission groups the scenario used before roles moved to the controller. It needs the `exp_scenario.seed` permission and the exp_roles and exp_groups plugins.

It creates 13 roles, Senior Administrator down to Regular plus Jail. The controller's admin role becomes System and its default role becomes Guest, the seed sets their short hand and colour but not their permissions. Each role also gets the permissions of its parent in the seed, the way the old config inherited them. Regular is auto assigned after 3 hours played and Veteran after 10. Jail has priority 1 and blocks auto assignment.

It creates the permission groups Admin, Trusted, Standard, Guest and Restricted, and maps each role to one of them, higher roles getting a higher mapping priority.

It can be run again. Roles that already exist by name keep their permissions and gain the seeded ones. Groups that already exist by name are reset to the seeded input actions.

## Player settings

The controller keeps some settings per player in `database/exp_scenario/players.json`, so they follow a player between servers:

- Join message. Printed to everyone when the player joins, unless `greetings` is disabled. Set in game with `/set-join-message` and removed with `/remove-join-message`, or edited on the user page of the web interface. Up to 255 characters.
- Toolbar. The order and state of the player's toolbar buttons, sent when they leave and restored when they join.

## Permissions

| Permission | Description |
|---|---|
| `exp_scenario.config.view` | View the Scenario Features page. |
| `exp_scenario.config.edit` | Edit features on the Scenario Features page. |
| `exp_scenario.seed` | Seed the roles and permission groups. |
| `exp_scenario.join_message.set` | Set your own join message from the web interface. |
| `exp_scenario.join_message.set_other` | Set the join message of other users. |

Users can always see their own player settings on the user page, `core.user.get` allows it for other users.

`permissions.ts` defines another 109 permissions checked in game through exp_roles. They are grouped by prefix: `exp_scenario.command.*` for each command, `exp_scenario.gui.*` for guis and their actions, `exp_scenario.bypass.*`, `exp_scenario.decon.*`, `exp_scenario.player.*` and `exp_scenario.chat.commands`. Every command checks `exp_scenario.command.<name>` with hyphens replaced by underscores, including commands added by other ExpGaming plugins such as `/server-ups`. 24 of them, mostly guis and informational commands, are granted by default.

## Lua

The module is split into:

- `commands/` the chat commands, plus `_authorities.lua` for the permission and feature checks, `_rcon.lua` for the `/_rcon` environment and `_types.lua` for argument types.
- `control/` event handlers that run without a gui, such as afk kick, protection and the spawn area.
- `gui/` the guis and toolbar buttons, with the debug gui in `gui/debug/`.
- `config/` data tables and some feature registrations, such as `community_details.lua` and `spawn_area.lua`.
- `features.lua` the feature registry described above.

`exp_scenario.features` and `exp_scenario.player_settings` are globals so the instance plugin can call them with `/sc`.
