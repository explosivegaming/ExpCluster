import * as lib from "@clusterio/lib";
import * as messages from "./messages.js";

declare module "@clusterio/lib" {
	export interface Permissions {
		"exp_player_statistics.view": never;
	}
}

export const plugin: lib.PluginDeclaration = {
	name: "exp_player_statistics",
	title: "ExpGaming - Player Statistics",
	description: "Clusterio plugin keeping player statistics on the controller",

	controllerEntrypoint: "./dist/node/controller.js",
	instanceEntrypoint: "./dist/node/instance.js",

	messages: [
		messages.StatisticsUpdateEvent,
		messages.PlayerStatisticsUpdatedEvent,
		messages.StatisticsGetRequest,
		messages.StatisticsListRequest,
	],

	permissions: [
		{
			name: "exp_player_statistics.view",
			title: "View player statistics",
			description: "View the statistics of every player and subscribe to their updates",
			grantByDefault: true,
		},
	],

	webEntrypoint: "./web",
	routes: [
		"/exp_player_statistics",
	],
};
