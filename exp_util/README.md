# ExpGaming - Module Utilities

Lua library the other ExpCluster plugins build on. It adds to the `math` and `table` globals, guards `require` at runtime, and has modules for storage, tasks spread over ticks, selection tools, flying text and bounding boxes. It has no config, and the Node side is empty so the module gets patched into the save.

Loading the module adds `math.round`, `math.clamp`, `table.get_keys`, `table.inspect`, `table.deep_copy` and more to the globals. `package.lifecycle` tracks the current stage. Once the first player joins, or on singleplayer or multiplayer init, the stage is runtime. From then on `require` only returns files that were already loaded and raises an error for anything else. Functions marked control stage only below raise an error at runtime.

## Lua

```lua
local ExpUtil = require("modules/exp_util")
local Storage = require("modules/exp_util/storage")
local Async = require("modules/exp_util/async")
local Selection = require("modules/exp_util/selection")
local FlyingText = require("modules/exp_util/flying_text")
local AABB = require("modules/exp_util/aabb")
local Colors = require("modules/exp_util/include/color") -- Also ExpUtil.color
local FlowPrecision = require("modules/exp_util/include/flow_precision")
```

Storage gives each file its own table in `storage.exp_storage`, keyed by the file path. Register once per file, in the control stage:

```lua
local data = { players = {} }
Storage.register(data, function(tbl) data = tbl end) -- Called on init and load
Storage.register_metatable("MyClass", metatable) -- Prefixed with the module name
```

Async runs a function on a later tick. Its calls can be kept in storage. Register in the control stage. The id is the file and line the function is defined on, so moving it breaks calls queued in an existing save.

```lua
local say = Async.register(function(name) game.print("Hello " .. name) end)
say("Dave") -- Next tick, same as say:start_soon("Dave")
say:start_after(60, "Dave")
say:start_now("Dave") -- This tick
say:start_task("Dave") -- Only if no call to it is queued
local pending = say("Dave") -- pending:cancel() or pending:return_to(other_async)

return Async.status.continue(...) -- From inside, run again next tick with new arguments
return Async.status.delay(ticks, ...)
return Async.status.complete(...) -- Or return nothing
```

Selection gives a player a `selection-tool` and sends the area events to the active selection. It stops when the tool leaves the cursor, or the player leaves or dies.

```lua
local MySelection = Selection.connect("my_selection") -- Control stage only
MySelection:on_selection(function(event, ...) end) -- Also on_alt_selection, on_start, on_stop
MySelection:start(player, ...) -- Extra arguments are passed to the handlers
MySelection:stop(player)
```

Other functions used often. `transfer_inventory_to_surface` moves the items into matching entities on the surface and creates more when `allow_creation` is set.

```lua
ExpUtil.assert_not_runtime()
ExpUtil.assert_argument_type(value, "table", 1, "name")
ExpUtil.write_json(path, tbl) -- Appends one JSON line to script-output on the server
ExpUtil.optional_require(path) -- nil if the file does not exist
ExpUtil.auto_complete(options, input) -- Best match, prefers matches at the start of a word
ExpUtil.format_any(value) -- Readable string or locale string for any value
ExpUtil.format_time(ticks, "short", { hours = true, minutes = true }) -- Also "long" and "clock"
ExpUtil.format_player_name(player) -- Name in the player's chat color
ExpUtil.teleport_player(player, surface, position, "dismount") -- Or "allow", "disallow"
ExpUtil.transfer_inventory_to_surface{ inventory = inv, surface = surface, name = "iron-chest", allow_creation = true }
FlyingText.create_above_player{ target_player = player, text = "Hi" }
AABB.contains_point(aabb, point)
```
