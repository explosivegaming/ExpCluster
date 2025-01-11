
local ExpGui = require("modules/exp_gui")

local frame = ExpGui.element("test")
    :draw{
        type = "frame",
        caption = "Hello, World",
    }

ExpGui.add_left_element(frame, true)

ExpGui.create_toolbar_button{
    name = "test-button",
    left_element = frame,
    caption = "Test",
}
