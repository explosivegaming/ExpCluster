--- This file defines the different triggers for the chat bot
-- @config Chat-Reply

local ExpUtil = require("modules/exp_util")
local Async = require("modules/exp_util/async")

local floor = math.floor
local random = math.random
local format_string = string.format
local locale_reply = "exp_chat-auto-reply.chat-reply"

local send_message_async =
    Async.register(function(player, message)
        if player == nil then
            game.print(message)
        else
            player.print(message)
        end
    end)

local afk_time_units = {
    minutes = true,
    seconds = true,
}

return {
    messages = { --- @setting messages will trigger when ever the word is said
        ["discord"] = { "info.discord" },
        ["expgaming"] = { "info.website" },
        ["website"] = { "info.website" },
        ["status"] = { "info.status" },
        ["github"] = { "info.github" },
        ["patreon"] = { "info.patreon" },
        ["donate"] = { "info.patreon" },
        ["command"] = { "info.custom-commands" },
        ["commands"] = { "info.custom-commands" },
        ["softmod"] = { "info.softmod" },
        ["plugin"] = { "info.softmod" },
        ["script"] = { "info.softmod" },
        ["redmew"] = { "info.redmew" },
        ["comfy"] = { "info.redmew" },
        ["rhd"] = { "info.lhd" },
        ["lhd"] = { "info.lhd" },
        ["loop"] = { "exp_chat-auto-reply.reply-loops" },
        ["roundabout"] = { "exp_chat-auto-reply.reply-loops" },
        ["roundabouts"] = { "exp_chat-auto-reply.reply-loops" },
        ["clusterio"] = { "exp_chat-auto-reply.reply-clusterio" },
        ["players"] = function()
            return { "exp_chat-auto-reply.reply-players", #game.players }
        end,
        ["online"] = function()
            return { "exp_chat-auto-reply.reply-online", #game.connected_players }
        end,
        ["afk"] = function(player)
            local max = player
            for _, next_player in pairs(game.connected_players) do
                if max.afk_time < next_player.afk_time then
                    max = next_player
                end
            end

            return { "exp_chat-auto-reply.reply-afk", max.name, ExpUtil.format_time_locale(max.afk_time, "long", afk_time_units) }
        end,
    },
    allow_command_prefix_for_messages = true, --- @setting allow_command_prefix_for_messages when true any message trigger will print to all player when prefixed
    command_admin_only = false, --- @setting command_admin_only when true will only allow chat commands for admins
    command_permission = "command/chat-commands", --- @setting command_permission the permission used to allow command prefixes
    command_prefix = "!", --- @setting command_prefix prefix used for commands below and to print to all players (if enabled above)
    commands = { --- @setting commands will trigger only when command prefix is given
        ["dev"] = { "exp_chat-auto-reply.reply-dev" },
        ["magic"] = { "exp_chat-auto-reply.reply-magic" },
        ["aids"] = { "exp_chat-auto-reply.reply-aids" },
        ["riot"] = { "exp_chat-auto-reply.reply-riot" },
        ["lenny"] = { "exp_chat-auto-reply.reply-lenny" },
        ["blame"] = function(player)
            local names = { "Cooldude2606", "arty714", "badgamernl", "mark9064", "aldldl", "Drahc_pro", player.name }
            for _, next_player in pairs(game.connected_players) do
                names[#names + 1] = next_player.name
            end

            return { "exp_chat-auto-reply.reply-blame", table.get_random(names) }
        end,
        ["hodor"] = function()
            local options = { "?", ".", "!", "!!!" }
            return { "exp_chat-auto-reply.reply-hodor", table.get_random(options) }
        end,
        ["evolution"] = function(player)
            return { "exp_chat-auto-reply.reply-evolution", format_string("%.2f", game.forces["enemy"].get_evolution_factor(player.surface)) }
        end,
        ["makepopcorn"] = function(player)
            local timeout = floor(180 * (random() + 0.5))
            send_message_async:start_after(timeout, nil, { locale_reply, { "exp_chat-auto-reply.reply-popcorn-2", player.name } })
            return { locale_reply, { "exp_chat-auto-reply.reply-popcorn-1" } }
        end,
        ["passsomesnaps"] = function(player)
            local timeout = floor(180 * (random() + 0.5))
            send_message_async:start_after(timeout, nil, { locale_reply, { "exp_chat-auto-reply.reply-snaps-2", player.name } })
            send_message_async:start_after(timeout * (random() + 0.5), nil, { locale_reply, { "exp_chat-auto-reply.reply-snaps-3", player.name } })
            return { locale_reply, { "exp_chat-auto-reply.reply-snaps-1" } }
        end,
        ["makecocktail"] = function(player)
            local timeout = floor(180 * (random() + 0.5))
            send_message_async:start_after(timeout, nil, { locale_reply, { "exp_chat-auto-reply.reply-cocktail-2", player.name } })
            send_message_async:start_after(timeout * (random() + 0.5), nil, { locale_reply, { "exp_chat-auto-reply.reply-cocktail-3", player.name } })
            return { locale_reply, { "exp_chat-auto-reply.reply-cocktail-1" } }
        end,
        ["makecoffee"] = function(player)
            local timeout = floor(180 * (random() + 0.5))
            send_message_async:start_after(timeout, nil, { locale_reply, { "exp_chat-auto-reply.reply-coffee-2", player.name } })
            return { locale_reply, { "exp_chat-auto-reply.reply-coffee-1" } }
        end,
        ["orderpizza"] = function(player)
            local timeout = floor(180 * (random() + 0.5))
            send_message_async:start_after(timeout, nil, { locale_reply, { "exp_chat-auto-reply.reply-pizza-2", player.name } })
            send_message_async:start_after(timeout * (random() + 0.5), nil, { locale_reply, { "exp_chat-auto-reply.reply-pizza-3", player.name } })
            return { locale_reply, { "exp_chat-auto-reply.reply-pizza-1" } }
        end,
        ["maketea"] = function(player)
            local timeout = floor(180 * (random() + 0.5))
            send_message_async:start_after(timeout, nil, { locale_reply, { "exp_chat-auto-reply.reply-tea-2", player.name } })
            return { locale_reply, { "exp_chat-auto-reply.reply-tea-1" } }
        end,
        ["meadplease"] = function(player)
            local timeout = floor(180 * (random() + 0.5))
            send_message_async:start_after(timeout, nil, { locale_reply, { "exp_chat-auto-reply.reply-mead-2", player.name } })
            return { locale_reply, { "exp_chat-auto-reply.reply-mead-1" } }
        end,
        ["passabeer"] = function(player)
            local timeout = floor(180 * (random() + 0.5))
            send_message_async:start_after(timeout, nil, { locale_reply, { "exp_chat-auto-reply.reply-beer-2", player.name } })
            return { locale_reply, { "exp_chat-auto-reply.reply-beer-1" } }
        end,
    },
}
