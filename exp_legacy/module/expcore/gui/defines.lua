--[[-- Core Module - Gui
- Common defines that are used by other modules, non of these are used internally
@module Gui
]]

local Gui = require 'expcore.gui.prototype'

--- Defines.
-- @section defines

--[[-- Draw a flow used to align its child elements, default is right align
@element Gui.alignment
@tparam LuaGuiElement parent the parent element to which the alignment will be added
@tparam[opt='alignment'] string name the name of the alignment flow which is added
@tparam[opt='right'] string horizontal_align the horizontal alignment of the elements in the flow
@tparam[opt='center'] string vertical_align the vertical alignment of the elements in the flow
@treturn LuaGuiElement the alignment flow that was created

@usage-- Adding a right align flow
local alignment = Gui.alignment(element, 'example_right_alignment')

@usage-- Adding a horizontal center and top align flow
local alignment = Gui.alignment(element, 'example_center_top_alignment', 'center', 'top')

]]
Gui.alignment =
Gui.element(function(_, parent, name, _,_)
    return parent.add{
        name = name or 'alignment',
        type = 'flow',
    }
end)
:style(function(style, _,_, horizontal_align, vertical_align)
    style.padding = {1, 2}
    style.vertical_align = vertical_align or 'center'
    style.horizontal_align = horizontal_align or 'right'
    style.vertically_stretchable  = style.vertical_align ~= 'center'
    style.horizontally_stretchable = style.horizontal_align ~= 'center'
end)

--[[-- Draw a scroll pane that has a table inside of it
@element Gui.scroll_table
@tparam LuaGuiElement parent the parent element to which the scroll table will be added
@tparam number height the maximum height for the scroll pane
@tparam number column_count the number of columns that the table will have
@tparam[opt='scroll'] string name the name of the scroll pane that is added, the table is always called "table"
@treturn LuaGuiElement the table that was created

@usage-- Adding a scroll table with max height of 200 and column count of 3
local scroll_table = Gui.scroll_table(element, 200, 3)

]]
Gui.scroll_table =
Gui.element(function(_, parent, height, column_count, name)
    -- Draw the scroll
    local scroll_pane =
    parent.add{
        name = name or 'scroll',
        type = 'scroll-pane',
        direction = 'vertical',
        horizontal_scroll_policy = 'never',
        vertical_scroll_policy = 'auto',
        style = 'scroll_pane_under_subheader'
    }

    -- Set the style of the scroll pane
    local scroll_style = scroll_pane.style
    scroll_style.padding = {1, 3}
    scroll_style.maximal_height = height
    scroll_style.horizontally_stretchable = true

    -- Draw the table
    local scroll_table =
    scroll_pane.add{
        type = 'table',
        name = 'table',
        column_count = column_count
    }

    -- Return the scroll table
    return scroll_table
end)
:style{
    padding = 0,
    cell_padding = 0,
    vertical_align = 'center',
    horizontally_stretchable = true
}

--[[-- Used to add a frame with the header style, has the option for a right alignment flow for buttons
@element Gui.header
@tparam LuaGuiElement parent the parent element to which the header will be added
@tparam ?string|Concepts.LocalizedString caption the caption that will be shown on the header
@tparam[opt] ?string|Concepts.LocalizedString tooltip the tooltip that will be shown on the header
@tparam[opt=false] boolean add_alignment when true an alignment flow will be added to the header
@tparam[opt='header'] string name the name of the header that is being added, the alignment is always called "alignment"
@treturn LuaGuiElement either the header or the header alignment if add_alignment is true

@usage-- Adding a custom header with a label
local header = Gui.header(
    element,
    'Example Caption',
    'Example Tooltip'
)

]]
Gui.header =
Gui.element(function(_, parent, caption, tooltip, add_alignment, name, label_name)
    -- Draw the header
    local header =
    parent.add{
        name = name or 'header',
        type = 'frame',
        style = 'subheader_frame'
    }

    -- Change the style of the header
    local style = header.style
    style.padding = {2, 4}
    style.use_header_filler = false
    style.horizontally_stretchable = true

    -- Draw the caption label
    if caption then
        header.add{
            name = label_name or 'header_label',
            type = 'label',
            style = 'heading_1_label',
            caption = caption,
            tooltip = tooltip
        }
    end

    -- Return either the header or the added alignment
    return add_alignment and Gui.alignment(header) or header
end)

--[[-- Used to add a frame with the footer style, has the option for a right alignment flow for buttons
@element Gui.footer
@tparam LuaGuiElement parent the parent element to which the footer will be added
@tparam ?string|Concepts.LocalizedString caption the caption that will be shown on the footer
@tparam[opt] ?string|Concepts.LocalizedString tooltip the tooltip that will be shown on the footer
@tparam[opt=false] boolean add_alignment when true an alignment flow will be added to the footer
@tparam[opt='footer'] string name the name of the footer that is being added, the alignment is always called "alignment"
@treturn LuaGuiElement either the footer or the footer alignment if add_alignment is true

@usage-- Adding a custom footer with a label
local footer = Gui.footer(
    element,
    'Example Caption',
    'Example Tooltip'
)

]]
Gui.footer =
Gui.element(function(_, parent, caption, tooltip, add_alignment, name)
    -- Draw the header
    local footer =
    parent.add{
        name = name or 'footer',
        type = 'frame',
        style = 'subfooter_frame'
    }

    -- Change the style of the footer
    local style = footer.style
    style.padding = {2, 4}
    style.use_header_filler = false
    style.horizontally_stretchable = true

    -- Draw the caption label
    if caption then
        footer.add{
            name = 'footer_label',
            type = 'label',
            style = 'heading_1_label',
            caption = caption,
            tooltip = tooltip
        }
    end

    -- Return either the footer or the added alignment
    return add_alignment and Gui.alignment(footer) or footer
end)

--[[-- Used for left frames to give them a nice boarder
@element Gui.container
@tparam LuaGuiElement parent the parent element to which the container will be added
@tparam string name the name that you want to give to the outer frame, often just event_trigger
@tparam number width the minimal width that the frame will have

@usage-- Adding a container as a base
local container = Gui.container(parent, 'my_container', 200)

]]
Gui.container =
Gui.element(function(_, parent, name, _)
    -- Draw the external container
    local frame =
    parent.add{
        name = name,
        type = 'frame'
    }

    -- Return the container
    return frame.add{
        name = 'container',
        type = 'frame',
        direction = 'vertical',
        style = 'window_content_frame_packed'
    }
end)
:style(function(style, element, _,width)
    style.vertically_stretchable = false
    local frame_style = element.parent.style
    frame_style.padding = 2
    frame_style.minimal_width = width
end)

--[[-- Used to make a solid white bar in a gui
@element Gui.bar
@tparam LuaGuiElement parent the parent element to which the bar will be added
@tparam number width the width of the bar that will be made, if not given bar will strech to fill the parent

@usage-- Adding a bar to a gui
local bar = Gui.bar(parent, 100)

]]
Gui.bar =
Gui.element(function(_, parent)
    return parent.add{
        type = 'progressbar',
        size = 1,
        value = 1
    }
end)
:style(function(style, _,width)
    style.height = 3
    style.color = {r=255, g=255, b=255}
    if width then style.width = width
    else style.horizontally_stretchable = true end
end)

--[[-- Used to make a label which is centered and of a certian size
@element Gui.centered_label
@tparam LuaGuiElement parent the parent element to which the label will be added
@tparam number width the width of the label, must be given in order to center the caption
@tparam ?string|Concepts.LocalizedString caption the caption that will be shown on the label
@tparam[opt] ?string|Concepts.LocalizedString tooltip the tooltip that will be shown on the label

@usage-- Adding a centered label
local label = Gui.centered_label(parent, 100, 'This is centered')

]]
Gui.centered_label =
Gui.element(function(_, parent, width, caption, tooltip)
    local label = parent.add{
        type = 'label',
        caption = caption,
        tooltip = tooltip,
        style = 'description_label'
    }

    local style = label.style
    style.horizontal_align = 'center'
    style.single_line = false
    style.width = width

    return label
end)

--[[-- Used to make a title which has two bars on either side
@element Gui.title_label
@tparam LuaGuiElement parent the parent element to which the label will be added
@tparam number width the width of the first bar, this can be used to position the label
@tparam ?string|Concepts.LocalizedString caption the caption that will be shown on the label
@tparam[opt] ?string|Concepts.LocalizedString tooltip the tooltip that will be shown on the label

@usage-- Adding a centered label
local label = Gui.centered_label(parent, 100, 'This is centered')

]]
Gui.title_label =
Gui.element(function(_, parent, width, caption, tooltip)
    local title_flow = parent.add{ type='flow' }
    title_flow.style.vertical_align = 'center'

    Gui.bar(title_flow, width)
    local title_label = title_flow.add{
        type = 'label',
        caption = caption,
        tooltip = tooltip,
        style = 'heading_1_label'
    }
    Gui.bar(title_flow)

    return title_label
end)