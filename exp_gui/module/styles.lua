--- @class Gui
local Gui = require("modules/exp_gui")

--- @class Gui.styles
local styles = {}
Gui.styles = styles

function styles.sprite(style)
    style = style or {}
    if not style.padding then
        style.padding = -2
    end
    return style
end

return styles
