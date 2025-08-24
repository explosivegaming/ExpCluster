# ExpGui Framework Guide

This guide presents best practices for creating GUIs in Factorio and demonstrates how the ExpGui framework can help streamline development.
If you’re new to GUI creation in Factorio, we recommend starting with [Therenas' helpful tutorial](https://github.com/ClaudeMetz/UntitledGuiGuide/wiki) to build a solid foundation.
We also recommend [Raiguard's style guide](https://man.sr.ht/~raiguard/factorio-gui-style-guide/) if you are looking to mimic the design principles employed by the game's own guis.

Additional details for the methods available in this library can be found in the [api reference](./docs/reference.md).

All examples in this guide assume you are using popular VSCode extensions for Factorio development, such as FMTK (`justarandomgeek.factoriomod-debug`) and LuaLs (`sumneko.lua`).

## Glossary

- "element": A `LuaGuiElement` instance representing a GUI component in Factorio.
- "element definition": An instance of `ExpElement` containing the details and logic for creating a GUI element.
- "element method": A custom method added to an element definition, the first argument should be a LuaGuiElement belonging to the definition.
- "gui event handler": A function called in response to a GUI-specific event (e.g., button click).
- "event handler": A function called in response to any event occurring in the game.
gui data: Persistent data stored and accessed by GUI event handlers, typically linked to specific elements.
- "pre-defined element": An element provided by the framework that includes built-in styles and layout logic for common GUI patterns.
- "draw function": A function defined within an element definition that constructs and returns the corresponding `LuaGuiElement`.
- "draw table": A plain Lua table used as a shorthand for a draw function, typically employed when no dynamic logic or nested elements are required.
- "toolbar": A shared GUI area for displaying module buttons, often positioned at the top-left of the screen.
- "cache": Temporarily stored computed data used to avoid repeated expensive calculations; cached variables are often prefixed with an underscore to indicate they should not be accessed directly.

### Naming conventions

- `Elements`: A common local variable name used to store returned element definitions from a GUI module, capitalised to avoid shadowing more generic variable names like `elements`.
- `Elements.container`: A common name for the variable holding the root element definition, especially when registering it to be drawn on the left flow.
- `scroll_table`: A built-in composite element in the framework designed to display tabular data with scrolling support.
- `calculate`: A method that generates the data required to draw or refresh GUI elements.
- `refresh`: A method that updates the GUI elements to reflect the current data without fully reconstructing the interface.
- `link`: A method used to associate elements with data or other elements after initial creation.
- `row_elements`: A lua table containing all elements in a row of a gui table.
- `row_data`: A lua table containing all data required to draw or refresh a row of a table.
- `add_row`: A method added to table element definitions that appends a single row based on provided data.
- `tooltip-`: Prefix used for locale string keys to indicate their intended display location, improving clarity and organisation. Others include `caption-` and `error-`

## The boiler plate

### Tip 1: Use `event_handler.add_lib`

When working with multiple GUI modules, it's a good practice to use `event_handler.add_lib` to register them.
This approach helps avoid conflicts between event handlers and makes it easier to scale your mod's interface across different components.
`event_handler` is a core lualib provided by factorio, it's full path is `__core__.lualib.event_handler` but should be required as `event_handler`

The ExpGui framework relies on this same mechanism to register your GUI event handlers, so following this pattern ensures compatibility and consistency.

By organising your code into libraries and registering them via add_lib, you also improve modularity; making it easier to reason about each part of your GUI separately and debug issues when they arise.

```lua
local add_lib = require("event_handler").add_lib
add_lib(require("modules/your_module/gui_foo"))
```

### Tip 2: Return your element definitions

Each GUI module should return its element definitions as part of its public interface.
Doing so offers two major advantages:

- It makes debugging easier; you can inspect the associated GUI data stored for each element definition, which helps track down issues with state or layout.
- It allows your definitions to be reused across other modules, encouraging modularity and reducing duplication.

Following both Tip 1 and Tip 2 gives you a clean boilerplate structure for starting any GUI module.
In most cases, the returned definitions are assigned to a local variable named `Elements` (capitalised).
This helps avoid naming conflicts with local variables like `elements`, which are commonly used within the same scope.

```lua
local ExpUtil = require("modules/exp_util")
local Gui = require("modules/exp_gui")

--- @class ExampleGui.elements
local Elements = {}

local e = defines.events
return {
    elements = Elements,
    events = {

    },
    on_nth_tick = {

    },
}
```

## Creating a root element

### Tip 3: Register a single root element definition to be drawn when a player is created.

Most GUI modules are built around a single root element; an element that contains all other child elements and acts as the entry point to your interface.

In typical usage, you’ll want this root element to be created automatically when a new player joins the game because it allows for a persistent GUI state.
Manually creating it in your own `on_player_created` handler can lead to redundant code and inconsistency.

Instead, the framework provides a way to register your root element definition, and it will handle drawing it for every newly created player.
This ensures the element is always present and your GUI state is initialised properly without extra boilerplate.

To create a new element definition you should call `Gui.define` with the name of your element, this name must be unique within your mod.
In the below example `Elements.container` is defined, this will be expanded in the next tip as all defines should have a draw method rather than using empty.

```lua
--- The root element of the example gui
Elements.container = Gui.define("container")
    :empty()

--- Add the element to the left flow with it hidden by default
Gui.add_left_element(Elements.container, false)
```

### Tip 4: Use pre-defined elements as a starting point

The framework includes several [pre defined elements](./module/elements.lua) that help maintain a consistent appearance and layout across GUI modules.
These elements simplify the process of creating common interface structures while encouraging visual consistency throughout your mod.

When using a pre defined element, or when defining your own element that contains other elements, you should include a `draw` method in the element definition.
This method is responsible for building the GUI structure at runtime.
The return value is used by the framework to attach event handlers and track elements, after which it is given to the caller.

For left side frames, such as in the example module, the `container` element is a good place to start.
It provides a standard layout that works well for persistent side panels.

```lua
Elements.container = Gui.define("container")
    :draw(function(def, parent)
        -- def is self reference to the element definition
        -- parent is where you should add your new element

        -- to create an element you call its definition passing a parent element
        local container = Gui.elements.container(parent)

        -- header is another common pre-defined element, footer exists too
        -- note, adding custom draw arguments will be covered later
        local header = Gui.elements.header(container, {
            caption = { "example-gui.caption-main" }
        })

        -- for elements registered to be drawn on join, the root element should be returned
        -- note that container.parent ~= parent because container is a composite element
        return container.parent
    end)
```

### Tip 5: Use the toolbar for buttons

The framework includes a shared toolbar that allows GUI modules to register buttons in a consistent and user friendly way. These buttons follow a standard style and layout, helping your interface stay visually unified across modules.
The toolbar also supports player customisation via the toolbox.
Players can choose which buttons are visible and rearrange their order according to personal preference.

![toolbox](./docs/toolbox.png)

A toolbar button does not require a `left_element`, but if one is provided, the framework will automatically register an `on_click` handler.
This handler toggles the visibility of the named element.
You can optionally define a `visible` function as part of the button definition.
This function is called when the button is first drawn and determines whether a specific player is allowed to see the button.

```lua
Gui.toolbar.create_button{
    name = "toggle_example_gui",
    sprite = "item/iron-plate",
    tooltip = { "example-gui.tooltip-main" },
    left_element = Elements.container,
    visible = function(player, element)
        -- this button will only be visible to admins
        return player.admin
    end,
}
```

## Receiving user input

### Tip 6: For simpler elements use draw tables

If an element does not contain any child elements and all of its properties are static, you can define it using a draw table instead of a full function.

A draw table is simply a Lua table that describes the structure and properties of a single GUI element.
The framework automatically converts this into a draw function internally, making it a convenient shorthand for simple elements.
A direct comparison of the two can be found in the [motivation section](#1-expelement).

This approach helps reduce boilerplate and improves readability when creating basic buttons, labels, flows, or other standalone GUI elements.

### Tip 7: Table definitions also work for applying styles

Styles can be applied to an element using the `:style(function(def, parent, element) end)` method.
However, for simpler elements like buttons and labels, you can also define the style directly as a table.

This shorthand approach allows you to include static style properties (such as font, padding, or alignment) in the same table format used to define the element itself.
It helps keep simple element definitions concise and easy to read.

### Tip 8: Use gui event handler methods

Instead of writing separate event handlers and manually routing events, you can define GUI event handler methods directly on your element definitions.
The framework will automatically register these methods and filter incoming events, calling the correct handler based on the element involved.

This approach simplifies your code by keeping the event logic close to the element it concerns.
It also reduces boilerplate and improves maintainability by leveraging the framework’s built-in event dispatch system.

All gui event handlers are supported following the naming convention of `on_gui_click` -> `on_click`

```lua
Elements.example_button = Gui.define("example_button")
    :draw{
        caption = "Hi",
        tooltip = { "example-gui.tooltip-example-button" },
        -- string styles are applied during draw
        style = "shortcut_bar_button",
    }
    :style{
        size = 24,
    }
    :on_click(function(def, player, element, event)
        player.print("Hello, World!")
    end)

-- within Elements.container:draw
Elements.example_button(header)
```

## Displaying data

### Tip 9: Scroll tables are your friend

Displaying data in a scrollable table is a common GUI pattern, and this framework includes a pre defined composite element specifically for this purpose.

In the upcoming examples, you will see type annotations used with the element definitions.
These annotations are necessary due to limitations in LuaLS, including the explicit type casts (using as) used to help the language server correctly interpret overloaded functions.

```lua
--- @class ExpGui_Example.elements.display_table: ExpElement
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.display_table = Gui.define("display_table")
    :draw(function(def, parent)
        -- 2nd arg is max vertical size, 3rd arg is column count
        return Gui.elements.scroll_table(parent, 200, 3)
    end) --[[ @as any ]]
```

### Tip 10: Separate data calculation and drawing

To avoid repeating code, it’s best to calculate the data you want to display in a separate function from the one that creates the row elements.

This separation makes your code cleaner and more modular.
It also allows you to reuse the calculated data in other methods such as `refresh`, where the GUI needs to update without rebuilding everything from scratch.

The return type of this function will typically be a collection of locale strings and other values that will be displayed in your GUI.
For tables, this should be named `row_data` but other elements can include their name such as `example_button_data` or more specific details like `team_data`.
The value should then be passed to create or refresh an element or table row, tip 14 has an example of this.

```lua
--- @class Elements.display_table.row_data
--- @field name string
--- @field sprite string
--- @field caption LocalisedString
--- @field count number

--- @param inventory LuaInventory
--- @param item_name string
--- @return Elements.display_table.row_data
function Elements.display_table.calculate_row_data(inventory, item_name)
    return {
        name = item_name,
        sprite = "item/" .. item_name,
        name = { "item-name." .. item_name },
        count = inventory.get_item_count(item_name)
    }
end
```

### Tip 11: Use a function to add rows rather than an element define

Element definitions are intended for creating single elements or composite elements with a clear structure.
When they are used to create multiple rows in tables, managing data ownership and state can become confusing.

To keep your code clean and your data flow clear, it’s recommended to extend your table element definition with an `add_row` method.
This method handles adding new rows one at a time, keeping row creation logic separate from element definition and making it easier to manage dynamic content.
Tip 14 shows an example of `add_row` being used within the container draw function.

### Tip 12: Store row elements in gui data

When adding elements to a row, you will often need to reference those elements later for updates or interaction.

To manage this, use gui data to store references to these elements.
The framework provides a convenient initialiser method, `:element_data{}`, which creates an empty table at `def.data[element]`.
This table can be used to store per-row GUI element references or other related data.

For good encapsulation, it is best practice to access gui data only within the methods of the element definition it belongs to.
This keeps your data management organised and reduces the risk of unintended side effects.

```lua
--- @class Elements.display_table.row_elements
--- @field sprite LuaGuiElement
--- @field label_name LuaGuiElement
--- @field label_count LuaGuiElement

--- @param display_table LuaGuiElement
--- @param row_data Elements.display_table.row_data
function Elements.display_table.add_row(display_table, row_data)
    local rows = Elements.display_table.data[display_table]
    assert(rows[row_data.name] == nil, "Row already exists")

    local visible = row_data.count > 0
    rows[row_data.name] = {
        sprite = display_table.add{
            type = "sprite",
            sprite = row_data.sprite,
            visible = visible
        },
        label_name = display_table.add{
            type = "label",
            caption = row_data.name,
            visible = visible
        },
        label_count = display_table.add{
            type = "label",
            caption = tostring(row_data.count),
            visible = visible
        },
    }
end
```

## Refreshing displayed data

### Tip 13: Use 'refresh' functions to optimise updates

Instead of clearing and rebuilding the entire table every time it changes, it’s more efficient to update the existing GUI elements directly.

To keep your code clean and modular, place this update logic inside a `refresh` function.
This function adjusts the current elements to match the new data state without unnecessary reconstruction.
You may also encounter variants like `refresh_all` or `refresh_online` to indicate different scopes or contexts for the update.

```lua
--- @param display_table LuaGuiElement
--- @param row_data Elements.display_table.row_data
function Elements.display_table.refresh_row(display_table, row_data)
    local row = assert(Elements.display_table.data[display_table][row_data.name])
    row.label_count.caption = tostring(row_data.count)

    local visible = row_data.count > 0
    for _, element in pairs(row) do
        element.visible = visible
    end
end
```

### Tip 14: Pass references rather than names

Instead of using element names to identify GUI elements, it’s better to pass direct references to those elements whenever possible.
Using references reduces the impact of GUI restructuring and improves performance by avoiding lookups.
However, be cautious not to use references to elements that might be destroyed, as this can lead to invalid references and crashes.

To maintain encapsulation and avoid tight coupling, passing references often means you’ll need to design your methods to accept custom arguments explicitly.
For example, updating a button’s event handler to receive element references directly rather than traversing the GUI tree.

```lua
--- @class ExpGui_Example.elements.example_button: ExpElement
--- @field data table<LuaGuiElement, LuaGuiElement>
--- @overload fun(parent: LuaGuiElement, display_table: LuaGuiElement): LuaGuiElement
Elements.example_button = Gui.define("example_button")
    :draw{
        caption = "Refresh",
        tooltip = { "example-gui.tooltip-example-button" },
        style = "shortcut_bar_button",
    }
    :style{
        size = 24,
    }
    :element_data(
        -- Set the element data to the first argument given
        Gui.from_argument(1)
    )
    :on_click(function(def, player, element, event)
        --- @cast def ExpGui_Example.elements.example_button
        local display_table = def.data[element]
        for _, item_name in pairs{ "iron-place", "copper-plate", "coal", "stone" } do
            local row_data = Elements.display_table.calculate_row_data(inventory, item_name)
            Elements.display_table.refresh(display_table, row_data)
        end
    end) --[[ @as any ]]

-- within Elements.container:draw
local inventory = Gui.get_player(container).get_main_inventory()
local display_table = Elements.display_table(container)
for _, item_name in pairs{ "iron-place", "copper-plate", "coal", "stone" } do
    local row_data = Elements.display_table.calculate_row_data(inventory, item_name)
    Elements.display_table.add_row(display_table, row_data)
end

Elements.example_button(header, display_table)
```

### Tip 15: Use the custom gui iterator to optimise refreshes

When your data requires frequent updates, whether triggered by events or on every nth game tick, it’s efficient to use the framework’s custom GUI iterator.
This iterator filters and returns only the specific elements that need refreshing, reducing unnecessary work.

To enable this, you must tell your element definition which GUI elements to track.
In most cases, calling `:track_all_elements()` is sufficient to track all relevant elements automatically.

For updates that happen every nth tick, it’s better to use `:online_elements()` instead of `:tracked_elements()`.
The `online_elements()` iterator returns only elements associated with players currently online, which helps avoid updating GUI elements for disconnected players unnecessarily.

```lua
--- @param event EventData.on_player_main_inventory_changed
local function on_player_main_inventory_changed(event)
    local player = assert(game.get_player(event.player_index))
    for _player, display_table in Elements.display_table:tracked_elements(player) do
        for _, item_name in pairs{ "iron-place", "copper-plate", "coal", "stone" } do
            local row_data = Elements.display_table.calculate_row_data(inventory, item_name)
            Elements.display_table.refresh(display_table, row_data)
        end
    end
end
```

## Miscellaneous

### Tip 16: Don't set sizes and instead use horizontally stretchable

Rather than explicitly setting fixed sizes on GUI elements, it is better to leave sizes undetermined and enable the horizontally stretchable property on the appropriate elements within your GUI.
You don’t need to set this property on every element, only on those that are at the deepest level of your GUI hierarchy where flexible spacing is required.

A common and effective use case is employing stretchable empty widgets to create flexible space between elements.
This approach leads to cleaner, more adaptive layouts that adjust gracefully to different languages.

### Tip 17: Cache data where possible

If the data you display is common to all players on a force or surface, it’s best to cache this data rather than recalculating it for each player individually.

You can store cached data as a local variable within a `refresh_all` function to limit its scope and lifetime. Alternatively, if you’re confident in your data management, you may cache it in a higher scope to reuse across multiple refresh cycles.
Be cautious when caching in higher scopes, as improper management can lead to desyncs issues between players.

```lua
function Elements.unnamed_element.refresh_all()
    local force_data = {}
    for player, unnamed_element in Elements.unnamed_element:online_elements() do 
        local force = player.force --[[ @as LuaForce ]]
        local element_data = force_data[force.name] or Elements.unnamed_element.calculate_data(force)
        force_data[force.name] = element_data
        Elements.unnamed_element.refresh(unnamed_element, element_data)
    end
end
```

```lua
local _force_data = {}
function Elements.here_be_desyncs.get_data(force)
    local data = _force_data[force.name] or Elements.here_be_desyncs.calculate_data(force)
    _force_data[force.name] = data
    return data
end
```

### Tip 18: Use named arguments when many are optional

For elements like `header` that have many optional arguments, it is better to provide those arguments as named values in a table rather than relying on positional order.
This can be done by passing a string key to `Gui.from_argument("key_name", default_value)`, which treats the final argument as a table of named parameters.

Positional arguments still support default values, but using named arguments improves readability and reduces errors when many options are involved.

```lua
--- @class ExpGui_Example.elements.label: ExpElement
--- @overload fun(parent: LuaGuiElement, opts: { caption: string?, width: number? }): LuaGuiElement
Elements.label = Gui.define("label")
    :draw{
        caption = Gui.from_argument("caption"),
    }
    :style{
        width = Gui.from_argument("width", 25),
    } --[[ @as any ]]
```

### Tip 19: Use force and player data within gui data

GUI data is not limited to just individual elements—you can also store and share data at the force or player level.
This allows multiple elements to access common data relevant to a specific player or force, improving consistency and reducing duplication.
Using force and player scoped gui data helps manage state effectively across complex interfaces.

All GUI data initialisers also accept functions, similar to the `:style` method, enabling you to define dynamic starting states that can change based on the current context.

```lua
:force_data{
    clicked_time = 0,
    clicked_by = "No one."
}
:on_click(function(def, player, element, event)
    local force = player.force --[[ @as LuaForce ]]
    local force_data = def.data[force]
    force_data.clicked_time = event.tick
    force_data.clicked_by = player.name
end)
```

### Tip 20: Have clear data ownership

Store GUI data in the highest-level element definition where it is needed, then pass references to child elements.
This allows children to access and modify the shared data as necessary while keeping ownership clear and centralized.

```lua
-- on the settings button
:element_data(
    Gui.from_argument(1)
)

-- on the parent
:draw(function(def, parent)
    local player = Gui.get_player(parent)
    local player_data = def.data[player] or {}
    def.data[player] = player_data

    local flow = parent.add{ type = "flow" }
    for _, setting in pairs(player_data) do
        Elements.settings_button(flow, setting)
    end
end)
```

Sometimes, due to the order in which elements are drawn, passing references at creation time isn’t possible.
In these cases, a `link` method should be used after creation to connect child elements together.
It’s also common to pass a table of elements that can be populated incrementally, helping to manage collections of related GUI components cleanly.

```lua
-- on toggle_enabled
:on_click(function(def, player, element, event)
    --- @cast def ExpGui_Example.elements.toggle_enabled
    local other_element = def.data[element]
    if other_element then
        other_element.enabled = not other_element.enabled
    end
end)

function Elements.toggle_enabled.link_element(toggle_enabled, other_element)
    Elements.toggle_enabled.data[toggle_enabled] = other_element
end

-- on the parent
:draw(function(def, parent)
    local flow = parent.add{ type = "flow" }
    local toggle_enabled = Elements.toggle_enabled(flow)
    local other_button = Elements.other_button(flow)
    Elements.toggle_enabled.link_element(toggle_enabled, other_button)
end)
```

## Design motivation

This section outlines why I created this framework, and the reasoning behind some of the opinionated decisions that shaped its design.

The motivation came from my experience with existing libraries, which often enforced a strict separation between element definitions, event handling, and GUI-related data.
In many cases, these libraries focused solely on element creation, leaving developers to manually manage event filtering and data scoping themselves.

I found that approach cumbersome and unintuitive.
I believed there was a better way—one that embraced a different kind of encapsulation, making the conceptual model easier to understand and work with.
And so I created a framework with four distinct parts that all come together with a sense of locality not seen in our libraries.

Additionally, this guide places greater emphasis on naming conventions and calling patterns, rather than just listing what each function does.
These conventions are key to how the framework is expected to be used and are intended to make development feel more cohesive and intuitive.

At the heart of the framework are four core concepts that bring everything together:

### 1. ExpElement

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

### 2. GuiData

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

### 3. GuiIter

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

### 4. Toolbar

While ExpElement ties individual components together into self-contained units, the Toolbar acts as a singleton that manages them all.
From an implementation standpoint, it’s split into two parts: one that handles drawing elements when a player joins, and an optional settings menu named "Toolbox".

The element-drawing functionality is the final piece of the puzzle for eliminating boilerplate and letting you focus on functionality.
You simply register an element at a given location, and it gets drawn automatically on player join, it really is that straightforward.

The optional settings menu provides a standardised way to manage button behaviour, while also giving players control over which buttons are visible.
This was born out of necessity: as the number of GUI modules grew, having all of them visible by default became overwhelming.
The settings menu solves that by letting players hide modules they don’t need.

![toolbox](./docs/toolbox.png)
