--[[-- Gui Module - Readme
Adds a main gui that contains important information about the server.
]]

local ExpUtil = require("modules/exp_util")
local Gui = require("modules/exp_gui")
local Roles = require("modules.exp_legacy.expcore.roles")
local Commands = require("modules/exp_commands")
local PlayerData = require("modules.exp_legacy.expcore.player_data")
local External = require("modules.exp_legacy.expcore.external")

local format_number = require("util").format_number
local format_time = ExpUtil.format_time_factory_locale{ format = "long", days = true, hours = true, minutes = true }

local frame_width = 595
local title_width = 270
local scroll_height = 275

--- @class ExpGui_Readme.elements
local Elements = {}

--- @type table<number, { caption: LocalisedString, tooltip: LocalisedString, element: ExpElement }>
local tabs = {}

--- Register a readme tab
--- @param caption LocalisedString
--- @param tooltip LocalisedString
--- @param element ExpElement
local function define_tab(caption, tooltip, element)
    tabs[#tabs + 1] = { caption = caption, tooltip = tooltip, element = element }
end

--- Create a title section table
--- @class ExpGui_Readme.elements.title_table: ExpElement
--- @overload fun(parent: LuaGuiElement, bar_size: number, caption: LocalisedString, column_count: number): LuaGuiElement
Elements.title_table = Gui.define("readme/title_table")
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
    } --[[ @as any ]]

--- Scroll pane used for title tables
--- @class ExpGui_Readme.elements.title_table_scroll: ExpElement
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.title_table_scroll = Gui.define("readme/title_table_scroll")
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
    } --[[ @as any ]]

--- Sub content frame
--- @class ExpGui_Readme.elements.sub_content: ExpElement
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
Elements.sub_content = Gui.define("readme/sub_content")
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
    } --[[ @as any ]]

--- @class ExpGui_Readme.elements.join_server.elements
--- @field server_id string

--- Join server button
--- @class ExpGui_Readme.elements.join_server: ExpElement
--- @field data table<LuaGuiElement, ExpGui_Readme.elements.join_server.elements>
--- @overload fun(parent: LuaGuiElement, server_id: string, wrong_version: string?): LuaGuiElement
Elements.join_server = Gui.define("readme/join_server")
    :track_all_elements()
    :draw(function(def, parent, server_id, wrong_version)
        --- @cast def ExpGui_Readme.elements.join_server
        local flow = parent.add{
            type = "flow",
        }

        local button = flow.add{
            type = "sprite-button",
            sprite = "utility/circuit_network_panel",
            hovered_sprite = "utility/circuit_network_panel",
            style = "frame_action_button",
        }

        def.data[button] = {
            server_id = server_id,
        }

        Elements.join_server.refresh(button, wrong_version)
        return button
    end)
    :style{
        size = 20,
        padding = -1,
    }
    :on_click(function(def, player, button)
        --- @cast def ExpGui_Readme.elements.join_server
        local server_id = def.data[button].server_id
        External.request_connection(player, server_id, true)
    end) --[[ @as any ]]

--- Refresh join server button
--- @param button LuaGuiElement
--- @param wrong_version string?
function Elements.join_server.refresh(button, wrong_version)
    local server_id = Elements.join_server.data[button].server_id
    local status = External.get_server_status(server_id) or "Offline"

    if wrong_version then
        status = "Version"
    end

    button.tooltip = { "exp-gui_readme.servers-connect-" .. status, wrong_version }

    if status == "Offline" or status == "Current" then
        button.enabled = false
        button.sprite = "utility/circuit_network_panel"
        button.hovered_sprite = "utility/circuit_network_panel"

    elseif status == "Version" then
        button.enabled = false
        button.sprite = "utility/shuffle"
        button.hovered_sprite = "utility/shuffle"

    elseif status == "Password" then
        button.enabled = true
        button.sprite = "utility/warning_white"
        button.hovered_sprite = "utility/warning"

    elseif status == "Modded" then
        button.enabled = true
        button.sprite = "utility/downloading_white"
        button.hovered_sprite = "utility/downloading"

    else
        button.enabled = true
        button.sprite = "utility/circuit_network_panel"
        button.hovered_sprite = "utility/circuit_network_panel"
    end
end

--- Refresh all online join buttons
function Elements.join_server.refresh_all()
    if not External.valid() then
        return
    end

    local current_version = External.get_current_server().version

    for _, button in Elements.join_server:tracked_elements() do
        local server_id = Elements.join_server.data[button].server_id
        local server = External.get_servers()[server_id]

        if server then
            Elements.join_server.refresh(button, current_version ~= server.version and server.version or nil)
        end
    end
end

--- Welcome tab
define_tab(
    { "exp-gui_readme.welcome-tab" },
    { "exp-gui_readme.welcome-tooltip" },
    Gui.define("readme/welcome")
    :draw(function(_, parent)
        local player = Gui.get_player(parent)

        local server_details = {
            name = "ExpGaming S0 - Local",
            welcome = "Failed to load description: disconnected from external api.",
            reset_time = "Not Set",
        }

        if External.valid() then
            server_details = External.get_current_server()
        end

        local container = parent.add{ type = "flow", direction = "vertical" }

        local top_flow = container.add{ type = "flow" }
        top_flow.add{ type = "sprite", sprite = "file/modules/exp_scenario/gui/logo.png" }

        local center_flow = top_flow.add{ type = "flow", direction = "vertical" }
        center_flow.style.horizontal_align = "center"

        Gui.elements.title_label(center_flow, 62, { "exp-gui_readme.welcome-title", server_details.name })
        Gui.elements.centered_label(center_flow, 380, server_details.welcome)

        top_flow.add{ type = "sprite", sprite = "file/modules/exp_scenario/gui/logo.png" }

        Gui.elements.bar(container)
        container.add{ type = "flow" }.style.height = 4

        local role_names = {}
        for i, role in ipairs(Roles.get_player_roles(player)) do
            role_names[i] = role.name
        end

        Gui.elements.centered_label(
            Elements.sub_content(container),
            frame_width,
            {
                "exp-gui_readme.welcome-general",
                server_details.reset_time,
                format_time(game.tick),
            }
        )

        Gui.elements.centered_label(
            Elements.sub_content(container),
            frame_width,
            {
                "exp-gui_readme.welcome-roles",
                table.concat(role_names, ", "),
            }
        )

        Gui.elements.centered_label(
            Elements.sub_content(container),
            frame_width,
            { "exp-gui_readme.welcome-chat" }
        )

        return container
    end) --[[ @as any ]]
)

--- Rules tab
define_tab(
    { "exp-gui_readme.rules-tab" },
    { "exp-gui_readme.rules-tooltip" },
    Gui.define("readme/rules")
    :draw(function(_, parent)
        local container = parent.add{ type = "flow", direction = "vertical" }
        Gui.elements.title_label(container, title_width - 3, { "exp-gui_readme.rules-tab" })
        Gui.elements.centered_label(container, frame_width, { "exp-gui_readme.rules-general" })
        Gui.elements.bar(container)
        container.add{ type = "flow" }

        local rules = Gui.elements.scroll_table(container, scroll_height, 1)
        rules.style = "bordered_table"
        rules.style.cell_padding = 4

        for i = 1, 15 do
            Gui.elements.centered_label(rules, frame_width - 30, { "exp-gui_readme.rules-" .. i })
        end

        return container
    end) --[[ @as any ]]
)

--- Commands tab
define_tab(
    { "exp-gui_readme.commands-tab" },
    { "exp-gui_readme.commands-tooltip" },
    Gui.define("readme/commands")
    :draw(function(_, parent)
        local player = Gui.get_player(parent)

        local container = parent.add{ type = "flow", direction = "vertical" }
        Gui.elements.title_label(container, title_width - 20, { "exp-gui_readme.commands-tab" })
        Gui.elements.centered_label(container, frame_width, { "exp-gui_readme.commands-general" })
        Gui.elements.bar(container)
        container.add{ type = "flow" }

        local commands = Gui.elements.scroll_table(container, scroll_height, 2)
        commands.style = "bordered_table"
        commands.style.cell_padding = 0

        for name, command in pairs(Commands.list_for_player(player)) do
            Gui.elements.centered_label(commands, 120, name)
            Gui.elements.centered_label(commands, 450, command.description)
        end

        return container
    end) --[[ @as any ]]
)

--- Servers tab
define_tab(
    { "exp-gui_readme.servers-tab" },
    { "exp-gui_readme.servers-tooltip" },
    Gui.define("readme/servers")
    :draw(function(_, parent)
        local container = parent.add{ type = "flow", direction = "vertical" }
        Gui.elements.title_label(container, title_width - 10, { "exp-gui_readme.servers-tab" })
        Gui.elements.centered_label(container, frame_width, { "exp-gui_readme.servers-general" })
        Gui.elements.bar(container)
        container.add{ type = "flow" }

        local scroll_pane = Elements.title_table_scroll(container)
        scroll_pane.style.maximal_height = scroll_height + 20

        if External.valid() then
            local current_version = External.get_current_server().version

            local factorio_servers = Elements.title_table(scroll_pane, 225, { "exp-gui_readme.servers-factorio" }, 3)

            for server_id, server in pairs(External.get_servers()) do
                Gui.elements.centered_label(factorio_servers, 110, server.short_name)
                Gui.elements.centered_label(factorio_servers, 436, server.description)
                Elements.join_server(factorio_servers, server_id, current_version ~= server.version and server.version or nil)
            end
        else
            local factorio_servers = Elements.title_table(scroll_pane, 225, { "exp-gui_readme.servers-factorio" }, 2)
            for i = 1, 8 do
                Gui.elements.centered_label(factorio_servers, 110, { "exp-gui_readme.servers-" .. i })
                Gui.elements.centered_label(factorio_servers, 460, { "exp-gui_readme.servers-d" .. i })
            end
        end

        local external_links = Elements.title_table(scroll_pane, 235, { "exp-gui_readme.servers-external" }, 2)
        for _, key in ipairs{ "discord", "website", "patreon", "status", "github" } do
            Gui.elements.centered_label(external_links, 110, key:gsub("^%l", string.upper))
            Gui.elements.centered_label(external_links, 460, { "links." .. key }, { "exp-gui_readme.servers-open-in-browser" })
        end

        return container
    end) --[[ @as any ]]
)

--- Backers tab
--- Content area for the backers tab
define_tab(
    { "exp-gui_readme.backers-tab" },
    { "exp-gui_readme.backers-tooltip" },
    Gui.define("readme/backers")
    :draw(function(_, parent)
        local container = parent.add{ type = "flow", direction = "vertical" }
        Gui.elements.title_label(container, title_width - 10, { "exp-gui_readme.backers-tab" })
        Gui.elements.centered_label(container, frame_width, { "exp-gui_readme.backers-general" })
        Gui.elements.bar(container)
        container.add{ type = "flow" }

        local groups = {
            {
                roles = { "Senior Administrator", "Administrator" },
                title = { "exp-gui_readme.backers-management" },
                width = 230,
                players = {},
            },
            {
                roles = { "Board Member", "Senior Backer" },
                title = { "exp-gui_readme.backers-board" },
                width = 145,
                players = {},
            },
            {
                roles = { "Sponsor", "Supporter" },
                title = { "exp-gui_readme.backers-backers" },
                width = 196,
                players = {},
            },
            {
                roles = { "Moderator", "Trainee" },
                title = { "exp-gui_readme.backers-staff" },
                width = 235,
                players = {},
            },
            {
                roles = {},
                time = 3 * 3600 * 60,
                title = { "exp-gui_readme.backers-active" },
                width = 235,
                players = {},
            },
        }

        local done = {}

        -- Fill groups from configured roles
        for player_name, player_roles in pairs(Roles.config.players) do
            for _, group in ipairs(groups) do
                for _, role_name in ipairs(group.roles) do
                    if table.contains(player_roles, role_name) then
                        done[player_name] = true
                        group.players[#group.players + 1] = player_name
                        break
                    end
                end
            end
        end

        -- Fill active player group
        for _, player in pairs(game.players) do
            if not done[player.name] then
                for _, group in ipairs(groups) do
                    if group.time and player.online_time > group.time then
                        group.players[#group.players + 1] = player.name
                    end
                end
            end
        end

        local scroll_pane = Elements.title_table_scroll(container)

        for _, group in ipairs(groups) do
            if #group.players > 0 then
                local backers_table = Elements.title_table(scroll_pane, group.width, group.title, 4)

                for _, player_name in ipairs(group.players) do
                    Gui.elements.centered_label(backers_table, 140, player_name)
                end

                if #group.players < 4 then
                    for i = 1, 4 - #group.players do
                        Gui.elements.centered_label(backers_table, 140)
                    end
                end
            end
        end

        return container
    end) --[[ @as any ]]
)

--- @class (exact) ExpGui_Readme.elements.readme_data.param table
--- @field scroll_pane LuaGuiElement
--- @field player LuaPlayer
--- @field player_name string
--- @field children table
--- @field title LocalisedString
--- @field locale_prefix string
--- @field default_stringify fun(value: any): string
--- @field columns number
--- @field title_width number
--- @field column_width number
--- @field extra_rows fun(data_table: LuaGuiElement)?

--- Render a player data category
--- @param opts ExpGui_Readme.elements.readme_data.param
local function render_data_category(opts)
    local data_table = Elements.title_table(opts.scroll_pane, opts.title_width, opts.title, opts.columns)

    if opts.extra_rows then
        opts.extra_rows(data_table)
    end

    for name, child in pairs(opts.children) do
        local metadata = child.metadata

        if not metadata.permission or Roles.player_allowed(opts.player, metadata.permission) then
            local value = child:get(opts.player_name)

            if value ~= nil or metadata.show_always then
                if metadata.stringify_short then
                    value = metadata.stringify_short(value)
                elseif metadata.stringify then
                    value = metadata.stringify(value)
                else
                    value = opts.default_stringify(value)
                end

                local tooltip = metadata.tooltip or { opts.locale_prefix .. name .. "-tooltip" }
                Gui.elements.centered_label(
                    data_table, 150,
                    metadata.name or { opts.locale_prefix .. name },
                    tooltip
                )

                Gui.elements.centered_label(
                    data_table, opts.column_width,
                    { "exp-gui_readme.data-format", value, metadata.unit or "" },
                    metadata.value_tooltip or { "?", { opts.locale_prefix .. name .. "-value-tooltip" }, tooltip }
                )
            end
        end
    end
end

--- Content area for the player data tab
define_tab(
    { "exp-gui_readme.data-tab" },
    { "exp-gui_readme.data-tooltip" },
    Gui.define("readme/data")
    :draw(function(_, parent)
        local container = parent.add{ type = "flow", direction = "vertical" }

        local player = Gui.get_player(parent)
        local player_name = player.name

        local enum = PlayerData.PreferenceEnum
        local preference = PlayerData.DataSavingPreference:get(player_name)
        local preference_meta = PlayerData.DataSavingPreference.metadata
        preference = enum[preference]

        Gui.elements.title_label(container, title_width, { "exp-gui_readme.data-tab" })
        Gui.elements.centered_label(container, frame_width, { "exp-gui_readme.data-general" })
        Gui.elements.bar(container)
        container.add{ type = "flow" }

        local scroll_pane = Elements.title_table_scroll(container)

        render_data_category{
            scroll_pane = scroll_pane,
            player = player,
            player_name = player_name,
            children = PlayerData.Required.children,
            title = { "exp-gui_readme.data-required" },
            locale_prefix = "exp-required.",
            columns = 2,
            title_width = 250,
            column_width = 420,
            default_stringify = tostring,
            extra_rows = function(required)
                Gui.elements.centered_label(required, 150, preference_meta.name, preference_meta.tooltip)
                Gui.elements.centered_label(required, 420, { "expcore-data.preference-" .. enum[preference] }, preference_meta.value_tooltip)
            end,
        }

        if preference <= enum.Settings then
            render_data_category{
                scroll_pane = scroll_pane,
                player = player,
                player_name = player_name,
                children = PlayerData.Settings.children,
                title = { "exp-gui_readme.data-settings" },
                locale_prefix = "exp-settings.",
                columns = 2,
                title_width = 255,
                column_width = 420,
                default_stringify = function(value)
                    return tostring(value or "None set")
                end,
            }
        end

        if preference <= enum.Statistics then
            render_data_category{
                scroll_pane = scroll_pane,
                player = player,
                player_name = player_name,
                children = PlayerData.Statistics.children,
                title = { "exp-gui_readme.data-statistics" },
                locale_prefix = "exp-statistics.",
                columns = 4,
                title_width = 250,
                column_width = 130,
                default_stringify = function(value)
                    return format_number(value or 0, false)
                end,
            }
        end

        local skip = {
            DataSavingPreference = true,
            Settings = true,
            Statistics = true,
            Required = true,
        }

        local count = 0
        for _ in pairs(PlayerData.All.children) do
            count = count + 1
        end

        if preference <= enum.All and count > 4 then
            local misc = {}
            for name, child in pairs(PlayerData.All.children) do
                if not skip[name] then
                    misc[name] = child
                end
            end

            render_data_category{
                scroll_pane = scroll_pane,
                player = player,
                player_name = player_name,
                children = misc,
                title = { "exp-gui_readme.data-misc" },
                locale_prefix = "",
                columns = 2,
                title_width = 232,
                column_width = 420,
                default_stringify = tostring,
            }
        end

        return container
    end) --[[ @as any ]]
)

--- @class ExpGui_Readme.elements.container.elements
--- @field pane LuaGuiElement

--- Main readme container
--- @class ExpGui_Readme.elements.container: ExpElement
--- @field data table<LuaGuiElement, ExpGui_Readme.elements.container.elements>
Elements.container = Gui.define("readme/container")
    :track_all_elements()
    :draw(function(def, parent)
        --- @cast def ExpGui_Readme.elements.container
        local container = parent.add{ name = def.name, type = "frame", style = "invisible_frame" }

        local left_alignment = Gui.elements.aligned_flow(container, { vertical_align = "bottom" })
        left_alignment.style.padding = { 32, 0, 0, 0 }

        local left_side = left_alignment.add{ type = "frame", style = "character_gui_left_side" }
        left_side.style.vertically_stretchable = true
        left_side.style.padding = 0
        left_side.style.width = 5

        local pane = container.add{
            name = "pane",
            type = "tabbed-pane",
            style = "frame_tabbed_pane",
        }

        for _, tab in ipairs(tabs) do
            local gui_tab = pane.add{
                type = "tab",
                style = "frame_tab",
                caption = tab.caption,
                tooltip = tab.tooltip,
            }

            pane.add_tab(gui_tab, tab.element(pane))
        end

        def.data[container] = {
            pane = pane,
        }

        return container
    end)
    :on_opened(function(def, player)
        Gui.toolbar.set_button_toggled_state(Elements.toggle_button, player, true)
    end)
    :on_closed(function(def, player, element)
        Gui.toolbar.set_button_toggled_state(Elements.toggle_button, player, false)
        Gui.destroy_if_valid(element)
    end)

--- Toggle button
Elements.toggle_button = Gui.toolbar.create_button{
        name = "readme_toggle",
        auto_toggle = true,
        sprite = "virtual-signal/signal-info",
        tooltip = { "exp-gui_readme.main-tooltip" },
        visible = function(player)
            return Roles.player_allowed(player, "gui/readme")
        end,
    }
    :on_click(function(_, player)
        local center = player.gui.center
        local readme = center[Elements.container.name]

        if readme then
            player.opened = nil
        else
            player.opened = Elements.container(center)
        end
    end)

--- Open readme for new players
--- @param event EventData.on_player_created
local function open_readme(event)
    local player = assert(game.get_player(event.player_index))
    local element = Elements.container(player.gui.center)
    element.pane.selected_tab_index = 1
    player.opened = element
end

--- Clear stale readme
--- @param event EventData.on_player_joined_game | EventData.on_player_respawned
local function clear_readme(event)
    local player = game.players[event.player_index]
    if not player.opened then
        Gui.destroy_if_valid(player.gui.center[Elements.container.name])
    end
end

local e = defines.events

return {
    elements = Elements,
    events = {
        [e.on_player_created] = open_readme,
        [e.on_player_joined_game] = clear_readme,
        [e.on_player_respawned] = clear_readme,
    },
    on_nth_tick = {
        [60 * 60] = Elements.join_server.refresh_all,
    }
}
