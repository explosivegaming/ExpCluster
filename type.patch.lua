---@meta

---@class script
script = {
    ---Raise an event. Only events generated with [LuaBootstrap::generate\_event\_name](https://lua-api.factorio.com/latest/classes/LuaBootstrap.html#generate_event_name) and the following can be raised:
    ---
    ---Events that can be raised manually:
    ---
    ---* [on\_console\_chat](https://lua-api.factorio.com/latest/events.html#on_console_chat)
    ---* [on\_player\_crafted\_item](https://lua-api.factorio.com/latest/events.html#on_player_crafted_item)
    ---* [on\_player\_fast\_transferred](https://lua-api.factorio.com/latest/events.html#on_player_fast_transferred)
    ---* [on\_biter\_base\_built](https://lua-api.factorio.com/latest/events.html#on_biter_base_built)
    ---* [on\_market\_item\_purchased](https://lua-api.factorio.com/latest/events.html#on_market_item_purchased)
    ---* [script\_raised\_built](https://lua-api.factorio.com/latest/events.html#script_raised_built)
    ---* [script\_raised\_destroy](https://lua-api.factorio.com/latest/events.html#script_raised_destroy)
    ---* [script\_raised\_revive](https://lua-api.factorio.com/latest/events.html#script_raised_revive)
    ---* [script\_raised\_teleported](https://lua-api.factorio.com/latest/events.html#script_raised_teleported)
    ---* [script\_raised\_set\_tiles](https://lua-api.factorio.com/latest/events.html#script_raised_set_tiles)
    ---
    ---### Example
    ---
    ---```
    ----- Raise the on_console_chat event with the desired message 'from' the first player
    ---local data = {player_index = 1, message = "Hello friends!"}
    ---script.raise_event(defines.events.on_console_chat, data)
    ---```
    ---
    ---[View Documentation](https://lua-api.factorio.com/latest/classes/LuaBootstrap.html#raise_event)
    ---
    --- Type patched in 2.0.28: [Bug Report](https://forums.factorio.com/viewtopic.php?f=233&t=125062)
    --- Changed "event" from "string | integer" to "LuaEventType"
    --- Resolved in 2.0.29, this patch will be removed was version is stable
    ---@param event LuaEventType ID or name of the event to raise.
    ---@param data table Table with extra data that will be passed to the event handler. Any invalid LuaObjects will silently stop the event from being raised.
    raise_event = function(event, data) end;
}

---@class LuaObject:userdata
--https://github.com/justarandomgeek/vscode-factoriomod-debug/issues/165
