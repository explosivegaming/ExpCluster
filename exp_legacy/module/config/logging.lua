--- Settings for logging
-- @config logging

return {
    file_name = "log/logging.log",
    rocket_launch_display = {
        [1] = true,
        [2] = true,
        [5] = true,
        [10] = true,
        [20] = true,
        [50] = true,
        [100] = true,
        [200] = true,
    },
    rocket_launch_display_rate = 500,
    disconnect_reason = {
        [defines.disconnect_reason.quit] = "left the game",
        [defines.disconnect_reason.dropped] = "was dropped from the game",
        [defines.disconnect_reason.reconnect] = "is reconnecting",
        [defines.disconnect_reason.wrong_input] = "was having a wrong input",
        [defines.disconnect_reason.desync_limit_reached] = "had desync limit reached",
        [defines.disconnect_reason.cannot_keep_up] = "cannot keep up",
        [defines.disconnect_reason.afk] = "was afk",
        [defines.disconnect_reason.kicked] = "was kicked",
        [defines.disconnect_reason.kicked_and_deleted] = "was kicked and deleted",
        [defines.disconnect_reason.banned] = "was banned",
        [defines.disconnect_reason.switching_servers] = "is switching servers",
    },
}
