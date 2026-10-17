--[[-- Gui Module - Readme
Adds a main gui that contains important information about the server.
]]

local ExpUtil = require("modules/exp_util")
local Gui = require("modules/exp_gui")
local Roles = require("modules/exp_roles")
local Commands = require("modules/exp_commands")
local ExpPlayerStatistics = require("modules/exp_player_statistics")
local ExpServerList = require("modules/exp_server_list")
local community = require("modules/exp_scenario/config/community_details").config

local format_time = ExpUtil.format_time_factory_locale{ format = "long", days = true, hours = true, minutes = true }

local frame_width = 595
local title_width = 270
local scroll_height = 275
local description_length = 120

--- Cut a string to a number of bytes without splitting a utf8 character
--- @param str string
--- @param length number
--- @return string
local function shorten(str, length)
    if #str <= length then
        return str
    end
    local next_byte = str:byte(length + 1)
    while length > 0 and next_byte >= 0x80 and next_byte < 0xC0 do
        length = length - 1
        next_byte = str:byte(length + 1)
    end
    return str:sub(1, length) .. "..."
end

--- @class ExpGui_Readme.elements
local Elements = {}

--- @type table<number, { caption: LocalisedString, tooltip: LocalisedString | (fun(): LocalisedString), element: ExpElement }>
local tabs = {}

--- Register a readme tab
--- @param caption LocalisedString
--- @param tooltip LocalisedString | fun(): LocalisedString Functions are called when the readme opens
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
    } --[[@as any]]

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
    } --[[@as any]]

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
    } --[[@as any]]

--- @class ExpGui_Readme.elements.join_server.elements
--- @field server_id number

--- Join server button
--- @class ExpGui_Readme.elements.join_server: ExpElement
--- @field data table<LuaGuiElement, ExpGui_Readme.elements.join_server.elements>
--- @overload fun(parent: LuaGuiElement, server: ExpServerList.Server): LuaGuiElement
Elements.join_server = Gui.define("readme/join_server")
    :track_all_elements()
    :draw(function(def, parent, server)
        --- @cast def ExpGui_Readme.elements.join_server
        --- @cast server ExpServerList.Server
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
            server_id = server.id,
        }

        Elements.join_server.refresh(button, server)
        return button
    end)
    :style{
        size = 20,
        padding = -1,
    }
    :on_click(function(def, player, button)
        --- @cast def ExpGui_Readme.elements.join_server
        local server = ExpServerList.get_server(def.data[button].server_id)
        if server and ExpServerList.is_online(server) then
            ExpServerList.request_connection(player, server, true)
        end
    end) --[[@as any]]

--- Refresh join server button
--- @param button LuaGuiElement
--- @param server ExpServerList.Server?
function Elements.join_server.refresh(button, server)
    local current = ExpServerList.get_current()
    local status, detail = "Online", nil
    if not server or not ExpServerList.is_online(server) then
        status = "Offline"
    elseif current and server.id == current.id then
        status = "Current"
    elseif current and server.factorio_version ~= current.factorio_version then
        status, detail = "Version", server.factorio_version
    elseif server.has_password then
        status = "Password"
    elseif current and server.mod_pack_name ~= current.mod_pack_name then
        status, detail = "Modded", server.mod_pack_name
    end

    -- Factorio drops nil parameters, which would shift the player count into __1__
    local player_count = server and server.player_count or 0
    button.tooltip = { "exp-gui_readme.servers-connect-" .. status, detail or "", player_count }

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
        button.sprite = "utility/downloading"
        button.hovered_sprite = "utility/downloading"

    else
        button.enabled = true
        button.sprite = "utility/circuit_network_panel"
        button.hovered_sprite = "utility/circuit_network_panel"
    end
end

--- Refresh all join buttons
function Elements.join_server.refresh_all()
    for _, button in Elements.join_server:tracked_elements() do
        local server_id = Elements.join_server.data[button].server_id
        Elements.join_server.refresh(button, ExpServerList.get_server(server_id))
    end
end

--- Welcome tab
define_tab(
    { "exp-gui_readme.welcome-tab" },
    function() return { "exp-gui_readme.welcome-tooltip", community.community_name } end,
    Gui.define("readme/welcome")
    :draw(function(_, parent)
        local player = Gui.get_player(parent)

        local server_details = {
            name = community.community_name .. " S0 - Local",
            welcome = "Failed to load description: disconnected from the controller.",
            reset_time = "Not Set",
        }

        local current = ExpServerList.get_current()
        if current then
            server_details = {
                name = current.name,
                welcome = current.welcome ~= "" and current.welcome or { "exp-gui_readme.welcome-default" },
                reset_time = current.reset_time ~= "" and current.reset_time or "Not Set",
            }
        end

        local container = parent.add{ type = "flow", direction = "vertical" }

        local top_flow = container.add{ type = "flow" }
        top_flow.add{ type = "sprite", sprite = "file/modules/exp_scenario/gui/logo.png" }

        local center_flow = top_flow.add{ type = "flow", direction = "vertical" }
        center_flow.style.horizontal_align = "center"

        Gui.elements.centered_label(center_flow, 380, { "exp-gui_readme.welcome-title", server_details.name })
        Gui.elements.centered_label(center_flow, 380, server_details.welcome)

        top_flow.add{ type = "sprite", sprite = "file/modules/exp_scenario/gui/logo.png" }

        Gui.elements.bar(container)
        container.add{ type = "flow" }.style.height = 4

        local role_names = {}
        for i, role in ipairs(Roles.sort_roles(Roles.get_player_roles(player))) do
            role_names[i] = role.name
        end

        Gui.elements.centered_label(
            Elements.sub_content(container),
            frame_width,
            {
                "exp-gui_readme.welcome-general",
                community.community_name,
                format_time(game.tick),
                server_details.reset_time,
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
    end) --[[@as any]]
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
        local rules_style = rules.style --[[@as LuaStyle]]
        rules_style.cell_padding = 4

        for i = 1, 15 do
            Gui.elements.centered_label(rules, frame_width - 30, { "exp-gui_readme.rules-" .. i })
        end

        return container
    end) --[[@as any]]
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
        local commands_style = commands.style --[[@as LuaStyle]]
        commands_style.cell_padding = 0

        for name, command in pairs(Commands.list_for_player(player)) do
            Gui.elements.centered_label(commands, 120, name)
            Gui.elements.centered_label(commands, 450, command.description)
        end

        return container
    end) --[[@as any]]
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

        local factorio_servers = Elements.title_table(scroll_pane, 225, { "exp-gui_readme.servers-factorio" }, 3)
        for _, server in ipairs(ExpServerList.get_servers()) do
            local description = shorten(server.description, description_length)
            local tooltip = description ~= server.description and server.description or nil
            Gui.elements.centered_label(factorio_servers, 110, server.display_name)
            Gui.elements.centered_label(factorio_servers, 436, description, tooltip)
            Elements.join_server(factorio_servers, server)
        end

        local external_links = Elements.title_table(scroll_pane, 235, { "exp-gui_readme.servers-external" }, 2)
        for _, key in ipairs{ "discord", "website", "patreon", "status", "github" } do
            Gui.elements.centered_label(external_links, 110, key:gsub("^%l", string.upper))
            Gui.elements.centered_label(external_links, 460, community[key], { "exp-gui_readme.servers-open-in-browser" })
        end

        return container
    end) --[[@as any]]
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
                players = {}, --- @type string[]
            },
            {
                roles = { "Board Member", "Senior Backer" },
                title = { "exp-gui_readme.backers-board" },
                width = 145,
                players = {}, --- @type string[]
            },
            {
                roles = { "Sponsor", "Supporter" },
                title = { "exp-gui_readme.backers-backers" },
                width = 196,
                players = {}, --- @type string[]
            },
            {
                roles = { "Moderator", "Trainee" },
                title = { "exp-gui_readme.backers-staff" },
                width = 235,
                players = {}, --- @type string[]
            },
            {
                roles = {},
                time = 3 * 3600 * 60,
                title = { "exp-gui_readme.backers-active" },
                width = 235,
                players = {}, --- @type string[]
            },
        }

        local done = {}

        -- Fill groups from the players who hold the roles, a player can be in more than one group
        for _, group in ipairs(groups) do
            local seen = {}
            for _, role_name in ipairs(group.roles) do
                local role = Roles.get_role_by_name(role_name)
                for _, player_name in ipairs(role and role:get_player_names() or {}) do
                    if not seen[player_name] then
                        seen[player_name] = true
                        done[player_name] = true
                        group.players[#group.players + 1] = player_name
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
    end) --[[@as any]]
)

--- Content area for the statistics tab
define_tab(
    { "exp-gui_readme.data-tab" },
    { "exp-gui_readme.data-tooltip" },
    Gui.define("readme/data")
    :draw(function(_, parent)
        local container = parent.add{ type = "flow", direction = "vertical" }
        local player_name = Gui.get_player(parent).name

        Gui.elements.title_label(container, title_width, { "exp-gui_readme.data-tab" })
        Gui.elements.centered_label(container, frame_width, { "exp-gui_readme.data-general" })
        Gui.elements.bar(container)
        container.add{ type = "flow" }

        local scroll_pane = Elements.title_table_scroll(container)
        local statistics = scroll_pane.add{ type = "table", column_count = 4, style = "bordered_table" }
        statistics.style.cell_padding = 0
        statistics.style.horizontally_stretchable = true
        for _, name in ipairs(ExpPlayerStatistics.display_order) do
            local value = ExpPlayerStatistics.format(name, ExpPlayerStatistics.get(player_name, name), true)
            local tooltip = { "exp-statistics." .. name .. "-tooltip" }
            Gui.elements.centered_label(statistics, 150, { "exp-statistics." .. name }, tooltip)
            Gui.elements.centered_label(statistics, 130, { "exp-gui_readme.data-format", value, ExpPlayerStatistics.units[name] or "" }, tooltip)
        end

        return container
    end) --[[@as any]]
)

--- @class ExpGui_Readme.elements.container.elements
--- @field pane LuaGuiElement

--- Main readme container
--- @class ExpGui_Readme.elements.container: ExpElement
--- @field data table<LuaGuiElement, ExpGui_Readme.elements.container.elements>
--- @overload fun(parent: LuaGuiElement): LuaGuiElement
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
            local tooltip = tab.tooltip
            if type(tooltip) == "function" then
                tooltip = tooltip()
            end

            local gui_tab = pane.add{
                type = "tab",
                style = "frame_tab",
                caption = tab.caption,
                tooltip = tooltip,
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
            return Roles.player_has_permission(player, "exp_scenario.gui.readme")
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
        [ExpServerList.on_servers_updated] = Elements.join_server.refresh_all,
    },
}
