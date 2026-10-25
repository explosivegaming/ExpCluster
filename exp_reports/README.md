# ExpGaming - Reports

Lets players report each other in game or from the web interface. Reports are kept on the controller in `database/exp_reports/reports.json`, so a report made on one instance can be seen and cleared from any other.

Each report has the reported player, the player who made it, a reason, the instance it was made on and the time. A player can only report the same player once. Reports can't be edited, only marked as read or unread from the web interface, and deleted. Nothing is stored in the Lua state, every command sends a request to the controller and the answer is printed once it arrives.

The plugin also keeps a watch list in `database/exp_reports/watch_list.json`. When a player on it joins any instance, every admin online on every instance is told who joined where and why they are watched, and the join is posted to the webhooks. Names on the watch list are case insensitive, like Factorio and Clusterio user names. With `exp_reports.watch_unread_reports` set, players with unread reports are treated as if they were on the watch list, and their unread reports are listed with the join.

## Config

All fields are on the controller.

| Field | Default | Description |
|---|---|---|
| `exp_reports.discord_webhook_url` | | Discord channel webhook which new reports and watched player joins are posted to as an embed. |
| `exp_reports.json_webhook_url` | | URL which new reports and watched player joins are posted to as JSON. |
| `exp_reports.watch_unread_reports` | `false` | Treat players with unread reports as if they were on the watch list. |
| `exp_reports.announce_to_all_instances` | `true` | Tell admins on every instance when a watched player joins. When off only admins on the instance they joined are told. |

Only new reports and watched player joins are posted. Deleting or reading a report and editing the watch list are not. The JSON webhook gets `{ "type": "report_created", "report": { ... } }` with the report in the same form as `reports.json`, or `{ "type": "watched_player_joined", "player_name", "instance_name", "watch_list_entry", "unread_reports" }`. `watch_list_entry` is left out when the player is only watched for unread reports, and `unread_reports` is empty unless `exp_reports.watch_unread_reports` is set. Unread reports are newest first. The Discord embed lists the three newest and counts the rest in its footer. A webhook that fails is logged as a warning and the report is still made.

## Permissions

| Permission | Default | Allows |
|---|---|---|
| `exp_reports.report.get` | granted | Get a report by id. |
| `exp_reports.report.list` | granted | List the reports against every player, or one player. |
| `exp_reports.report.subscribe` | granted | Receive updates when reports are made or deleted. |
| `exp_reports.report.create` | not granted | Report a player from the web interface. |
| `exp_reports.report.delete` | not granted | Delete reports from the web interface. |
| `exp_reports.report.mark_read` | not granted | Mark reports as read or unread. |
| `exp_reports.watch_list.subscribe` | granted | See the watch list and receive updates to it. |
| `exp_reports.watch_list.add` | not granted | Add a player to the watch list. |
| `exp_reports.watch_list.remove` | not granted | Remove a player from the watch list. |

These only apply to the web interface and control connections. In game, players with the `exp_scenario.bypass.reports` role permission can't be reported.

## Commands

| Command | Description |
|---|---|
| `/create-report <player> <reason>` | Report a player. Alias `/report`. |
| `/get-reports [player]` | List the reports against a player, or the number against every player. Alias `/reports`. Admin only. |
| `/clear-reports <player> [from-player]` | Delete every report against a player, or only the one from `from-player`. Admin only. |

When a report is made, admins on that instance see who made it and the reason. Other players see the reported player and the reason. Clearing reports is announced to everyone on the instance.

## Web

The Reports page lists every report. The player, reporter and reason columns are searchable, and the instance column can be filtered. Reports made from the web interface show "Web UI" as the instance. The status column shows whether a report has been read and can be filtered. Users with `exp_reports.report.create` get a Create button. Each row has buttons for the permissions the user has: Mark read or Mark unread with `exp_reports.report.mark_read`, Add to watch list with `exp_reports.watch_list.add`, and Delete with `exp_reports.report.delete`. Add to watch list opens the add form with the player and the report's reason filled in, and is disabled once the player is on the watch list. A report made from the web interface is made by the logged in user.

Below the reports is the watch list, with the player, reason, who added them and when. Users with `exp_reports.watch_list.add` get an Add button, and users with `exp_reports.watch_list.remove` get a Delete button on each row. A reason is required. Players watched only for unread reports are not listed here.

## Lua

```lua
local ExpReports = require("modules/exp_reports")

ExpReports.create_report(player, reported_player, reason)
ExpReports.list_reports(player, reported_player) -- Every player when reported_player is nil
ExpReports.delete_reports(player, reported_player, by_player_name) -- Only those from by_player_name when given

[ExpReports.on_player_reported] = function(event) end, -- { player_index, by_player_name, reason, report_count, by_player_names }
[ExpReports.on_reports_deleted] = function(event) end, -- { player_index, by_player_name, count }
```

The functions only send the request, the outcome is printed to `player`. The events are raised on the instance the command was used on, and only when the reported player is online there.

## Node

`ReportCreateRequest`, `ReportListRequest`, `ReportGetRequest` and `ReportDeleteRequest` can be sent from instances and control connections. `ReportSetReadRequest`, `WatchListAddRequest` and `WatchListRemoveRequest` can only be sent from control connections. Web plugins and control connections can subscribe to `ReportUpdatedEvent` with the `exp_reports.report.subscribe` permission, and to `WatchListUpdatedEvent` with `exp_reports.watch_list.subscribe`. The controller sends `WatchedPlayerJoinedEvent` to every instance when a watched player joins.
