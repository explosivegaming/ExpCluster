# ExpGaming - Commands

Lua library for adding Factorio commands with typed arguments, aliases and permission checks. The other ExpCluster plugins add all their commands through it. It has no config, and the Node side is empty so the module gets patched into the save.

Input is split on spaces, and double quotes group words into one argument. Each argument goes through its parser before the callback runs, and every permission authority must allow the player. From RCON the player is `Commands.server`, which passes every permission check and raises an error if the callback reads a field it does not have. Denied and failed attempts, and commands run by players, are appended as JSON lines to `script-output/log/commands.log`.

## Commands

| Command | Description |
|---|---|
| `/commands [keyword] [page]` | Lists custom commands the player can use and game commands matching the keyword, 5 per page. Aliases `/chelp` and `/helpp`. |
| `/_rcon <code>` | Runs Lua code. Globals it sets are kept in storage between runs. |
| `/_sudo <player> <command> [arguments]` | Runs a command as another player, with their permissions. |
| `/_ipc <channel> <json>` | Sends the JSON to Clusterio on the given IPC channel. |

The `_` commands have the `system_only` flag. Only RCON and players unlocked with `Commands.unlock_system_commands` can use them.

`/_rcon` has `Commands`, `ExpUtil`, `Async`, `Clustorio`, `ipc` and `print` as globals, and `player`, `surface`, `force`, `position`, `entity` and `tile` for the player running it. `entity` is the selected entity.

## Lua

```lua
local Commands = require("modules/exp_commands")

Commands.new("repeat", { "my-module.description" })
    :argument("count", { "my-module.arg-count" }, Commands.types.integer_range(1, 10))
    :optional("message", nil, Commands.types.string)
    :defaults{ message = "Hello" } -- A function default is called with the player
    :add_aliases{ "repeat-message" }
    :add_flags{ "admin_only" }
    :enable_auto_concatenation() -- The last argument takes the rest of the input
    :register(function(player, count, message)
        for i = 1, count do Commands.print(i .. " " .. message) end
        return Commands.status.success() -- Returning nothing also counts as success
    end)

Commands.status.success(msg) -- Or error, unauthorised, invalid_input
Commands.print(value) -- To the player running the command, or to RCON
Commands.error(value)
Commands.add_data_type("name", parser) -- Adds Commands.types.name, parser(input, player) returns a status
Commands.add_permission_authority(function(player, command) end) -- Return a boolean or a status
Commands.player_has_permission(player, command)
Commands.list_for_player(player)
Commands.search_for_player(keyword, player)
Commands.disable_command(name) -- Or enable_command, kept in storage
Commands.unlock_system_commands(player_name) -- Or lock_system_commands, kept in storage
Commands.add_rcon_static(name, value) -- Global in /_rcon, control stage only
Commands.add_rcon_dynamic(name, function(player) end) -- Called on each /_rcon
```

Types in `Commands.types`: `boolean`, `string`, `number`, `integer`, `player`, `player_online`, `player_alive`, `force`, `surface`, `planet` and `color`. These take arguments and return a parser: `enum(options)`, `key_of(map)`, `string_max_length(max)`, `number_range(min, max)` and `integer_range(min, max)`. `integer` floors the number. `boolean` is true for yes, y, true and 1, and false for anything else.

Flags checked by the built in permission authorities:

| Flag | Allows |
|---|---|
| `admin_only` | Game admins. |
| `system_only` | RCON and unlocked players. |
| `character_only` | Players controlling their character, not in remote view. |
| `remote_only` | Players in remote view. |

A command disabled with `Commands.disable_command` works only for RCON and unlocked players.

`/commands` searches the translated descriptions in the player's locale. Translations are requested when a player joins or changes locale, so a search finds nothing in a locale no player has joined with yet.
