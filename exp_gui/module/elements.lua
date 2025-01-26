--- @class ExpGui
local ExpGui = require("modules/exp_gui")

--- @class ExpGui.elements
local elements = {}
ExpGui.elements = elements

--- A flow which aligns its content as specified
elements.aligned_flow = ExpGui.element("aligned_flow")
    :draw{
        type = "flow",
        name = ExpGui.property_from_arg("name"),
    }
    :style(function(def, element, parent, opts)
        opts = opts or {}
        local vertical_align = opts.vertical_align or "center"
        local horizontal_align = opts.horizontal_align or "right"
        return {
            padding = { 1, 2 },
            vertical_align = vertical_align,
            horizontal_align = horizontal_align,
            vertically_stretchable = vertical_align ~= "center",
            horizontally_stretchable = horizontal_align ~= "center",
        }
    end)

--- A solid horizontal white bar element
elements.bar = ExpGui.element("bar")
    :draw{
        type = "progressbar",
        value = 1,
    }
    :style(function(def, element, parent, width)
        local style = element.style
        style.color = { r = 255, g = 255, b = 255 }
        style.height = 4
        if width then
            style.width = width
        else
            style.horizontally_stretchable = true
        end
    end)

--- A label which is centered
elements.centered_label = ExpGui.element("centered_label")
    :draw{
        type = "label",
        caption = ExpGui.property_from_arg(2),
        tooltip = ExpGui.property_from_arg(3),
    }
    :style{
        horizontal_align = "center",
        single_line = false,
        width = ExpGui.property_from_arg(1),
    }

--- A label which has two white bars on either side of it
elements.title_label = ExpGui.element("title_label")
    :draw(function(def, parent, width, caption, tooltip)
        local flow =
            parent.add{
                type = "flow"
            }
            
        flow.style.vertical_align = "center"
        elements.bar(flow, width)

        local label =
            flow.add{
                type = "label",
                style = "frame_title",
                caption = caption,
                tooltip = tooltip,
            }

        elements.bar(flow)

        return label
    end)

--- A fixed size vertical scroll pane
elements.scroll_pane = ExpGui.element("scroll_pane")
    :draw{
        type = "scroll-pane",
        name = ExpGui.property_from_arg(2),
        direction = "vertical",
        horizontal_scroll_policy = "never",
        vertical_scroll_policy = "auto",
        style = "scroll_pane_under_subheader",
    }
    :style{
        padding = { 1, 3 },
        maximal_height = ExpGui.property_from_arg(1),
        horizontally_stretchable = true,
    }

--- A fixed size vertical scroll pane containing a table
elements.scroll_table = ExpGui.element("scroll_table")
    :draw(function(def, parent, height, column_count, scroll_name)
        local scroll_pane = elements.scroll_pane(parent, height, scroll_name)

        return scroll_pane.add{
            type = "table",
            name = "table",
            column_count = column_count,
        }
    end)
    :style{
        padding = 0,
        cell_padding = 0,
        vertical_align = "center",
        horizontally_stretchable = true,
    }

--- A container frame
elements.container = ExpGui.element("container")
    :draw(function(def, parent, width, container_name)
        local container =
            parent.add{
                type = "frame",
                name = container_name,
            }

        local style = container.style
        style.horizontally_stretchable = false
        style.minimal_width = width
        style.padding = 2

        return container.add{
            type = "frame",
            name = "frame",
            direction = "vertical",
            style = "inside_shallow_frame_packed",
        }
    end)
    :style{
        vertically_stretchable = false,
    }

--- A frame within a container
elements.subframe_base = ExpGui.element("container_subframe")
    :draw{
        type = "frame",
        name = ExpGui.property_from_arg(2),
        style = ExpGui.property_from_arg(1),
    }
    :style{
        height = 0,
        minimal_height = 36,
        padding = { 3, 4 },
        use_header_filler = false,
        horizontally_stretchable = true,
    }

--- A header frame within a container
elements.header = ExpGui.element("container_header")
    :draw(function(def, parent, opts)
        opts = opts or {}
        local subframe = elements.subframe_base(parent, "subheader_frame", opts.name)

        if opts.caption then
            subframe.add{
                type = "label",
                name = opts.label_name,
                caption = opts.caption,
                tooltip = opts.tooltip,
                style = "frame_title",
            }
        end

        return opts.no_flow and subframe or elements.aligned_flow(subframe, { name = "flow" })
    end)

--- A footer frame within a container
elements.footer = ExpGui.element("container_footer")
    :draw(function(def, parent, opts)
        opts = opts or {}
        local subframe = elements.subframe_base(parent, "subfooter_frame", opts.name)

        if opts.caption then
            subframe.add{
                type = "label",
                name = opts.label_name,
                caption = opts.caption,
                tooltip = opts.tooltip,
                style = "frame_title",
            }
        end

        return opts.no_flow and subframe or elements.aligned_flow(subframe, { name = "flow" })
    end)

return elements
