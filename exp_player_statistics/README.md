# ExpGaming - Player Statistics

Keeps statistics for every player across every instance, such as kills, deaths and machines built. The totals live on the controller in `database/exp_player_statistics/players.json`, keyed by player name.

The Lua module counts what each player gains on an instance and sends it to the controller as a delta every 5 minutes, when the player leaves and when the instance stops. When a player joins, the instance fetches their totals from the controller so in-game code can show the total across every server. Anything left unsent when an instance starts came from a save made before it was sent, so it is dropped rather than counted twice.

Playtime and JoinCount are not stored by this plugin. They come from the online time and join count clusterio keeps for each user, and are added whenever the statistics are requested.

## Statistics

Times are in minutes.

| Name | Counts |
|---|---|
| `Playtime` | Time online, from the clusterio user. |
| `AfkTime` | Minutes a player has been AFK for more than 5 minutes. |
| `MapsPlayed` | Maps the player has joined, counted the first time they join each map. |
| `JoinCount` | Times the player joined, from the clusterio user. |
| `ChatMessages` | Chat messages sent. |
| `CommandsUsed` | Commands used. |
| `RocketsLaunched` | Rockets launched by the player's force while they were online. |
| `ResearchCompleted` | Research finished by the player's force while they were online. Research finished by script is not counted. |
| `MachinesBuilt` | Entities built. |
| `MachinesRemoved` | Entities of the player's own force mined or marked for deconstruction. |
| `TilesBuilt` | Tiles placed. |
| `TilesRemoved` | Tiles mined. |
| `TreesDestroyed` | Trees mined or marked for deconstruction. |
| `OreMined` | Resource entities mined. |
| `ItemsCrafted` | Items hand crafted. |
| `ItemsPickedUp` | Items picked up from the ground. |
| `Kills` | Entities of another, non-neutral force killed. |
| `Deaths` | Times the player died. |
| `DamageDealt` | Damage dealt to entities of another, non-neutral force. |
| `DistanceTravelled` | Tiles moved while not AFK. |
| `CapsulesUsed` | Capsules used. |
| `EntityRepaired` | Times the player repaired an entity. |
| `DeconstructionPlannerUsed` | Areas selected with a deconstruction planner. |
| `MapTagsMade` | Map tags added. |

Damage and kills from a car, spidertron or locomotive count for the driver, or the passenger when there is no driver. The simple counters and the display order are in `module/config.lua`.

## Permissions

`exp_player_statistics.view` is granted by default. It allows viewing the statistics of every player and subscribing to their updates.

## Web

The Statistics page lists every player with a stored record, one column per statistic. Columns are sortable and the player column is searchable. A picker in the header chooses which statistics are shown, and the choice is saved in the browser's local storage.

The user page gets a Statistics block with every statistic for that player.

## Lua

```lua
local ExpPlayerStatistics = require("modules/exp_player_statistics")

ExpPlayerStatistics.increment(player, "Kills", amount) -- amount defaults to 1
ExpPlayerStatistics.get(player, "Kills") -- Total on every server, player or name
ExpPlayerStatistics.format("Playtime", value, short) -- LocalisedString as shown to players
ExpPlayerStatistics.display_order -- Statistic names in the order they are shown
ExpPlayerStatistics.units -- Suffix shown after the value, by statistic
```

`get` returns the totals received when the player joined plus what they gained since. Playtime and JoinCount are those values at the time the player joined.

## Node

`StatisticsGetRequest` returns the totals of one player with Playtime and JoinCount added. `StatisticsListRequest` returns every stored record without them. Web plugins and control connections can subscribe to `PlayerStatisticsUpdatedEvent` with the `exp_player_statistics.view` permission.
