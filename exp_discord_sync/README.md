# ExpGaming - Discord Sync

Gives players the Discord roles that match their clusterio roles. Only players who linked their Factorio account with [Discord Auth](../exp_discord_auth/README.md) get roles, and only the Discord roles picked on a role page are ever added or removed.

## Setup

1. In the [Discord developer portal](https://discord.com/developers/applications), open the application (the one used by Discord Auth is fine) and go to Bot. Reset the token to get one, and turn on Server Members Intent.
2. Invite the bot to the server with the Manage Roles permission: `https://discord.com/oauth2/authorize?client_id=<client id>&scope=bot&permissions=268435456`.
3. In the server settings, drag the bot's role above every role it should give. Discord refuses changes to roles above the bot's highest role.
4. Turn on Developer Mode in Discord, right click the server and Copy Server ID.
5. Set the config on the controller:

```
npx clusterioctl controller config set exp_discord_sync.bot_token <bot token>
npx clusterioctl controller config set exp_discord_sync.guild_id <server id>
```

Without Server Members Intent the bot still syncs roles, but a player who joins the Discord server after linking only gets their roles at the next sync instead of straight away.

## Config

All fields are on the controller.

| Field | Default | Description |
|---|---|---|
| `exp_discord_sync.bot_token` | | Token of the Discord bot. Only readable on the controller. |
| `exp_discord_sync.guild_id` | | ID of the Discord server to give roles in. |

## Role mapping

Each role page has a Discord Roles section. Pick roles from the list, which comes from the bot, or type a role ID. Changing it needs the `exp_discord_sync.mapping.update` permission, which nobody has by default. The plugin doesn't compare the editor's own roles against the ones they map, so only give this permission to cluster admins.

A linked player gets every Discord role mapped to any clusterio role held by any of the Factorio accounts linked to their Discord account. A mapped Discord role the player shouldn't have is removed. Roles which are not mapped are never touched, and neither are members who haven't linked.

Removing a role from the mapping, or deleting the clusterio role, leaves that Discord role on the members who have it.

Mappings are stored in `database/exp_discord_sync/role_mappings.json` on the controller.

## When roles are synced

- A player links or unlinks their Discord account.
- A user's clusterio roles change.
- A linked player joins the Discord server (needs Server Members Intent).
- A role mapping changes, which syncs every linked player.
- The bot connects to Discord, which syncs every linked player. This happens on startup and whenever the connection to Discord drops and comes back, so joins missed while disconnected are caught up.

Requests go to Discord one at a time and wait when Discord answers with a rate limit.
