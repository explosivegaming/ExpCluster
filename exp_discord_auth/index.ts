import * as lib from "@clusterio/lib";
import * as messages from "./messages.js";

declare module "@clusterio/lib" {
	export interface ControllerConfigFields {
		"exp_discord_auth.client_id": string | null;
		"exp_discord_auth.client_secret": string | null;
		"exp_discord_auth.max_accounts": number;
	}
	export interface Permissions {
		"exp_discord_auth.link.get": never;
		"exp_discord_auth.link.delete": never;
	}
}

export const plugin: lib.PluginDeclaration = {
	name: "exp_discord_auth",
	title: "ExpGaming - Discord Auth",
	description: "Clusterio plugin linking Factorio accounts to Discord accounts and logging in to the web interface with Discord",

	features: [
		"SavePatching",
		"ScriptCommands",
	],

	messages: [
		messages.DiscordLinkRequest,
		messages.DiscordUnlinkRequest,
		messages.DiscordLinkGetRequest,
		messages.DiscordLinkStartRequest,
	],

	permissions: [
		{
			name: "exp_discord_auth.link.get",
			title: "Get Discord Links",
			description: "See which Discord account any user is linked to, users can always see their own.",
			grantByDefault: false,
		},
		{
			name: "exp_discord_auth.link.delete",
			title: "Remove Discord Links",
			description: "Unlink any user from their Discord account, users can always unlink themselves.",
			grantByDefault: false,
		},
	],

	instanceEntrypoint: "./dist/node/instance.js",

	controllerEntrypoint: "./dist/node/controller.js",
	controllerConfigFields: {
		"exp_discord_auth.client_id": {
			title: "Client ID",
			description: "Application ID of the Discord application used for logging in.",
			type: "string",
			optional: true,
		},
		"exp_discord_auth.client_secret": {
			title: "Client Secret",
			description: "OAuth2 client secret of the Discord application used for logging in.",
			type: "string",
			credential: ["controller"],
			optional: true,
		},
		"exp_discord_auth.max_accounts": {
			title: "Max Accounts",
			description: "Number of Factorio accounts which can be linked to one Discord account.",
			type: "number",
			initialValue: 3,
		},
	},

	webEntrypoint: "./web",
};
