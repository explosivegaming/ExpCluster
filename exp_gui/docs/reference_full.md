# ExpGui Full API Reference

If you haven’t already, please read the [framework guide](../readme.md) and [condensed reference](./reference.md) first, this full reference won’t be very useful without that context.

Additionally, if you find yourself needing to rely heavily on this document, I strongly recommend reading the actual implementation of each function.
It will give you a far better understanding than the limited comments provided here.

[Pre-defined elements](../module/elements.lua), [styles](../module/styles.lua), and elements defined by the toolbar are not included in this reference.

## Control ([`control.lua`](../module/control.lua))

It is expected this file is required as `modules/exp_gui` and is assigned to the variable `Gui`.

### `Gui.define`

This is a reference to [`ExpElement.new`](#expelementnew)

It creates new element definations.
The name provided must be unqiue to your mod.

### `Gui.from_argument`

This is a reference to [`ExpElement.from_argument`](#expelementfrom_argument)

It is used within defiantion tables (draw, style, and data) to use a value from an argument.
The argument can be named or positional, and a default value can be provided.

### `Gui.from_name`

This is a reference to [`ExpElement.from_name`](#expelementfrom_name)

It is used within defiantion tables (draw, style, and data) to use a value from the defination name. The most common use case is `name = Gui.from_name` within a draw table.

### `Gui.no_return`

This is a reference to [`ExpElement.no_return`](#expelementno_return)

It is used exclusively within [`ExpElement:draw`](#expelementdraw) to signal the intental lack of a return value.

### `Gui.top_elements`

This is a table of all registered elements for the top flow.

The keys are ExpElement and the values are the default visibltiy callback / boolean.

### `Gui.left_elements`

This is a table of all registered elements for the left flow.

The keys are ExpElement and the values are the default visibltiy callback / boolean.

### `Gui.relative_elements`

This is a table of all registered elements for relative locations.

The keys are ExpElement and the values are the default visibltiy callback / boolean.

### `Gui.get_top_flow`

This is a reference to `mod_gui.get_button_flow`

It gets the flow where top elements are added to.

### `Gui.get_left_flow`

This is a reference to `mod_gui.get_frame_flow`

It gets the flow where left elements are added to.

### `Gui._debug`

After this function is called, all players GUIs will be redrawn every join.
This is helpful for structure and style debugging.

### `Gui.get_player`

A version of `game.get_player` that accepts LuaGuiElement and events containing `event.element` as a property.

### `Gui.toggle_enabled_state`

Toggles the enabled state of the passed LuaGuiElement.
It will return the new enabled state.

The second argument makes this `set_enabled_state`

### `Gui.toggle_visible_state`

Toggles the visible state of the passed LuaGuiElement.
It will return the new visible state.

The second argument makes this `set_visible_state`

### `destroy_if_valid`

Destories the passed LuaGuiElement.
Does nothing if the element is nil or an invalid reference.

### `Gui.add_top_element`

Registers an ExpElement to be drawn on the top flow.
The second argument is the default visible state, which can be a function.

### `Gui.add_left_element`

Registers an ExpElement to be drawn on the left flow.
The second argument is the default visible state, which can be a function.

### `Gui.add_relative_element`

Registers an ExpElement to be drawn relative to a core GUI.
The second argument is the default visible state, which can be a function.

The core gui is defined with `:draw{ anchor: GuiAnchor }`

### `Gui.get_top_element`

Returns the LuaGuiElement for the passed ExpElement.
Errors if the element is not registered to the top flow.

### `Gui.get_left_element`

Returns the LuaGuiElement for the passed ExpElement.
Errors if the element is not registered to the left flow.

### `Gui.get_relative_element`

Returns the LuaGuiElement for the passed ExpElement.
Errors if the element is not registered to the relative flow.

### `Gui._ensure_consistency`

If for any reason registered elements need to be redrawn, this method will handle it.
One example is updates within a custom permission system.

## Gui Data ([`data.lua`](../module/data.lua))

It is expected this file is required as `modules/exp_gui/data` and is assigned to the variable `GuiData`.

Alternativly, instances of GuiData exist on all ExpElements as `ExpElement.data`.

### `GuiData:__index`

No data is directly stored within an instance of GuiData, instead `__index` will be called and fetch the data from `GuiData._raw`.

Currently accepted indexes are: LuaGuiElement, LuaPlayer, LuaForce, and "global_data".

### `GuiData:__newindex`

No data is directly stored within an instance of GuiData, instead `__newindex` will be called and store the data in `GuiData._raw`.

Currently accepted indexes are: LuaGuiElement, LuaPlayer, LuaForce.
Setting "global_data" is not supported, although settings keys of "global_data" is permitted.

### `GuiData.create`

Creates a new instance of GuiData with a given scope.
Only a single instance can exist for any scope, use [`GuiData.get`](#guidataget) to retrive existing instances.

### `GuiData.get`

Retrives and existing instance of GuiData for a given scope.
Only use this if you have a circular dependency, otherwise you should be passing by reference.

## Gui Iter ([`iter.lua`](../module/iter.lua))

It is expected this file is required as `modules/exp_gui/iter` and is assigned to the variable `GuiIter`.

Alternativly, references to GuiIter exist on all ExpElements as `ExpElement:track_element`, `ExpElement:untrack_element`, `ExpElement:tracked_elements`, `ExpElement:online_elements`, and `ExpElement:track_all_elements`

### `GuiIter.player_elements`

Iterates all elements for a single player in a given scope.
The returned tupple is `LuaPlayer, LuaGuiElement`.

### `GuiIter.filtered_elements`

Iterates all elements for the provided players in a given scope.
The returned tupple is `LuaPlayer, LuaGuiElement`.

This method is named "filtered" because it is expected that the player list provided has been filtered on some condition and only elements for players in this list are returned.
The optional third argument can be provided to filter to online only if you have not done so yourself.

### `GuiIter.all_element`

Iterates all elements for all players in a given scope.
The returned tupple is `LuaPlayer, LuaGuiElement`.

### `GuiIter.get_tracked_elements`

Iterates all elements for all players in a given scope who pass the provided filter.
The returned tupple is `LuaPlayer, LuaGuiElement`.

The accepted filters are: nil, LuaPlayer, LuaPlayer[], and LuaForce.

Functions are NOT supported, instead pass an array of players you have pre-filtered.

### `GuiIter.get_online_elements`

Iterates all elements for online players in a given scope who pass the provided filter.
The returned tupple is `LuaPlayer, LuaGuiElement`.

The accepted filters are: nil, LuaPlayer, LuaPlayer[], and LuaForce.

Functions are NOT supported, instead pass an array of players you have pre-filtered.

### `GuiIter.add_element`

Adds an element to be tracked within a scope.
Elements can be tracked in multiple scopes.

### `GuiIter.remove_element`

Remove an element from a scope.
Does nothing if the element was not tracked.

Elements are automatically removed when destoryed.

## ExpElement ([`prototype.lua`](../module/prototype.lua))

It is expected this file is required as `modules/exp_gui/prototype` and is assigned to the variable `ExpElement`.

Alternativly, instances of ExpElement can be created with [`Gui.define`](#guidefine).

### `ExpElement.no_return`

It is used exclusively within `ExpElement:draw` to signal the intental lack of a return value.

Also accessible through [`Gui.no_return`](#guino_return)

### `ExpElement.from_name`

It is used within defiantion tables (draw, style, and data) to use a value from the defination name.

Also accessible through [`Gui.from_name`](#guifrom_name)

### `ExpElement.from_argument`

It is used within defiantion tables (draw, style, and data) to use a value from an argument.

The argument can be named or positional, and a default value can be provided.

Also accessible through [`Gui.from_argument`](#guifrom_argument)

### `ExpElement.new`

It creates new element definations.
The name provided must be unqiue to your mod.

Also accessible through [`Gui.define`](#guidefine)

### `ExpElement.get`

Gets the existing ExpElement with the given name.
Only use this if you have a circular dependency, otherwise you should be passing by reference.

### `ExpElement:create`

Creates a LuaGuiElement following the element defination.

Also accessible through `__call` allowing direct calls of this table to create an element.

Order of operations is: [draw](#expelementdraw), [style](#expelementstyle), [element_data](#expelementelement_data), [player_data](#expelementplayer_data), [force_data](#expelementforce_data), [global_data](#expelementglobal_data), [track_element](#expelementtrack_element), [link_element](#expelementlink_element).

### `ExpElement:track_all_elements`

When called, `ExpElement:track_element` will be called for all elements at the end of [`ExpElement:create`](#expelementcreate)

### `ExpElement:empty`

Defines [`ExpElement:draw`](#expelementdraw) as an empty flow.
This is intended to be used when you are first setting up the structure of your gui.
When used warnings will be logged, do not rely on this when you want an empty flow.

### `ExpElement:draw`

Defines the draw function for you element defination.
Successive calls will overwrite previous calls.

Accepts either a table to be passed to `LuaGuiElement.add` or a function that returns a LuaGuiElement.

### `ExpElement:style`

Defines the style function for you element defination.
Successive calls will overwrite previous calls.

Accepts either a table with key values equlaient to LuaStyle, or a function that can return this table, or [`ExpElement:from_argument`](#expelementfrom_argument).

### `ExpElement:element_data`

Defines the element data init function for you element defination.
Successive calls will overwrite previous calls.

Accepts any non-function value to deep copy, or a function that can return this value, or [`ExpElement:from_argument`](#expelementfrom_argument).

When a non-function value is used or returned, it will not overwrite existing data.
If you want this behaviour then modify the data directly in your function rather than returning a value.

### `ExpElement:player_data`

Defines the player data init function for you element defination.
Successive calls will overwrite previous calls.

Accepts any non-function value to deep copy, or a function that can return this value, or [`ExpElement:from_argument`](#expelementfrom_argument).

When a non-function value is used or returned, it will not overwrite existing data.
If you want this behaviour then modify the data directly in your function rather than returning a value.

### `ExpElement:force_data`

Defines the force data init function for you element defination.
Successive calls will overwrite previous calls.

Accepts any non-function value to deep copy, or a function that can return this value, or [`ExpElement:from_argument`](#expelementfrom_argument).

When a non-function value is used or returned, it will not overwrite existing data.
If you want this behaviour then modify the data directly in your function rather than returning a value.

### `ExpElement:global_data`

Defines the global data init function for you element defination.
Successive calls will overwrite previous calls.

Accepts only a table value to deep copy, or a function that can return a table, or [`ExpElement:from_argument`](#expelementfrom_argument).

When a table is used or returned, it will not overwrite existing data.
If you want this behaviour then modify the data directly in your function rather than returning a table.

### `ExpElement:tracked_elements`

A proxy call to [`GuiIter.get_tracked_elements`](#guiiterget_tracked_elements) with the scope pre-populated.

### `ExpElement:online_elements`

A proxy call to [`GuiIter.get_online_elements`](#guiiterget_online_elements) with the scope pre-populated.

### `ExpElement:track_element`

A proxy call to [`GuiIter.add_element`](#guiiteradd_element) with the scope pre-populated.

### `ExpElement:untrack_element`

A proxy call to [`GuiIter.remove_element`](#guiiterremove_element) with the scope pre-populated.

If returned from a draw function then [`ExpElement:track_all_elements`](#expelementtrack_all_elements) is ignored.

### `ExpElement:link_element`

Links an element to this define in order to trigger event handlers.

Should only be used to link additional elements because elements returned from draw are linked automatically.

### `ExpElement:unlink_element`

Unlinks an element from this define in order to prevent event handlers triggering.

If returned from a draw function then automatic linking will be prevented.

### `ExpElement:raise_event`

Raise an event on this define.

This can be useful for defering events to other definiations or for raising custom events.

### `ExpElement:on_event`

Allows connecting to arbitary events.
Multiple handlers are supported.

### `ExpElement:on_checked_state_changed`

Connects a handler to `defines.events.on_gui_checked_state_changed`.

### `ExpElement:on_click`

Connects a handler to `defines.events.on_gui_click`.

### `ExpElement:on_closed`

Connects a handler to `defines.events.on_gui_closed`.

### `ExpElement:on_confirmed`

Connects a handler to `defines.events.on_gui_confirmed`.

### `ExpElement:on_elem_changed`

Connects a handler to `defines.events.on_gui_elem_changed`.

### `ExpElement:on_hover`

Connects a handler to `defines.events.on_gui_hover`.

### `ExpElement:on_leave`

Connects a handler to `defines.events.on_gui_leave`.

### `ExpElement:on_location_changed`

Connects a handler to `defines.events.on_gui_location_changed`.

### `ExpElement:on_opened`

Connects a handler to `defines.events.on_gui_opened`.

### `ExpElement:on_selected_tab_changed`

Connects a handler to `defines.events.on_gui_selected_tab_changed`.

### `ExpElement:on_selection_state_changed`

Connects a handler to `defines.events.on_gui_selection_state_changed`.

### `ExpElement:on_switch_state_changed`

Connects a handler to `defines.events.on_gui_switch_state_changed`.

### `ExpElement:on_text_changed`

Connects a handler to `defines.events.on_gui_text_changed`.

### `ExpElement:on_value_changed`

Connects a handler to `defines.events.on_gui_value_changed`.

## Toolbar ([`toolbar.lua`](../module/toolbar.lua))

It is expected this file is required as `modules/exp_gui/toolbar` and is assigned to the variable `Toolbar`.

Alternativly, it can be accessed through `Gui.toolbar`.

A point of clarifcation, the "toolbar" in this framework refers to the top flow which may also be refered to as the "favoruites bar", while the "toolbox" is the custom gui for configruing the toolbar.

### `Toolbar.set_visible_state`

Sets the visible state of the toolbar for a player.

If a state is not given then this becomes `toggle_visible_state` and returns the new visible state.

The name difference compared to [`Gui.toggle_visible_state`](#guitoggle_visible_state) despite same beaviour is due to the expected use case for each function.

### `Toolbar.get_visible_state`

Gets the visible state of the toolbar for a player.

### `Toolbar.set_button_toggled_state`

Sets the toggled state for a toolbar button. It is expected that the element define is given not the LuaGuiElement because all instances of a toolbar button should be in sync, and the toolbar does not expose the LuaGuiElement except though [`Gui.get_top_element`](#guiget_top_element).

If a state is not given then this becomes `toggle_button_toggled_state` and returns the new visible state.

### `Toolbar.get_button_toggled_state`

Gets the toggled state for a toolbar button. It is expected that the element define is given not the LuaGuiElement because all instances of a toolbar button should be in sync, and the toolbar does not expose the LuaGuiElement except though [`Gui.get_top_element`](#guiget_top_element).

### `Toolbar.set_left_element_visible_state`

Sets the visible state for a left element. It is expected that the element define is given not the LuaGuiElement because only a single left element can exist, and the toolbar does not expose the LuaGuiElement except though [`Gui.get_left_element`](#guiget_left_element).

If a state is not given then this becomes `toggle_left_element_visible_state` and returns the new visible state.

### `Toolbar.get_left_element_visible_state`

Gets the visible state for a left element. It is expected that the element define is given not the LuaGuiElement because only a single left element can exist, and the toolbar does not expose the LuaGuiElement except though [`Gui.get_left_element`](#guiget_left_element).

### `Toolbar.has_visible_buttons`

Returns true if the player has any visible toolbar buttons.

### `Toolbar.has_visible_left_elements`

Returns true if the player has any visible left elements.

### `Toolbar.create_button`

Creates a new element define representing a toolbar button.

The new button is automaticaly registered to the top flow, has the option to auto toggle, and the option to have a left element linked to it. As this creates a new element define the name provided must be unqiue to your mod.

### `Toolbar.set_state`

Sets the whole state of the toolbar for a player, the value given should be a value previously returned from [`Toolbar.get_state`](#toolbarget_state).

### `Toolbar.get_state`

Gets the whol state of the toolbar for a player which can later be restored with [`Toolbar.set_state`](#toolbarset_state).
