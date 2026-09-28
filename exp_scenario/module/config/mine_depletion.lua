--- Settings for mine depletion
-- @config Mine-Depletion

local Features = require("modules/exp_scenario/features")

return Features.register("mine_depletion", {
    fluid = true, --- @setting fluid When true, checks for for fluid pipes when removing miners
    chest = true, --- @setting chest When true, checks for for chest when removing miners
    beacon = true, --- @setting beacon When true, checks for for beacon when removing miners
})
