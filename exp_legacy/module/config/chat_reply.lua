--- This file defines the different triggers for the chat bot
-- @config Chat-Reply

local Async = require 'expcore.async'
local format_time = _C.format_time --- @dep expcore.common

-- eg Async(async_message, is_command or player, message)
local async_message = Async.register(function(player, message)
    if player == true then game.print(message) else player.print(message) end
end)

-- luacheck:ignore 212/player 212/is_command
return {
    allow_command_prefix_for_messages = true, --- @setting allow_command_prefix_for_messages when true any message trigger will print to all player when prefixed
    messages = { --- @setting messages will trigger when ever the word is said
        ['discord'] = {'info.discord'},
        ['expgaming'] = {'info.website'},
        ['website'] = {'info.website'},
        ['status'] = {'info.status'},
        ['github'] = {'info.github'},
        ['patreon'] = {'info.patreon'},
        ['donate'] = {'info.patreon'},
        ['command'] = {'info.custom-commands'},
        ['commands'] = {'info.custom-commands'},
        ['softmod'] = {'info.softmod'},
        ['script'] = {'info.softmod'},
        ['loop'] = {'chat-bot.loops'},
        ['rhd'] = {'info.lhd'},
        ['lhd'] = {'info.lhd'},
        ['roundabout'] = {'chat-bot.loops'},
        ['roundabouts'] = {'chat-bot.loops'},
        ['redmew'] = {'info.redmew'},
        ['afk'] = function(player, _is_command)
            local max = player
            for _, next_player in pairs(game.connected_players) do
                if max.afk_time < next_player.afk_time then
                    max = next_player
                end
            end
            return {'chat-bot.afk', max.name, format_time(max.afk_time, {minutes = true, seconds = true, long = true})}
        end,
        ['players'] = function(_player, _is_command)
            return {'chat-bot.players', #game.players}
        end,
        ['online'] = function(_player, _is_command)
            return {'chat-bot.players-online', #game.connected_players}
        end,
        ['r!verify'] = function(player, _is_command)
            return {'chat-bot.verify', player.name}
        end,
    },
    command_admin_only = false, --- @setting command_admin_only when true will only allow chat commands for admins
    command_permission = 'command/chat-bot', --- @setting command_permission the permission used to allow command prefixes
    command_prefix = '!', --- @setting command_prefix prefix used for commands below and to print to all players (if enabled above)
    commands = { --- @setting commands will trigger only when command prefix is given
        ['dev'] = {'chat-bot.not-real-dev'},
        ['blame'] = function(player, _is_command)
            local names = {'Cooldude2606', 'arty714', 'badgamernl', 'mark9064', 'aldldl', 'Drahc_pro', player.name}
            for _, next_player in pairs(game.connected_players) do
                names[#names + 1] = next_player.name
            end
            return {'chat-bot.blame', table.get_random_dictionary_entry(names)}
        end,
        ['magic'] = {'chat-bot.magic'},
        ['aids'] = {'chat-bot.aids'},
        ['riot'] = {'chat-bot.riot'},
        ['lenny'] = {'chat-bot.lenny'},
        ['hodor'] = function(_player, _is_command)
            local options = {'?', '.', '!', '!!!'}
            return {'chat-bot.hodor', table.get_random_dictionary_entry(options)}
        end,
        ['evolution'] = function(_player, _is_command)
            return {'chat-bot.current-evolution', string.format('%.2f', game.forces['enemy'].evolution_factor)}
        end,
        ['makepopcorn'] = function(player, _is_command)
            local timeout = math.floor(180*(math.random()+0.5))
            Async(async_message, true, {'chat-bot.reply', {'chat-bot.get-popcorn-1'}})
            Async.wait(timeout, async_message, true, {'chat-bot.reply', {'chat-bot.get-popcorn-2', player.name}})
        end,
        ['passsomesnaps'] = function(player, _is_command)
            local timeout = math.floor(180*(math.random()+0.5))
            Async(async_message, player, {'chat-bot.reply', {'chat-bot.get-snaps-1'}})
            Async.wait(timeout, async_message, true, {'chat-bot.reply', {'chat-bot.get-snaps-2', player.name}})
            Async.wait(timeout*(math.random()+0.5), async_message, true, {'chat-bot.reply', {'chat-bot.get-snaps-3', player.name}})
        end,
        ['makecocktail'] = function(player, _is_command)
            local timeout = math.floor(180*(math.random()+0.5))
            Async(async_message, true, {'chat-bot.reply', {'chat-bot.get-cocktail-1'}})
            Async.wait(timeout, async_message, true, {'chat-bot.reply', {'chat-bot.get-cocktail-2', player.name}})
            Async.wait(timeout*(math.random()+0.5), async_message, true, {'chat-bot.reply', {'chat-bot.get-cocktail-3', player.name}})
        end,
        ['makecoffee'] = function(player, _is_command)
            local timeout = math.floor(180*(math.random()+0.5))
            Async(async_message, true, {'chat-bot.reply', {'chat-bot.make-coffee-1'}})
            Async.wait(timeout, async_message, true, {'chat-bot.reply', {'chat-bot.make-coffee-2', player.name}})
        end,
        ['orderpizza'] = function(player, _is_command)
            local timeout = math.floor(180*(math.random()+0.5))
            Async(async_message, true, {'chat-bot.reply', {'chat-bot.order-pizza-1'}})
            Async.wait(timeout, async_message, true, {'chat-bot.reply', {'chat-bot.order-pizza-2', player.name}})
            Async.wait(timeout*(math.random()+0.5), async_message, true, {'chat-bot.reply', {'chat-bot.order-pizza-3', player.name}})
        end,
        ['maketea'] = function(player, _is_command)
            local timeout = math.floor(180*(math.random()+0.5))
            Async(async_message, true, {'chat-bot.reply', {'chat-bot.make-tea-1'}})
            Async.wait(timeout, async_message, true, {'chat-bot.reply', {'chat-bot.make-tea-2', player.name}})
        end,
        ['meadplease'] = function(player, _is_command)
            local timeout = math.floor(180*(math.random()+0.5))
            Async(async_message, true, {'chat-bot.reply', {'chat-bot.get-mead-1'}})
            Async.wait(timeout, async_message, true, {'chat-bot.reply', {'chat-bot.get-mead-2', player.name}})
        end,
        ['passabeer'] = function(player, _is_command)
            local timeout = math.floor(180*(math.random()+0.5))
            Async(async_message, true, {'chat-bot.reply', {'chat-bot.get-beer-1'}})
            Async.wait(timeout, async_message, true, {'chat-bot.reply', {'chat-bot.get-beer-2', player.name}})
        end
    }
}
