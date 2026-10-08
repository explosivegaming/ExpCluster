import * as lib from "@clusterio/lib";
import * as messages from "./messages.js";

declare module "@clusterio/lib" {
	export interface InstanceConfigFields {
		"exp_server_list.short_name": string;
		"exp_server_list.description": string;
		"exp_server_list.welcome": string;
		"exp_server_list.reset_time": string;
		"exp_server_list.hidden": boolean;
	}

	export interface Permissions {
		"exp_server_list.list": never;
	}
}

export const plugin: lib.PluginDeclaration = {
	name: "exp_server_list",
	title: "ExpGaming - Server List",
	description: "Clusterio plugin sharing the details of every instance with the others",

	controllerEntrypoint: "./dist/node/controller.js",
	instanceEntrypoint: "./dist/node/instance.js",
	instanceConfigFields: {
		"exp_server_list.short_name": {
			title: "Short Name",
			description: "Name shown in the server list, the instance name when empty",
			type: "string",
			initialValue: "",
		},
		"exp_server_list.description": {
			title: "Description",
			description: "One line about the server shown in the server list",
			type: "string",
			initialValue: "",
		},
		"exp_server_list.welcome": {
			title: "Welcome",
			description: "Message shown on the welcome tab of the readme",
			type: "string",
			initialValue: "",
		},
		"exp_server_list.reset_time": {
			title: "Reset Time",
			description: "When the map next resets, shown on the welcome tab of the readme",
			type: "string",
			initialValue: "",
		},
		"exp_server_list.hidden": {
			title: "Hidden",
			description: "Leave this instance out of the server list on other instances",
			type: "boolean",
			initialValue: false,
		},
	},

	messages: [
		messages.ServerUpdatesEvent,
		messages.ServerListRequest,
	],

	permissions: [
		{
			name: "exp_server_list.list",
			title: "List servers",
			description: "View the server list and subscribe to its updates",
		},
	],
};
