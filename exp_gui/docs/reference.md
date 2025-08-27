# ExpGui API Reference

This is a streamlined version of the API reference, highlighting the methods you're most likely to use day-to-day.
It includes extra detail and practical examples to help you get up and running quickly.

If you haven’t already, we recommend starting with the [framework guide](../readme.md).
It lays the groundwork and gives you the context you’ll need to understand how these methods work together.

A [full reference](./reference_full.md) is also available.
But if you plan to rely on it, we strongly suggest reviewing and familiarizing yourself with the underlying implementation of the functions.

## Utility Functions

These helper methods are designed to simplify common tasks when working with GUI elements, like toggling states or safely destroying elements.

### `Gui.get_player`

Retrieves the player associated with a given context. This can be:

- A LuaGuiElement
- An event containing `event.player_index`
- An event containing `event.element`

The method includes a not-nil assertion to handle rare cases where a player might have become invalid.

### `Gui.toggle_*_state`

Refers to `Gui.toggle_enabled_state` and `Gui.toggle_visible_state`.

These functions toggle the specified state (either enabled or visible) for a LuaGuiElement, and return the new state after toggling.
If you provide a second argument (true or false), the function becomes `set_*_state` and sets the state directly instead of toggling.

Each function checks if the element is non-nil and still valid before performing any action.
If those checks fail, nothing happens.

### `Gui.destroy_if_valid`

Destroys a given LuaGuiElement, but only if it exists and is valid.

If either condition is not met, the function exits quietly without performing any action.

## Element Definations

This section covers how to define, register, and manage GUI elements using the framework.
These definitions form the foundation of how your GUI behaves, persists, and responds to player interaction.

### `Gui.define`

All GUI elements begin with a call to `Gui.define`, where you provide a unique name for your element.
This name only needs to be unique within your own mod or module.

When you're first setting up a GUI, you may not know its full structure right away.
In these cases, it can be useful to use `:empty()` child elements until you are ready to define them.

```lua
Elements.my_button = Gui.define("my_button")
    :empty()
```

### `Gui.add_*_element`

Refers to `Gui.add_top_element`, `Gui.add_left_element`, and `Gui.add_relative_element`.

These functions register a root element to a GUI flow, ensuring it’s created for all players when they join.
Once registered, the framework takes ownership of the element’s lifetime, guaranteeing that it always exists.

This makes them ideal entry points for GUIs that maintain persistent state.

You can retrieve the created instance using `Gui.get_*_element`, passing in the definition as the first argument.
From there, you can perform operations like [`Gui.toggle_visible_state`](#guitoggle__state) or apply custom logic.

If you're using the Toolbar or GuiIter, you likely won’t need to manually retrieve your element at all.
For example, the Toolbar provides convenience methods like [`Toolbar.get_left_element_visible_state`](#guitoolbarset_left_element_visible_state) and [`Toolbar.set_button_toggled_state`](#guitoolbarset_button_toggled_state), both of which accept your element definition directly.

### `ExpElement:draw`

When you're ready to define an element, the first required step is to call `:draw()`.

This method accepts either:

- A table that defines the GUI structure
- A function that returns a LuaGuiElement

Using a table is encouraged and it supports dynamic values via `Gui.from_argument`, allowing you to pass data through arguments easily.
While this doesn't cover every use case, it handles the majority of common needs.

```lua
Elements.my_label = Gui.define("my_label")
    :draw{
        caption = Gui.from_argument(1),
        style = "heading_2_label",
    }
```

For elements with many optional values, it's recommended to use an "options" table.
Simply provide named keys instead of using array indexes.
The options table is always assumed to be the final argument, so required values can still be passed by index.
You can also define default values.

```lua
Elements.my_camera = Gui.define("my_camera")
    :draw{
        surface_index = Gui.from_argument(1),
        position = Gui.from_argument("position", { 0, 0 }),
        zoom = Gui.from_argument("zoom"),
    }
```

When an element is a composite of other elements, i.e. it has children, then you need to use the function defination method.
This is because child elements may need arguments to be supplied to them which is more easily done in a function body rather than inventing a new table syntax.

Your draw function should always return the most "meaningful" LuaGuiElement, this can mean: the element that raises events, the element that children should be added to, or the root element for those registered to a gui flow (top / left / relative).
If multiple of these conditions apply to different children then you will need to look into manually calling `:link_element` for event handling or clearly document where children should be added by callers.
If none of these apply, then consider if you should be using an element defination at all, if you must then you can return `Gui.no_return`.

If your element is a composite (i.e. it contains child elements), then using a function is required.
This is because you may need to pass arguments to children which is more cleanly done in a function body rather than a complex table structure.

Your draw function should return the most “meaningful” LuaGuiElement. This might be:

- The element that raises GUI events
- The element where children should be added
- The root element registered to a GUI flow (top, left, or relative)

If these responsibilities apply to different children, you’ll need to either manually link elements to events using `:link_element` or document clearly where children should be added by callers.
If none of these conditions apply, consider whether a standalone element definition is appropriate.
If you still need one, you can return `Gui.no_return`.

```lua
Elements.my_frame = Gui.define("my_Frame")
    :draw(function(def, parent)
        local player = Gui.get_player(parent)
        local frame = parent.add{ type = "frame" }
        Elements.my_button(frame)
        Element.my_label(frame, "Hello, " .. player.name)
        Element.my_camera(frame, player.surface.index, {
            zoom = 0.5,
        })
        return frame
    end)

Elements.no_return = Gui.define("no_Return")
    :draw(function(def, parent)
        return Gui.no_return()
    end)
```

### `ExpElement:style`

This method defines the style of your element, and is very similar to `:draw`.
Styling is only applied to the element returned from `:draw`.

If you use a function to define styles, the signature is `fun(def, element, parent)`.

If you return a table from this function, it should mimic the structure of a LuaStyle object.
However, you are not required to return anything.
You can also apply styles directly to the element, which is useful for read-only properties like `LuaStyle.column_alignments`.

```lua
Elements.my_label_big = Gui.define("my_label_big")
    :draw{
        caption = Gui.from_argument(1),
        style = "heading_2_label",
    }
    :style{
        width = 400,
    }

Elements.right_aligned_numbers = Gui.define("right_aligned_numbers")
    :draw{
        caption = Gui.from_argument(1),
    }
    :style(function(def, element, parent, caption)
        return {
            width = 400,
            horizontal_align = tonumber(caption) and "right" or "left"
        }
    end)
```

### `ExpElement:*_data`

Refers to `ExpElement:element_data`, `ExpElement:player_data`, `ExpElement:force_data`, and `ExpElement:global_data`; standlone use of `GuiData` is not covered.

These methods initialize GUI-related data within your element definition.
You can access the data later through `ExpElement.data`, or more commonly as `def.data` in event handlers.

If you pass a non-function value, it will be deep-copied to create the initial data (if it does not already exist).

If you pass a function, it will be called to either mutate existing data or return a new value to be used as the inital data.

For complex data structures, especially those involving references to child elements, it’s often better to assign data directly inside your `:draw` method.
Keep in mind that initializers do not run until after `:draw` completes, so you cannot rely on data being in a consistent state during draw.

```lua
Elements.my_primaitve_data = Gui.define("my_primaitve_data")
    :empty()
    :element_data(0)

Elements.my_table_data = Gui.define("my_table_data")
    :empty()
    :element_data{
        count = 0,
    }

Elements.my_function_data = Gui.define("my_function_data")
    :empty()
    :element_data(function(def, element, parent)
        return {
            seed = math.random()
        }
    end)

Elements.shared_counter = Gui.define("shared_counter")
    :draw(function(def, parent)
        local player = Gui.get_player(parent)
        local count = def.data[player.force] or 0
        return parent.add{
            type = "button",
            caption = tostring(count),
        }
    end)
    :force_data(0)
    :on_click(function(def, player, element, event)
        local old_count = def.data[player.force]
        local new_count = old_count + 1
        def.data[player.force] = new_count
        element.caption = tostring(new_count)
    end)

Elements.composite = Gui.define("composite")
    :draw(function(def, parent)
        local frame = parent.add{ type = "frame" }      
        def.data[frame] = {
            shared_counter = Elements.shared_counter(frame),
            label = frame.add{ type = "label" },
        }
        return frame
    end)
```

### `ExpElement:on_*`

Refers to all gui events and `ExpElement:on_event` for other arbitary events.
Gui events are converted from `on_gui_` to `on_` for examplse `on_gui_clicked` to `on_clicked`.

These methods allow you to attach event handlers to your element definition.

For general `on_event` usage, there’s no extra filtering, the handler will be called when the event occurs.

For GUI-specific events, the handler is only called for linked elements.
Handlers are automatically linked to any element returned from `:draw`.
You can manually link other elements using `:link_element`.

If you want to prevent an element from being linked automatically, you can call and return `:unlink_element`.
However, needing to do this might suggest a misalignment in how your functions responsibilities are structured.
In the example below, it would be best practice to introduce `Elements.title_label` which has an `on_click` handler.

```lua
Elements.my_clickable_button = Gui.define("my_clickable_button")
    :draw{
        type = "button",
        caption = "Click Me",
    }
    :on_click(function(def, player, element, event)
        player.print("Clicked!")
    end)

Elements.my_clickable_title = Gui.define("my_clickable_title")
    :draw(function(def, parent)
        local frame = parent.add{ type = "frame" }
        local title = frame.add{ type = "label", caption = "Click Me" }
        def:link_element(title)
        return def:unlink_element(frame)
    end)
    :on_click(function(def, player, element, event)
        player.print("The title was clicked!")
    end)
```

### `ExpElement:track_all_elements`

The most common use of the GUI iterator is to track all created elements.
Therefore `track_all_elements` was added which will track every element that is returned from your draw function.
You can also manually track additional elements with `:track_element`, and you can exclude elements from tracking using `:untrack_element`.

```lua
Elements.my_tracked_label = Gui.define("my_tracked_label")
    :track_all_elements()
    :draw{
        type = "label",
        caption = "Im tracked by GuiIter",
    }

Element.my_tracked_children = Gui.define("my_tracked_children")
    :draw(function(def, parent)
        local frame = parent.add{ type = "frame" }
        def:track_element(frame.add{ type = "label", caption = "Im tracked 1" })
        def:track_element(frame.add{ type = "label", caption = "Im tracked 2" })
        def:track_element(frame.add{ type = "label", caption = "Im tracked 3" })
        return frame
    end)

Elements.my_sometimes_tracked_label = Gui.define("my_sometimes_tracked_label")
    :track_all_elements()
    :draw(function(def, parent)
        local player = Gui.get_player(parent)
        if player.admin then
            return parent.add{ type = "label", caption = "Im tracked" }
        end
        return def:untrack_element(parent.add{ type = "label", caption = "Im tracked" })
    end)
```

## Gui Iterator

Refers to `ExpElement:tracked_elements` and `ExpElement:online_elements`; standalone use of `GuiIter` is not covered.

Once an element has been tracked using `:track_all_elements` or `:track_element`, it can be iterated over using these custom GUI iterators.
Each method accepts an optional filter parameter, which can be: LuaPlayer, LuaForce, or an array of LuaPlayer.
As their names suggest, `:tracked_elements` returns all tracked elements while `:online_elements` limits the results to online players only.

If you're caching data per force, it is more efficient to use a single unfiltered iteration rather than multiple filtered ones.

The naming convention to be followed is:

- `refresh` when the first argument is an instance of the element.
- `refresh_all` when there using `:tracked_elements` without a filter.
- `refresh_online` when there using `:online_elements` without a filter.
- `refresh_*` when there using `:tracked_elements` with a filter, e.g. `refresh_force`.
- `refresh_*_online` when there using `:online_elements` with a filter, e.g. `refresh_force_online`.
- `update` can be used when the new state is dependend on the old state, e.g. incrementing a counter.
- `reset` can be used when the element has a default state it can be returned to.
- `save` can be used when the current state is stored in some way.
- `*_row` when the action applies to a row within a table rather than an element.
- The name does not indicate if a cache is used, this is because a cache should be used where possible.

```lua
function Elements.my_tracked_label.calculate_force_data(force)
    return {
        caption = "I was refreshed: " .. force.name,
    }
end

function Elements.my_tracked_label.refresh_all()
    for player, element in Elements.my_tracked_label:tracked_elements() do
        element.caption = "I was refreshed"
    end
end

function Elements.my_tracked_label.refresh_online()
    for player, element in Elements.my_tracked_label:online_elements() do
        element.caption = "I was refreshed: online"
    end
end

function Elements.my_tracked_label.refresh_force(force)
    local force_data = Elements.my_tracked_label.calculate_force_data(force)
    for player, element in Elements.my_tracked_label:tracked_elements(force) do
        element.caption = force_data.caption
    end
end

-- a different implimention of refresh all with a force cache
function Elements.my_tracked_label.refresh_all()
    local _force_data = {}
    for _, force in pairs(game.forces) do
        _force_data[force.name] = Elements.my_tracked_label.calculate_force_data(force)
    end

    for player, element in Elements.my_tracked_label:tracked_elements() do
        local force_data = _force_data[player.force.name]
        element.caption = force_data.caption
    end
end

-- a different implimention of refresh online with a force cache
function Elements.my_tracked_label.refresh_online()
    local _force_data = {}
    for _, force in pairs(game.forces) do
        if next(force.connected_players) then
            _force_data[force.name] = Elements.my_tracked_label.calculate_force_data(force)
        end
    end

    for player, element in Elements.my_tracked_label:online_elements() do
        local force_data = _force_data[player.force.name]
        element.caption = force_data.caption
    end
end
```

## Toolbar

The toolbar API provides convenience methods for adding toggleable buttons and syncing them with GUI elements in the left flow.
This is especially useful for building persistent interfaces.

### `Gui.toolbar.create_button`

Creates a new button on the toolbar, with the option to link it to an element defined in the left flow.

This method also creates a new element definition for the button, so the provided name must be unique within your mod or module.
You can attach event handlers (such as `on_click` or `on_button_toggled`) to the button as needed.

If a left-side element definition is provided, the button is automatically set to toggle the visibility of that element when clicked.

The button type is set automatically based on the presence of a `sprite` option.
If `sprite` is defined, it creates a sprite button; otherwise, a standard button is used.

```lua
Gui.toolbar.create_button{
    name = "click_me",
    caption = "Click Me!",
}
:on_click(function(def, player, element, event)
    player.print("Clicked!")
end)

Elements.toggle_me =
    Gui.toolbar.create_button{
        name = "toggle_me",
        caption = "Toggle Me!",
        auto_toggle = true,
    }
    :on_button_toggled(function(def, player, element, event)
        player.print("I am now: " .. event.state)
    end)

Gui.add_left_element(Elements.my_frame)
Gui.toolbar.create_button{
    name = "toggle_my_frame",
    caption = "Toggle Me!",
    left_element = Elements.my_frame,
}
```

### `Gui.toolbar.set_button_toggled_state`

Sets the toggled state of a toolbar button, keeping it in sync with a linked left-side element if one is defined.
The element definition must have been previously returned by `create_button`.
If a state argument is not given then this becomes `toggle_button_toggled_state`.
This method does not raise `on_click`; instead, it raises `on_button_toggled`

```lua
Gui.toolbar.set_button_toggled_state(Elements.toggle_me, true)
```

### `Gui.toolbar.set_left_element_visible_state`

Sets the visibility state of a left-flow GUI element, and updates the state of a linked toolbar button if one is defined.
The element definition must have been previously passed to `Gui.add_left_element`.
If a state argument is not given then this becomes `toggle_left_element_visible_state`.
When a toolbar button is linked, this method also raises `on_button_toggled` for that button to reflect the change.

```lua
Gui.toolbar.set_button_toggled_state(Elements.my_frame, true)
```
