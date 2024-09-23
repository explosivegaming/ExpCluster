--- This will make commands only work when a valid color from the presets has been selected
-- @config Commands-Color-Parse

local Commands = require 'expcore.commands' --- @dep expcore.commands
local Colours = require 'utils.color_presets' --- @dep utils.color_presets

Commands.add_parse('color',function(input, _, reject)
  if not input then return end
  local color = Colours[input]
  if not color then
    return reject{'expcore-commands.reject-color'}
  else
    return input
  end
end)