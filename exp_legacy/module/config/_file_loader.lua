--- This contains a list of all files that will be loaded and the order they are loaded in;
-- to stop a file from loading add "--" in front of it, remove the "--" to have the file be loaded;
-- config files should be loaded after all modules are loaded;
-- core files should be required by modules and not be present in this list;
-- @config File-Loader
return {
    "expcore.player_data", -- must be loaded first to register event handlers

    --- Addons
    "modules.addons.chat-popups",
    "modules.addons.damage-popups",
    "modules.addons.death-logger",
    "modules.addons.advanced-start",
    "modules.addons.spawn-area",
    "modules.addons.compilatron",
    "modules.addons.scorched-earth",
    "modules.addons.pollution-grading",
    "modules.addons.station-auto-name",
    "modules.addons.discord-alerts",
    "modules.addons.chat-reply",
    "modules.addons.tree-decon",
    "modules.addons.afk-kick",
    "modules.addons.report-jail",
    "modules.addons.protection-jail",
    "modules.addons.deconlog",
    "modules.addons.nukeprotect",
    "modules.addons.inserter",
    "modules.addons.miner",
    "modules.addons.logging",

    -- Control
    "modules.control.vlayer",

    --- Data
    "modules.data.statistics",
    "modules.data.player-colours",
    "modules.data.greetings",
    "modules.data.quickbar",
    "modules.data.alt-view",
    "modules.data.tag",
    -- 'modules.data.bonus',
    "modules.data.personal-logistic",
    "modules.data.language",
    --"modules.data.toolbar",

    --- GUI
    "modules.gui.readme",
    "modules.gui.rocket-info",
    "modules.gui.science-info",
    "modules.gui.autofill",
    "modules.gui.task-list",
    "modules.gui.warp-list",
    "modules.gui.player-list",
    "modules.gui.server-ups",
    "modules.gui.bonus",
    "modules.gui.vlayer",
    "modules.gui.research",
    "modules.gui.module",
    "modules.gui.landfill",
    "modules.gui.tool",
    "modules.gui.production",
    "modules.gui.playerdata",
    "modules.gui.surveillance",
    "modules.gui._role_updates",

    "modules.graftorio.require", -- graftorio
    --- Config Files
    "config.expcore.permission_groups", -- loads some predefined permission groups
    "config.expcore.roles", -- loads some predefined roles
}
