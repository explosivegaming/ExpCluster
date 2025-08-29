# Design motivation

This document outlines why I created this framework, and the reasoning behind some of the opinionated decisions that shaped its design.

The motivation came from my experience with existing libraries, which often enforced a strict separation between element definitions, event handling, and GUI-related data.
In many cases, these libraries focused solely on element creation, leaving developers to manually manage event filtering and data scoping themselves.

I found that approach cumbersome and unintuitive.
I believed there was a better way, one that embraced a different kind of encapsulation, making the conceptual model easier to understand and work with.
And so I created a framework with four distinct and independent parts that all come together with a sense of locality not seen in our libraries.

Additionally, the guide places greater emphasis on naming conventions and calling patterns, rather than just listing what each function does.
These conventions are key to how the framework is expected to be used and are intended to make development feel more cohesive and intuitive.

At the heart of the framework are four core concepts that bring everything together:

## ExpElement

ExpElement serves as the prototype for all element definitions.
It's intentionally designed as a wrapper around LuaGuiElement.add and associated event handlers.
It takes in definition tables and functions, and returns a function that can be used to create a LuaGuiElement.

This focused purpose makes it easier to reason about.
It also reduces boilerplate, allowing you to concentrate on functionality rather than repetitive setup.

You can optionally add methods to the definition, such as `add_row` or `refresh`.
While these could technically be local functions, including them directly in the definition makes it immediately clear which data they interact with or modify.
This enhances both readability and maintainability.

For example, the following two snippets are conceptually equivalent:

```lua
Elements.my_label = Gui.define("my_label")
    :draw{
        type = "label",
        caption = "Hello, World!",
    }
    :style{
        font_color = { r = 1, g = 0, b = 0 },
        width = Gui.from_argument(1),
    }
    :element_data{
        foo = "bar"
    }
    :on_click(function(def, player, element, event)
        element.caption = "Clicked!"
    end)

function Elements.my_label.reset(my_label)
    my_label.caption = "Hello, World!"
end
```

```lua
local my_label_data = GuiData.create("my_label")
function Elements.my_label(parent, width)
    -- :draw
    local element = parent.add{
        type = "label",
        caption = "Hello, World!",
    }

    -- :style
    local style = element.style
    style.font_color = { r = 1, g = 0, b = 0 }
    style.width = width

    -- :element_data
    my_label_data[element] = {
        foo = "bar"
    }

    -- event handlers
    local tags = element.tags or {}
    local event_tags = tags.event_tags or {}
    event_tags[#event_tags + 1] = "my_label"
    element.tags = tags

    return element
end

local function my_label_reset(my_label)
    my_label.caption = "Hello, World!"
end

local function on_gui_click(event)
    local element = event.element
    if is_my_label(element) then -- pseudo function to check event_tags
        element.caption = "Clicked!"
    end
end
```

In the example, I use table-style definitions, which are the most common approach for simple elements and are encouraged wherever possible.
Internally, these tables are converted into draw functions, which can also be passed directly if needed.

You could, of course, write everything into a single "create" function, or even place all logic inside a `:draw` method, but maintaining a separation between these responsibilities serves as a form of clear signposting.
This improves readability and makes the structure of your code easier to follow at a glance.

```lua
Elements.my_label = Gui.define("my_label")
    :draw(function(def, parent, width)
        return parent.add{
            type = "label",
            caption = "Hello, World!",
        }
    end)
    :style(function(def, element, parent, width)
        return {
            font_color = { r = 1, g = 0, b = 0 },
            width = width,
        }
    end)
    :element_data(function(def, element, parent, width)
        return {
            foo = "bar"
        }
    end)
    :on_click(function()
        print("Clicked!")
    end)
```

## GuiData

Building on the goal of keeping GUI data close to where it’s used and displayed, I introduced `GuiData`, which is integrated as `ExpElement.data`.
Like the other components, its purpose is focused and singular, and it can even be used standalone if it's the only part of the framework you find useful.

In simple terms, GuiData creates a table in `storage` with a custom `__index` metamethod that enables automatic scoping of data.
It also cleans up data when the associated key is destroyed, helping to reduce unnecessary memory usage.

One common use case, explained earlier in this guide, is storing references to other elements.
This approach removes the tight coupling between event handlers and the GUI structure by giving handlers direct access to what they need.

Additionally, it encourages you to make assumptions explicit by requiring references as arguments.
While this pattern can take some getting used to, it makes dependencies much easier to identify and reason about.

While this example exposes some of the internal mechanics, it should help you understand the convenience and clarity that scoped data access provides.

```lua
local data = GuiData.create("my_data")

-- data[element] = "foo"
storage.gui_data.scopes["my_data"].element_data[element.player_index][element.index] = "foo"

-- data[player] = "bar"
storage.gui_data.scopes["my_data"].player_data[player.index] = "bar"

-- data[force] = "baz"
storage.gui_data.scopes["my_data"].force_data[force.index] = "baz"
```

## GuiIter

With scoped data easily accessible, it became straightforward to track elements belonging to a specific player, especially for updates or state changes.
However, this pattern became so common (and often cluttered `GuiData`) that I created a dedicated iterator: `GuiIter`.

As with the other modules, GuiIter can be used independently if you like what it offers, or through its integration with ExpElement.

Whenever an element is created, or at any point, really, it can be registered with the iterator for future access.
Retrieval is then handled by applying a filter across all tracked elements, returning them one by one.
Don’t worry, the underlying data structure is designed for efficient lookup and automatic cleanup.

This can be incredibly powerful.
It gives you direct access to GUI elements without having to manually navigate from `player.gui`, and the filtering makes it simple to, for example, target only elements belonging to online players in a specific force.

Below is an example of how GuiIter can be used as a standalone utility:

```lua
local function teammate_counter(player)
    local frame = player.gui.left.add{ type = "frame" }
    local label = frame.add{ type = "label", caption = tostring(#player.force.players) }
    GuiIter.add_element("teammate_counter", label)
end

local function on_player_changed_force(event)
    local old_force = event.old_force
    local old_force_count = tostring(#old_force.players)
    for player, label in GuiIter.get_online_elements("teammate_counter", old_force) do
        label.caption = caption
    end

    local new_force = game.get_player(event.player_index).force
    local new_force_count = tostring(#new_force.players)
    for player, label in GuiIter.get_online_elements("teammate_counter", new_force) do
        label.caption = caption
    end
end
```

## Toolbar

While ExpElement ties individual components together into self-contained units, the Toolbar acts as a singleton that manages them all.
From an implementation standpoint, it’s split into two parts: one that handles drawing elements when a player joins, and an optional settings menu named "Toolbox".

The element-drawing functionality is the final piece of the puzzle for eliminating boilerplate and letting you focus on functionality.
You simply register an element at a given location, and it gets drawn automatically on player join, it really is that straightforward.

The optional settings menu provides a standardised way to manage button behaviour, while also giving players control over which buttons are visible.
This was born out of necessity: as the number of GUI modules grew, having all of them visible by default became overwhelming.
The settings menu solves that by letting players hide modules they don’t need.

![toolbox](./docs/toolbox.png)
