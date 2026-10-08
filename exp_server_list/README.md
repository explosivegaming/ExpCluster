# ExpGaming - Server List

Shares the details of every instance with every other instance. Replaces `expcore/external` from exp_legacy, which read the same data from a file written by an outside service.

The controller keeps one record per instance with its name, mod pack, Factorio version, players online, status and address. The address is the public address of the host and the game port of the instance, the same one the web UI shows. Nothing is saved, the records are rebuilt from the instances when the controller starts.

## Config

All fields are on the instance.

| Field | Default | Description |
|---|---|---|
| `exp_server_list.short_name` | | Name shown in the server list, the instance name when empty. |
| `exp_server_list.description` | | One line about the server shown in the server list. |
| `exp_server_list.welcome` | | Message shown on the welcome tab of the readme. |
| `exp_server_list.reset_time` | | When the map next resets, shown on the welcome tab of the readme. |
| `exp_server_list.hidden` | false | Leave this instance out of the server list on other instances. |

## Lua

```lua
local ExpServerList = require("modules/exp_server_list")

ExpServerList.get_servers() -- Every server that is not hidden, sorted by name
ExpServerList.get_server(instance_id)
ExpServerList.get_current() -- nil until the controller has sent the list
ExpServerList.find_servers("weekly") -- Matches name, short name or id
ExpServerList.is_online(server)
ExpServerList.request_connection(player, server_or_address, self_requested)

[ExpServerList.on_servers_updated] = function(event) end, -- { server_ids }
```

## Node

Controller plugins can read the records with `ControllerPlugin.get(controller).servers`. Web plugins and control connections can subscribe to `ServerUpdatesEvent` with the `exp_server_list.list` permission.
