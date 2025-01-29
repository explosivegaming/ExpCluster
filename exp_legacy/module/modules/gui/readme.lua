--[[-- Gui Module - Readme
    - Adds a main gui that contains lots of important information about our server
    @gui Readme
    @alias readme
]]

local ExpUtil = require("modules/exp_util")
local Gui = require("modules/exp_gui")
local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event
local Roles = require("modules.exp_legacy.expcore.roles") --- @dep expcore.roles
local Commands = require("modules/exp_commands") --- @dep expcore.commands
local PlayerData = require("modules.exp_legacy.expcore.player_data") --- @dep expcore.player_data
local External = require("modules.exp_legacy.expcore.external") --- @dep expcore.external
local format_number = require("util").format_number --- @dep util

local tabs = {}
local function define_tab(caption, tooltip, element_define)
    tabs[#tabs + 1] = { caption, tooltip, element_define }
end

local frame_width = 595 -- controls width of top descriptions
local title_width = 270 -- controls the centering of the titles
local scroll_height = 275 -- controls the height of the scrolls

--- Sub content area used within the content areas
local sub_content = Gui.element("readme_sub_content")
    :draw{
        type = "frame",
        direction = "vertical",
        style = "inside_deep_frame",
    }
    :style{
        horizontally_stretchable = true,
        horizontal_align = "center",
        padding = { 2, 2 },
        top_margin = 2,
    }

--- Table which has a title above it above it
local title_table = Gui.element("readme_title_table")
    :draw(function(_, parent, bar_size, caption, column_count)
        Gui.elements.title_label(parent, bar_size, caption)

        return parent.add{
            type = "table",
            column_count = column_count,
            style = "bordered_table",
        }
    end)
    :style{
        padding = 0,
        cell_padding = 0,
        vertical_align = "center",
        horizontally_stretchable = true,
    }

--- Scroll to be used with Gui.elements.title_label tables
local title_table_scroll = Gui.element("readme_title_table_scroll")
    :draw{
        type = "scroll-pane",
        direction = "vertical",
        horizontal_scroll_policy = "never",
        vertical_scroll_policy = "auto",
        style = "scroll_pane_under_subheader",
    }
    :style{
        padding = { 1, 3 },
        maximal_height = scroll_height,
        horizontally_stretchable = true,
    }

--- Used to connect to servers in server list
local join_server = Gui.element("readme_join_server")
    :draw(function(_, parent, server_id, wrong_version)
        local status = External.get_server_status(server_id) or "Offline"
        if wrong_version then status = "Version" end
        local flow = parent.add{ name = server_id, type = "flow" }
        local button = flow.add{
            type = "sprite-button",
            sprite = "utility/circuit_network_panel",
            hovered_sprite = "utility/circuit_network_panel",
            tooltip = { "readme.servers-connect-" .. status, wrong_version },
            style = "frame_action_button",
        }

        if status == "Offline" or status == "Current" then
            button.enabled = false
            button.sprite = "utility/circuit_network_panel"
        elseif status == "Version" then
            button.enabled = false
            button.sprite = "utility/shuffle"
        elseif status == "Password" then
            button.sprite = "utility/warning_white"
            button.hovered_sprite = "utility/warning"
        elseif status == "Modded" then
            button.sprite = "utility/downloading_white"
            button.hovered_sprite = "utility/downloading"
        end

        return button
    end)
    :style{
        size = 20,
        padding = -1,
    }
    :on_click(function(def, player, element)
        local server_id = element.parent.name
        External.request_connection(player, server_id, true)
    end)

local welcome_time_format = ExpUtil.format_time_factory_locale{ format = "long", days = true, hours = true, minutes = true }

--- Content area for the welcome tab
define_tab({ "readme.welcome-tab" }, { "readme.welcome-tooltip" }, Gui.element("readme_welcome")
    :draw(function(_, parent)
        local server_details = { name = "ExpGaming S0 - Local", welcome = "Failed to load description: disconnected from external api.", reset_time = "Non Set", branch = "Unknown" }
        if External.valid() then server_details = External.get_current_server() end
        local container = parent.add{ type = "flow", direction = "vertical" }
        local player = Gui.get_player(parent)

        -- Set up the top flow with logos
        local top_flow = container.add{ type = "flow" }
        top_flow.add{ type = "sprite", sprite = "file/modules/exp_legacy/modules/gui/logo.png" }
        local top_vertical_flow = top_flow.add{ type = "flow", direction = "vertical" }
        top_flow.add{ type = "sprite", sprite = "file/modules/exp_legacy/modules/gui/logo.png" }
        top_vertical_flow.style.horizontal_align = "center"

        -- Add the title and description to the top flow
        Gui.elements.title_label(top_vertical_flow, 62, "Welcome to " .. server_details.name)
        Gui.elements.centered_label(top_vertical_flow, 380, server_details.welcome)
        Gui.elements.bar(container)

        -- Get the names of the roles the player has
        local player_roles = Roles.get_player_roles(player)
        local role_names = {}
        for i, role in ipairs(player_roles) do
            role_names[i] = role.name
        end

        -- Add the other information to the gui
        container.add{ type = "flow" }.style.height = 4
        local online_time = welcome_time_format(game.tick)
        Gui.elements.centered_label(sub_content(container), frame_width, { "readme.welcome-general", server_details.reset_time, online_time })
        Gui.elements.centered_label(sub_content(container), frame_width, { "readme.welcome-roles", table.concat(role_names, ", ") })
        Gui.elements.centered_label(sub_content(container), frame_width, { "readme.welcome-chat" })

        return container
    end))

--- Content area for the rules tab
define_tab({ "readme.rules-tab" }, { "readme.rules-tooltip" }, Gui.element("readme_rules")
    :draw(function(_, parent)
        local container = parent.add{ type = "flow", direction = "vertical" }

        -- Add the title and description to the content
        Gui.elements.title_label(container, title_width - 3, { "readme.rules-tab" })
        Gui.elements.centered_label(container, frame_width, { "readme.rules-general" })
        Gui.elements.bar(container)
        container.add{ type = "flow" }

        -- Add a table for the rules
        local rules = Gui.elements.scroll_table(container, scroll_height, 1) --[[@as LuaGuiElement]]
        rules.style = "bordered_table"
        rules.style.cell_padding = 4

        -- Add the rules to the table
        for i = 1, 15 do
            Gui.elements.centered_label(rules, 565, { "readme.rules-" .. i })
        end

        return container
    end))

--- Content area for the commands tab
define_tab({ "readme.commands-tab" }, { "readme.commands-tooltip" }, Gui.element("readme_commands")
    :draw(function(_, parent)
        local container = parent.add{ type = "flow", direction = "vertical" }
        local player = Gui.get_player(parent)

        -- Add the title and description to the content
        Gui.elements.title_label(container, title_width - 20, { "readme.commands-tab" })
        Gui.elements.centered_label(container, frame_width, { "readme.commands-general" })
        Gui.elements.bar(container)
        container.add{ type = "flow" }

        -- Add a table for the commands
        local commands = Gui.elements.scroll_table(container, scroll_height, 2) --[[@as LuaGuiElement]]
        commands.style = "bordered_table"
        commands.style.cell_padding = 0

        -- Add the rules to the table
        for name, command in pairs(Commands.list_for_player(player)) do
            Gui.elements.centered_label(commands, 120, name)
            Gui.elements.centered_label(commands, 450, command.description)
        end

        return container
    end))

--- Content area for the servers tab
define_tab({ "readme.servers-tab" }, { "readme.servers-tooltip" }, Gui.element("readme_servers")
    :draw(function(_, parent)
        local container = parent.add{ type = "flow", direction = "vertical" }

        -- Add the title and description to the content
        Gui.elements.title_label(container, title_width - 10, { "readme.servers-tab" })
        Gui.elements.centered_label(container, frame_width, { "readme.servers-general" })
        Gui.elements.bar(container)
        container.add{ type = "flow" }

        -- Draw the scroll
        local scroll_pane = title_table_scroll(container)
        scroll_pane.style.maximal_height = scroll_height + 20 -- the text is a bit shorter

        -- Add the factorio servers
        if External.valid() then
            local factorio_servers = title_table(scroll_pane, 225, { "readme.servers-factorio" }, 3)
            local current_version = External.get_current_server().version
            for server_id, server in pairs(External.get_servers()) do
                Gui.elements.centered_label(factorio_servers, 110, server.short_name)
                Gui.elements.centered_label(factorio_servers, 436, server.description)
                join_server(factorio_servers, server_id, current_version ~= server.version and server.version)
            end
        else
            local factorio_servers = title_table(scroll_pane, 225, { "readme.servers-factorio" }, 2)
            for i = 1, 8 do
                Gui.elements.centered_label(factorio_servers, 110, { "readme.servers-" .. i })
                Gui.elements.centered_label(factorio_servers, 460, { "readme.servers-d" .. i })
            end
        end

        -- Add the external links
        local external_links = title_table(scroll_pane, 235, { "readme.servers-external" }, 2)
        for _, key in ipairs{ "discord", "website", "patreon", "status", "github" } do
            local upper_key = key:gsub("^%l", string.upper)
            Gui.elements.centered_label(external_links, 110, upper_key)
            Gui.elements.centered_label(external_links, 460, { "links." .. key }, { "readme.servers-open-in-browser" })
        end

        return container
    end))

--- Content area for the servers tab
define_tab({ "readme.backers-tab" }, { "readme.backers-tooltip" }, Gui.element("readme_backers")
    :draw(function(_, parent)
        local container = parent.add{ type = "flow", direction = "vertical" }

        -- Add the title and description to the content
        Gui.elements.title_label(container, title_width - 10, { "readme.backers-tab" })
        Gui.elements.centered_label(container, frame_width, { "readme.backers-general" })
        Gui.elements.bar(container)
        container.add{ type = "flow" }

        -- Find which players will go where
        local done = {}
        local groups = {
            { _roles = { "Senior Administrator", "Administrator" }, _title = { "readme.backers-management" }, _width = 230 },
            { _roles = { "Board Member", "Senior Backer" }, _title = { "readme.backers-board" }, _width = 145 }, -- change role to board
            { _roles = { "Sponsor", "Supporter" }, _title = { "readme.backers-backers" }, _width = 196 }, -- change to backer
            { _roles = { "Moderator", "Trainee" }, _title = { "readme.backers-staff" }, _width = 235 },
            { _roles = {}, _time = 3 * 3600 * 60, _title = { "readme.backers-active" }, _width = 235 },
        }

        -- Fill by player roles
        for player_name, player_roles in pairs(Roles.config.players) do
            for _, players in ipairs(groups) do
                for _, role_name in pairs(players._roles) do
                    if table.contains(player_roles, role_name) then
                        done[player_name] = true
                        table.insert(players, player_name)
                        break
                    end
                end
            end
        end

        -- Fill by active times
        for _, player in pairs(game.players) do
            if not done[player.name] then
                for _, players in ipairs(groups) do
                    if players._time and player.online_time > players._time then
                        table.insert(players, player.name)
                    end
                end
            end
        end

        -- Add the different tables
        local scroll_pane = title_table_scroll(container)
        for _, players in ipairs(groups) do
            local table = title_table(scroll_pane, players._width, players._title, 4)
            for _, player_name in ipairs(players) do
                Gui.elements.centered_label(table, 140, player_name)
            end

            if #players < 4 then
                for i = 1, 4 - #players do
                    Gui.elements.centered_label(table, 140)
                end
            end
        end

        return container
    end))

--- Content area for the player data tab
define_tab({ "readme.data-tab" }, { "readme.data-tooltip" }, Gui.element("readme_data")
    :draw(function(_, parent)
        local container = parent.add{ type = "flow", direction = "vertical" }
        local player = Gui.get_player(parent)
        local player_name = player.name

        local enum = PlayerData.PreferenceEnum
        local preference = PlayerData.DataSavingPreference:get(player_name)
        local preference_meta = PlayerData.DataSavingPreference.metadata
        preference = enum[preference]

        -- Add the title and description to the content
        Gui.elements.title_label(container, title_width, { "readme.data-tab" })
        Gui.elements.centered_label(container, frame_width, { "readme.data-general" })
        Gui.elements.bar(container)
        container.add{ type = "flow" }
        local scroll_pane = title_table_scroll(container)

        -- Add the required area
        local required = title_table(scroll_pane, 250, { "readme.data-required" }, 2)
        Gui.elements.centered_label(required, 150, preference_meta.name, preference_meta.tooltip)
        Gui.elements.centered_label(required, 420, { "expcore-data.preference-" .. enum[preference] }, preference_meta.value_tooltip)

        for name, child in pairs(PlayerData.Required.children) do
            local metadata = child.metadata
            local value = child:get(player_name)
            if value ~= nil or metadata.show_always then
                if metadata.stringify then value = metadata.stringify(value) end
                Gui.elements.centered_label(required, 150, metadata.name or { "exp-required." .. name }, metadata.tooltip or { "exp-required." .. name .. "-tooltip" })
                Gui.elements.centered_label(required, 420, tostring(value), metadata.value_tooltip or { "exp-required." .. name .. "-value-tooltip" })
            end
        end

        -- Add the settings area
        if preference <= enum.Settings then
            local settings = title_table(scroll_pane, 255, { "readme.data-settings" }, 2)
            for name, child in pairs(PlayerData.Settings.children) do
                local metadata = child.metadata
                local value = child:get(player_name)
                if not metadata.permission or Roles.player_allowed(player, metadata.permission) then
                    if metadata.stringify then value = metadata.stringify(value) end
                    if value == nil then value = "None set" end
                    Gui.elements.centered_label(settings, 150, metadata.name or { "exp-settings." .. name }, metadata.tooltip or { "exp-settings." .. name .. "-tooltip" })
                    Gui.elements.centered_label(settings, 420, tostring(value), metadata.value_tooltip or { "exp-settings." .. name .. "-value-tooltip" })
                end
            end
        end

        -- Add the statistics area
        if preference <= enum.Statistics then
            local count = 4
            local statistics = title_table(scroll_pane, 250, { "readme.data-statistics" }, 4)
            for _, name in pairs(PlayerData.Statistics.metadata.display_order) do
                local child = PlayerData.Statistics[name]
                local metadata = child.metadata
                local value = child:get(player_name)
                if value ~= nil or metadata.show_always then
                    count = count - 2
                    if metadata.stringify then
                        value = metadata.stringify(value)
                    else
                        value = format_number(value or 0, false)
                    end
                    Gui.elements.centered_label(statistics, 150, metadata.name or { "exp-statistics." .. name }, metadata.tooltip or { "exp-statistics." .. name .. "-tooltip" })
                    Gui.elements.centered_label(statistics, 130, { "readme.data-format", value, metadata.unit or "" }, metadata.value_tooltip or { "exp-statistics." .. name .. "-tooltip" })
                end
            end

            if count > 0 then for i = 1, count do Gui.elements.centered_label(statistics, 140) end end
        end

        -- Add the misc area
        local skip = { DataSavingPreference = true, Settings = true, Statistics = true, Required = true }
        local count = 0; for _ in pairs(PlayerData.All.children) do count = count + 1 end

        if preference <= enum.All and count > 4 then
            local misc = title_table(scroll_pane, 232, { "readme.data-misc" }, 2)
            for name, child in pairs(PlayerData.All.children) do
                if not skip[name] then
                    local metadata = child.metadata
                    local value = child:get(player_name)
                    if value ~= nil or metadata.show_always then
                        if metadata.stringify then value = metadata.stringify(value) end
                        Gui.elements.centered_label(misc, 150, metadata.name or name, metadata.tooltip)
                        Gui.elements.centered_label(misc, 420, tostring(value), metadata.value_tooltip)
                    end
                end
            end
        end

        return container
    end))

--- Main readme container for the center flow
local readme_toggle
local readme = Gui.element("readme")
    :draw(function(def, parent)
        local container = parent.add{
            name = def.name,
            type = "frame",
            style = "invisible_frame",
        }

        -- Add the left hand side of the frame back, removed because of frame_tabbed_pane style
        local left_alignment = Gui.elements.aligned_flow(container, { vertical_align = "bottom" })
        left_alignment.style.padding = { 32, 0, 0, 0 }

        local left_side =
            left_alignment.add{
                type = "frame",
                style = "character_gui_left_side",
            }
        left_side.style.vertically_stretchable = true
        left_side.style.padding = 0
        left_side.style.width = 5

        -- Add the tab pane
        local tab_pane = container.add{
            name = "pane",
            type = "tabbed-pane",
            style = "frame_tabbed_pane",
        }

        -- Add the different content areas
        for _, tab_details in ipairs(tabs) do
            local tab = tab_pane.add{ type = "tab", style = "frame_tab", caption = tab_details[1], tooltip = tab_details[2] }
            tab_pane.add_tab(tab, tab_details[3](tab_pane))
        end

        return container
    end)
    :on_opened(function(def, player, element)
        Gui.toolbar.set_button_toggled_state(readme_toggle, player, true)
    end)
    :on_closed(function(def, player, element)
        Gui.toolbar.set_button_toggled_state(readme_toggle, player, false)
        Gui.destroy_if_valid(element)
    end)

--- Toggle button for the readme gui
readme_toggle =
    Gui.toolbar.create_button{
        name = "readme_toggle",
        auto_toggle = true,
        sprite = "virtual-signal/signal-info",
        tooltip = { "readme.main-tooltip" },
        visible = function(player, element)
            return Roles.player_allowed(player, "gui/readme")
        end
    }
    :on_click(function(def, player, element)
        local center = player.gui.center
        if center[readme.name] then
            player.opened = nil
        else
            player.opened = readme(center)
        end
    end)

--- When a player joins the game for the first time show this gui
Event.add(defines.events.on_player_created, function(event)
    local player = game.players[event.player_index]
    local element = readme(player.gui.center)
    element.pane.selected_tab_index = 1
    player.opened = element
end)

local function clear_readme(event)
    local player = game.players[event.player_index]
    if not player.opened then
        Gui.destroy_if_valid(player.gui.center[readme.name])
    end
end

--- When a player joins or respawns, clear center unless the player has something open
Event.add(defines.events.on_player_joined_game, clear_readme)
Event.add(defines.events.on_player_respawned, clear_readme)
