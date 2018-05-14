--[[
Explosive Gaming

This file can be used with permission but this and the credit below must remain in the file.
Contact a member of management on our discord to seek permission to use our code.
Any changes that you may make to the code are yours but that does not make the script yours.
Discord: https://discord.gg/r6dC2uK
]]
--Please Only Edit Below This Line-----------------------------------------------------------
-- this file will just contain all the diffrent requires

-- admin dir
require('Admin/player-info')
require('Admin/admin') -- used with Guis/admin-gui, but can work without
require('Admin/reports') -- this adds onto Admin/admin, adds report command and warnings, and temp ban
require('Admin/discord')
require('Admin/auto-message')
require('Admin/tree-decon')
require('Admin/inventory-search')
require('Admin/base-damage')
require('Admin/afk-kick')
require('Admin/auto-chat')

-- commands dir
require('Commands/cheat-mode')
require('Commands/kill')
require('Commands/repair')
require('Commands/bonus')
require('Commands/tags')
require('Commands/home')
require('Commands/tp') -- requires Admin/admin
require('Commands/admin') -- requires Admin/reports

-- guis dir
require('Guis/readme')
require('Guis/science')
require('Guis/rockets')
require('Guis/player-list')
require('Guis/tasklist')
require('Guis/warp-system')
require('Guis/polls') -- too many desyncs
require('Guis/announcements')
require('Guis/rank-changer')
require('Guis/admin-gui') -- used with Admin/admin, requires Admin/admin
require('Guis/reports') -- requires Admin/reports
require('Guis/game-settings')

-- other