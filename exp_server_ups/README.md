# ExpGaming - Server UPS

Shows the UPS the server is running at in the top right of the screen, below the game's own UPS and clock. The label reads like `59.8 (99.7%)`, the second number being the UPS as a percentage of 60.

The label starts hidden. Players toggle it with `/server-ups`, also available as `/sups` and `/ups`. With exp_scenario loaded the command needs the `exp_scenario.command.server_ups` permission, which is granted by default.

The instance asks the game for the current tick over RCON once every update interval and divides the ticks passed by the time passed, averaged over the last `average_interval` updates. Each request also sends the last result, which updates the label for every online player. If `auto_pause` is enabled in `factorio.settings`, updates start when a player joins and stop when the last player leaves, otherwise they run from when the instance starts.

## Config

All fields are on the instance.

| Field | Default | Description |
|---|---|---|
| `exp_server_ups.update_interval` | 1000 | Time between updates in milliseconds. |
| `exp_server_ups.average_interval` | 60 | Number of updates the UPS is averaged over. |

## Lua

```lua
local ServerUps = require("modules/exp_server_ups")

ServerUps.refresh_online(ups) -- Set the label of every online player
ServerUps.get_main_label(player) -- The label of a player, created hidden if missing
ServerUps.set_visible(player, visible)
```

The instance calls `/_rcon return exp_server_ups.refresh(ups)`, which updates the labels and returns `game.tick`.
