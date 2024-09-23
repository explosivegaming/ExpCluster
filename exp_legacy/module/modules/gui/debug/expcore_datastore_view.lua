local Gui = require 'utils.gui' --- @dep utils.gui
local Datastore = require 'expcore.datastore' --- @dep expcore.datastore
local Color = require 'utils.color_presets' --- @dep utils.color_presets
local Model = require 'modules.gui.debug.model' --- @dep modules.gui.debug.model

local dump = Model.dump
local concat = table.concat

local Public = {}

local header_name = Gui.uid_name()
local left_panel_name = Gui.uid_name()
local right_panel_name = Gui.uid_name()
local input_text_box_name = Gui.uid_name()
local refresh_name = Gui.uid_name()

Public.name = 'Datastore'

function Public.show(container)
    local main_flow = container.add {type = 'flow', direction = 'horizontal'}

    local left_panel = main_flow.add {type = 'scroll-pane', name = left_panel_name}
    local left_panel_style = left_panel.style
    left_panel_style.width = 300

    for name in pairs(table.keysort(Datastore.debug())) do
        local header = left_panel.add({type = 'flow'}).add {type = 'label', name = header_name, caption = name}
        Gui.set_data(header, name)
    end

    local right_flow = main_flow.add {type = 'flow', direction = 'vertical'}

    local right_top_flow = right_flow.add {type = 'flow', direction = 'horizontal'}

    local input_text_box = right_top_flow.add {type = 'text-box', name = input_text_box_name}
    local input_text_box_style = input_text_box.style
    input_text_box_style.horizontally_stretchable = true
    input_text_box_style.height = 32
    input_text_box_style.maximal_width = 1000

    local refresh_button =
        right_top_flow.add {type = 'sprite-button', name = refresh_name, sprite = 'utility/reset', tooltip = 'refresh'}
    local refresh_button_style = refresh_button.style
    refresh_button_style.width = 32
    refresh_button_style.height = 32

    local right_panel = right_flow.add {type = 'text-box', name = right_panel_name}
    right_panel.read_only = true
    right_panel.selectable = true

    local right_panel_style = right_panel.style
    right_panel_style.vertically_stretchable = true
    right_panel_style.horizontally_stretchable = true
    right_panel_style.maximal_width = 1000
    right_panel_style.maximal_height = 1000

    local data = {
        right_panel = right_panel,
        input_text_box = input_text_box,
        selected_header = nil
    }

    Gui.set_data(input_text_box, data)
    Gui.set_data(left_panel, data)
    Gui.set_data(refresh_button, data)
end

Gui.on_click(
    header_name,
    function(event)
        local element = event.element
        local tableName = Gui.get_data(element)

        local left_panel = element.parent.parent
        local data = Gui.get_data(left_panel)
        local right_panel = data.right_panel
        local selected_header = data.selected_header
        local input_text_box = data.input_text_box

        if selected_header then
            selected_header.style.font_color = Color.white
        end

        element.style.font_color = Color.orange
        data.selected_header = element

        input_text_box.text = tableName
        input_text_box.style.font_color = Color.black

        local content = Datastore.debug(tableName)
        local content_string = {}
        for key, value in pairs(content) do
            content_string[#content_string+1] = key:gsub('^%l', string.upper)..' = '..dump(value)
        end
        right_panel.text = concat(content_string, '\n')
    end
)

local function update_dump(text_input, data)
    local content = Datastore.debug(text_input.text)
    local content_string = {}
    for key, value in pairs(content) do
        content_string[#content_string+1] = key:gsub('^%l', string.upper)..' = '..dump(value)
    end
    data.right_panel.text = concat(content_string, '\n')
end

Gui.on_text_changed(
    input_text_box_name,
    function(event)
        local element = event.element
        local data = Gui.get_data(element)

        update_dump(element, data)
    end
)

Gui.on_click(
    refresh_name,
    function(event)
        local element = event.element
        local data = Gui.get_data(element)

        local input_text_box = data.input_text_box

        update_dump(input_text_box, data)
    end
)

return Public
