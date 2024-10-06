--- Allows the FAGC clientside bot to receive information about bans and unbans and propagate that information to other servers
-- @addon FAGC

local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event

local write_file = helpers.write_file

-- Clear the file on startup to minimize its size
Event.on_init(function()
    write_file("fagc-actions.txt", "", false, 0)
end)

Event.add(defines.events.on_player_banned, function(e)
    local text = "ban;" .. e.player_name .. ";" .. (e.by_player or "") .. ";" .. (e.reason or "") .. "\n"
    write_file("fagc-actions.txt", text, true, 0)
end)

Event.add(defines.events.on_player_unbanned, function(e)
    local text = "unban;" .. e.player_name .. ";" .. (e.by_player or "") .. ";" .. (e.reason or "") .. "\n"
    write_file("fagc-actions.txt", text, true, 0)
end)
