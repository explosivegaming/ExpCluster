--[[-- Control - Roles
Applies the in game effects of the player permissions defined by the scenario
]]

local Gui = require("modules/exp_gui")
local Roles = require("modules/exp_roles")

Roles.define_permission_trigger("exp_scenario.player.admin", function(player, state)
    player.admin = state
end)


return {
    events = {
        --- @diagnostic disable-next-line: access-invisible
        [Roles.events.on_player_roles_changed] = Gui._ensure_consistency,
    }
}
