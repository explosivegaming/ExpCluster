# ExpGaming - Discord Auth

Lets players log in to the web interface with Discord, and links their Factorio accounts to a Discord account. It only uses the OAuth2 `identify` scope, so no bot is needed.

## Setup

1. Create an application in the [Discord developer portal](https://discord.com/developers/applications).
2. Under OAuth2, copy the Client ID and reset the Client Secret to get one.
3. Under OAuth2 → Redirects, add `<controller.public_url>api/exp_discord_auth/callback`. For a controller with `controller.public_url` set to `https://example.com/cluster/` that is `https://example.com/cluster/api/exp_discord_auth/callback`. It must match exactly, including the trailing path and http or https.
4. Set the config on the controller:

```
npx clusterioctl controller config set controller.public_url https://example.com/cluster/
npx clusterioctl controller config set exp_discord_auth.client_id <client id>
npx clusterioctl controller config set exp_discord_auth.client_secret <client secret>
```

`controller.public_url` has to be set, because the redirect URL is built from it and Discord rejects any URL that isn't registered.

## Config

All fields are on the controller.

| Field | Default | Description |
|---|---|---|
| `exp_discord_auth.client_id` | | Application ID of the Discord application. |
| `exp_discord_auth.client_secret` | | OAuth2 client secret of the Discord application. Only readable on the controller. |
| `exp_discord_auth.max_accounts` | 3 | How many Factorio accounts one Discord account can link. |

## Linking

There are two ways to link a Factorio account:

- On the user page, a logged in user clicks Link Discord and approves it on Discord.
- On the login page, a player logs in with Discord and gets a code, then types `/link-discord CODE` on any server. This is how a player who can't log in to the web interface yet links their account.

Linking a Factorio account that is already linked to another Discord account moves it. `/link-discord` without a code shows the current link, and `/unlink-discord` removes it. The user page has an Unlink button too.

Users can always see and remove their own link. The `exp_discord_auth.link.get` and `exp_discord_auth.link.delete` permissions allow it for other users.

Once linked, the Discord tab on the login page has a "Log in as" button for each linked account. Banned users can't log in this way.

Links are stored in `database/exp_discord_auth/accounts.json` on the controller.
