--- @class Gui
local Gui = require("modules/exp_gui")

--- @class Gui.elements
local Elements = {}
Gui.elements = Elements

--- @class Gui.elements.aligned_flow.opts
--- @field horizontal_align ("left" | "center" | "right")?
--- @field vertical_align ("top" | "center" | "bottom")?

--- A flow which aligns its content as specified
--- @class Gui.elements.aligned_flow: ExpElement
--- @overload fun(parent: LuaGuiElement, opts: Gui.elements.aligned_flow.opts?): LuaGuiElement
Elements.aligned_flow = Gui.define("aligned_flow")
    :draw{
        type = "flow",
        name = Gui.from_argument("name"),
    }
    :style(function(def, element, parent, opts)
        opts = opts or {} --- @cast opts Gui.elements.aligned_flow.opts
        local vertical_align = opts.vertical_align or "center"
        local horizontal_align = opts.horizontal_align or "right"
        return {
            padding = { 1, 2 },
            vertical_align = vertical_align,
            horizontal_align = horizontal_align,
            vertically_stretchable = vertical_align ~= "center",
            horizontally_stretchable = horizontal_align ~= "center",
        }
    end) --[[ @as any ]]

--- A solid horizontal white bar element
--- @class Gui.elements.bar: ExpElement
--- @overload fun(parent: LuaGuiElement, width: number?): LuaGuiElement
Elements.bar = Gui.define("bar")
    :draw{
        type = "progressbar",
        value = 1,
    }
    :style(function(def, element, parent, width)
        --- @cast width number?
        local style = element.style
        style.color = { r = 255, g = 255, b = 255 }
        style.height = 4
        if width then
            style.width = width
        else
            style.horizontally_stretchable = true
        end
    end) --[[ @as any ]]

--- A label which is centered
--- @class Gui.elements.centered_label: ExpElement
--- @overload fun(parent: LuaGuiElement, width: number, caption: LocalisedString, tooltip: LocalisedString?): LuaGuiElement
Elements.centered_label = Gui.define("centered_label")
    :draw{
        type = "label",
        caption = Gui.from_argument(2),
        tooltip = Gui.from_argument(3),
    }
    :style{
        horizontal_align = "center",
        single_line = false,
        width = Gui.from_argument(1),
    } --[[ @as any ]]

--- A label which has two white bars on either side of it
--- @class Gui.elements.title_label: ExpElement
--- @overload fun(parent: LuaGuiElement, width: number, caption: LocalisedString, tooltip: LocalisedString?): LuaGuiElement
Elements.title_label = Gui.define("title_label")
    :draw(function(def, parent, width, caption, tooltip)
        --- @cast width number
        --- @cast caption LocalisedString
        --- @cast tooltip LocalisedString?
        local flow = parent.add{
            type = "flow"
        }

        flow.style.vertical_align = "center"

        Elements.bar(flow, width)

        local label = flow.add{
            type = "label",
            style = "frame_title",
            caption = caption,
            tooltip = tooltip,
        }

        Elements.bar(flow)

        return label
    end) --[[ @as any ]]

--- A fixed size vertical scroll pane
--- @class Gui.elements.scroll_pane: ExpElement
--- @overload fun(parent: LuaGuiElement, maximal_height: number, name: string?): LuaGuiElement
Elements.scroll_pane = Gui.define("scroll_pane")
    :draw{
        type = "scroll-pane",
        name = Gui.from_argument(2),
        direction = "vertical",
        horizontal_scroll_policy = "never",
        vertical_scroll_policy = "auto",
        style = "scroll_pane_under_subheader",
    }
    :style{
        padding = { 1, 3 },
        maximal_height = Gui.from_argument(1),
        horizontally_stretchable = true,
    } --[[ @as any ]]

--- A fixed size vertical scroll pane containing a table
--- @class Gui.elements.scroll_table: ExpElement
--- @overload fun(parent: LuaGuiElement, maximal_height: number, column_count: number, scroll_name: string?): LuaGuiElement
Elements.scroll_table = Gui.define("scroll_table")
    :draw(function(def, parent, maximal_height, column_count, scroll_name)
        --- @cast maximal_height number
        --- @cast column_count number
        --- @cast scroll_name string?
        local scroll_pane = Elements.scroll_pane(parent, maximal_height, scroll_name)

        return scroll_pane.add{
            type = "table",
            name = "table",
            column_count = column_count,
        }
    end)
    :style{
        padding = { 3, 2 },
        cell_padding = 1,
        vertical_align = "center",
        horizontally_stretchable = true,
    } --[[ @as any ]]

--- A container frame
--- @class Gui.elements.container: ExpElement
--- @overload fun(parent: LuaGuiElement, minimal_width: number?, name: string?): LuaGuiElement
Elements.container = Gui.define("container")
    :draw(function(def, parent, minimal_width, name)
        --- @cast minimal_width number?
        --- @cast name string?
        local container = parent.add{
            type = "frame",
            name = name,
        }

        container.style.padding = 2

        return container.add{
            type = "frame",
            name = "frame",
            direction = "vertical",
            style = "inside_shallow_frame_packed",
        }
    end)
    :style{
        vertically_stretchable = false,
        horizontally_stretchable = false,
        minimal_width = Gui.from_argument(1),
    } --[[ @as any ]]

--- Get the root element of a container
--- @param container LuaGuiElement
--- @return LuaGuiElement
function Elements.container.get_root_element(container)
    return container.parent
end

--- A frame within a container
--- @class Gui.elements.subframe_base: ExpElement
--- @overload fun(parent: LuaGuiElement, style: string, name: string?): LuaGuiElement
Elements.subframe_base = Gui.define("container_subframe")
    :draw{
        type = "frame",
        name = Gui.from_argument(2),
        style = Gui.from_argument(1),
    }
    :style{
        height = 0,
        minimal_height = 36,
        padding = { 3, 6, 0, 6 },
        use_header_filler = false,
        horizontally_stretchable = true,
    } --[[ @as any ]]

--- @class Gui.elements.header.opts
--- @field name string?
--- @field caption LocalisedString?
--- @field tooltip LocalisedString?

--- A header frame within a container
--- @class Gui.elements.header: ExpElement
--- @field label LuaGuiElement
--- @overload fun(parent: LuaGuiElement, opts: Gui.elements.header.opts?): LuaGuiElement
Elements.header = Gui.define("container_header")
    :draw(function(def, parent, opts)
        opts = opts or {} --- @cast opts Gui.elements.header.opts
        local subframe = Elements.subframe_base(parent, "subheader_frame", opts.name)

        if opts.caption then
            subframe.add{
                type = "label",
                name = "label",
                caption = opts.caption,
                tooltip = opts.tooltip,
                style = "frame_title",
            }
        end

        subframe.add{ type = "empty-widget" }.style.horizontally_stretchable = true

        return subframe
    end) --[[ @as any ]]

--- @class Gui.elements.footer.opts
--- @field name string?
--- @field caption LocalisedString?
--- @field tooltip LocalisedString?

--- A footer frame within a container
--- @class Gui.elements.footer: ExpElement
--- @field label LuaGuiElement
--- @overload fun(parent: LuaGuiElement, opts: Gui.elements.footer.opts?): LuaGuiElement
Elements.footer = Gui.define("container_footer")
    :draw(function(def, parent, opts)
        opts = opts or {} --- @cast opts Gui.elements.footer.opts
        local subframe = Elements.subframe_base(parent, "subfooter_frame", opts.name)

        if opts.caption then
            subframe.add{
                type = "label",
                name = "label",
                caption = opts.caption,
                tooltip = opts.tooltip,
                style = "frame_title",
            }
        end

        subframe.add{ type = "empty-widget" }.style.horizontally_stretchable = true

        return subframe
    end) --[[ @as any ]]

--- A button used to destroy its target when clicked, intended for screen frames
--- @class Gui.elements.screen_frame_close: ExpElement
--- @field data table<LuaGuiElement, LuaGuiElement>
--- @overload fun(parent: LuaGuiElement, target: LuaGuiElement): LuaGuiElement
Elements.screen_frame_close = Gui.define("screen_frame_close")
    :draw{
        type = "sprite-button",
        style = "frame_action_button",
        sprite = "utility/close",
    }
    :element_data(
        Gui.from_argument(1)
    )
    :on_click(function(def, player, element, event)
        --- @cast def Gui.elements.screen_frame_close
        Gui.destroy_if_valid(def.data[element])
    end) --[[ @as any ]]

--- A draggable frame with close button and button flow
--- @class Gui.elements.screen_frame: ExpElement
--- @field data table<LuaGuiElement, LuaGuiElement?>
--- @overload fun(parent: LuaGuiElement, caption: LocalisedString?, button_flow: boolean?): LuaGuiElement
Elements.screen_frame = Gui.define("screen_frame")
    :draw(function(def, parent, caption, button_flow)
        local container = parent.add{
            type = "frame",
            direction = "vertical",
        }
        container.style.padding = 2

        local header = container.add{
            type = "flow",
        }

        if caption then
            local label = header.add{
                type = "label",
                caption = caption,
                style = "frame_title"
            }
            label.style.top_margin = -3
            label.style.bottom_padding = 3
        end

        local filler = header.add{
            type = "empty-widget",
            style = "draggable_space_header",
        }

        filler.drag_target = container
        local filler_style = filler.style
        filler_style.horizontally_stretchable = true
        filler_style.vertically_stretchable = true
        filler_style.left_margin = caption and 4 or 0
        filler_style.natural_height = 24
        filler_style.height = 24

        if button_flow then
            local _button_flow = header.add{ type = "flow" }
            def.data[container] = _button_flow
            _button_flow.style.padding = 0
        end

        Elements.screen_frame_close(header, container)

        return container.add{
            type = "frame",
            direction = "vertical",
            style = "inside_shallow_frame_packed",
        }
    end) --[[ @as any ]]

--- Get the button flow for a screen frame
--- @param screen_frame LuaGuiElement
--- @return LuaGuiElement
function Elements.screen_frame.get_button_flow(screen_frame)
    return assert(Elements.screen_frame.data[screen_frame.parent], "Screen frame has no button flow")
end

--- Get the root element of a screen frame
--- @param screen_frame LuaGuiElement
--- @return LuaGuiElement
function Elements.screen_frame.get_root_element(screen_frame)
    return screen_frame.parent
end

return Elements
