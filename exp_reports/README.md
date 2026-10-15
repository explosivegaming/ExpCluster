# ExpGaming - Reports

Lets players report each other in game or from the web interface. Reports are kept on the controller in `database/exp_reports/reports.json`, so a report made on one instance can be seen and cleared from any other.

Each report has the reported player, the player who made it, a reason, the instance it was made on and the time. A player can only report the same player once. Reports can't be edited, only deleted. Nothing is stored in the Lua state, every command sends a request to the controller and the answer is printed once it arrives.

## Config

All fields are on the controller.

| Field | Default | Description |
|---|---|---|
| `exp_reports.discord_webhook_url` | | Discord channel webhook which new reports are posted to as an embed. |
| `exp_reports.json_webhook_url` | | URL which new reports are posted to as JSON. |

Only new reports are posted, deletions are not. The JSON webhook gets `{ "type": "report_created", "report": { ... } }` with the report in the same form as `reports.json`. A webhook that fails is logged as a warning and the report is still made.

## Permissions

| Permission | Default | Allows |
|---|---|---|
| `exp_reports.report.get` | granted | Get a report by id. |
| `exp_reports.report.list` | granted | List the reports against every player, or one player. |
| `exp_reports.report.subscribe` | granted | Receive updates when reports are made or deleted. |
| `exp_reports.report.create` | not granted | Report a player from the web interface. |
| `exp_reports.report.delete` | not granted | Delete reports from the web interface. |

These only apply to the web interface and control connections. In game, players with the `exp_scenario.bypass.reports` role permission can't be reported.

## Commands

| Command | Description |
|---|---|
| `/create-report <player> <reason>` | Report a player. Alias `/report`. |
| `/get-reports [player]` | List the reports against a player, or the number against every player. Alias `/reports`. Admin only. |
| `/clear-reports <player> [from-player]` | Delete every report against a player, or only the one from `from-player`. Admin only. |

When a report is made, admins on that instance see who made it and the reason. Other players see the reported player and the reason. Clearing reports is announced to everyone on the instance.

## Web

The Reports page lists every report. The player, reporter and reason columns are searchable, and the instance column can be filtered. Reports made from the web interface show "Web UI" as the instance. Users with `exp_reports.report.create` get a Create button, and users with `exp_reports.report.delete` get a Delete button on each row. A report made from the web interface is made by the logged in user.

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

`ReportCreateRequest`, `ReportListRequest`, `ReportGetRequest` and `ReportDeleteRequest` can be sent from instances and control connections. Web plugins and control connections can subscribe to `ReportUpdatedEvent` with the `exp_reports.report.subscribe` permission.
