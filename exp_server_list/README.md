# ExpGaming - Server List

Shares the details of every instance with every other instance. Replaces `expcore/external` from exp_legacy, which read the same data from a file written by an outside service.

The controller keeps one record per instance with its name, mod pack, Factorio version, players online, status and address. The address is the public address of the host and the game port of the instance, the same one the web UI shows. Whether the server has a game password is sent, the password is not. Nothing is saved, the records are rebuilt from the instances when the controller starts.

## Config

On the controller:

| Field | Default | Description |
|---|---|---|
| `exp_server_list.welcome` | | Message shown on the welcome tab of the readme for instances without their own. |

On the instance:

| Field | Default | Description |
|---|---|---|
| `exp_server_list.display_name` | | Name shown in the server list, the instance name when empty. |
| `exp_server_list.description` | | One line about the server shown in the server list, the description in `factorio.settings` when empty. |
| `exp_server_list.welcome` | | Message shown on the welcome tab of the readme, the controller welcome when empty. |
| `exp_server_list.reset_time` | | When the map next resets, shown on the welcome tab of the readme. |
| `exp_server_list.hidden` | false | Leave this instance out of the server list on other instances. |
| `exp_server_list.always_on_top` | false | List this instance before those without it. |

## Lua

```lua
local ExpServerList = require("modules/exp_server_list")

ExpServerList.get_servers() -- Every server that is not hidden, always on top first then by name
ExpServerList.get_server(instance_id)
ExpServerList.is_synced() -- false until the controller has sent the list
ExpServerList.get_current() -- nil until the controller has sent the list
ExpServerList.find_servers("weekly") -- Matches name, display name or id
ExpServerList.is_online(server)
ExpServerList.request_connection(player, server_or_address, self_requested)

[ExpServerList.on_servers_updated] = function(event) end, -- { server_ids }
```

## Node

`ServerListRequest` returns every record, hidden ones included. Web plugins and control connections can subscribe to `ServerUpdatesEvent` with the `exp_server_list.list` permission.
