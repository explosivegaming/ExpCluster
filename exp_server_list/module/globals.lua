--- @diagnostic disable: global-in-non-module

-- Access using `/sc exp_server_list.foo()`
exp_server_list = require("modules/exp_server_list/control")
