import * as lib from "@clusterio/lib";
import * as messages from "./messages.js";

declare module "@clusterio/lib" {
	export interface ControllerConfigFields {
		"exp_discord_sync.bot_token": string | null;
		"exp_discord_sync.guild_id": string | null;
	}
	export interface Permissions {
		"exp_discord_sync.mapping.update": never;
	}
}

export const plugin: lib.PluginDeclaration = {
	name: "exp_discord_sync",
	title: "ExpGaming - Discord Sync",
	description: "Clusterio plugin giving players linked with exp_discord_auth the Discord roles mapped to their clusterio roles",

	messages: [
		messages.RoleMappingUpdatedEvent,
		messages.RoleMappingUpdateRequest,
		messages.GuildRoleListRequest,
	],

	permissions: [
		{
			name: "exp_discord_sync.mapping.update",
			title: "Update Discord Roles",
			description: "Change which Discord roles are given to players holding a role.",
			grantByDefault: false,
		},
	],

	controllerEntrypoint: "./dist/node/controller.js",
	controllerConfigFields: {
		"exp_discord_sync.bot_token": {
			title: "Bot Token",
			description: "Token of the Discord bot which gives the roles.",
			type: "string",
			credential: ["controller"],
			optional: true,
		},
		"exp_discord_sync.guild_id": {
			title: "Guild ID",
			description: "ID of the Discord server to give roles in.",
			type: "string",
			optional: true,
		},
	},

	webEntrypoint: "./web",
};
