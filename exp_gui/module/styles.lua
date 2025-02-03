--- @class ExpGui
local ExpGui = require("modules/exp_gui")

--- @class ExpGui.styles
local styles = {}
ExpGui.styles = styles

function styles.sprite(style)
    style = style or {}
    if not style.padding then
        style.padding = -2
    end
    return style
end

return styles
