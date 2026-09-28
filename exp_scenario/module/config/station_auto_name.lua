--- Settings for naming train stations when they are built
-- @config Station-Auto-Name

local Features = require("modules/exp_scenario/features")

return Features.register("station_auto_name", {
    --[[
        __icon__
        __item_name__
        __backer_name__
        __direction__
        __x__
        __y__
    ]]
    station_name = "[L] __icon__", --- @setting station_name the name given to new stations, uses the placeholders above
})
