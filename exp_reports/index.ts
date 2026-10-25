import * as lib from "@clusterio/lib";
import * as messages from "./messages.js";

declare module "@clusterio/lib" {
	export interface ControllerConfigFields {
		"exp_reports.discord_webhook_url": string | null;
		"exp_reports.json_webhook_url": string | null;
		"exp_reports.watch_unread_reports": boolean;
		"exp_reports.announce_to_all_instances": boolean;
	}
	export interface Permissions {
		"exp_reports.report.get": never;
		"exp_reports.report.list": never;
		"exp_reports.report.subscribe": never;
		"exp_reports.report.create": never;
		"exp_reports.report.delete": never;
		"exp_reports.report.mark_read": never;
		"exp_reports.watch_list.subscribe": never;
		"exp_reports.watch_list.add": never;
		"exp_reports.watch_list.remove": never;
	}
}

export const plugin: lib.PluginDeclaration = {
	name: "exp_reports",
	title: "ExpGaming - Reports",
	description: "Clusterio plugin storing player reports on the controller",

	features: [
		"SavePatching",
		"ScriptCommands",
	],

	messages: [
		messages.ReportUpdatedEvent,
		messages.WatchListUpdatedEvent,
		messages.WatchedPlayerJoinedEvent,

		messages.ReportListRequest,
		messages.ReportGetRequest,
		messages.ReportCreateRequest,
		messages.ReportDeleteRequest,
		messages.ReportSetReadRequest,

		messages.WatchListAddRequest,
		messages.WatchListRemoveRequest,
	],

	permissions: [
		{
			name: "exp_reports.report.get",
			title: "Get Reports",
			description: "Retrieve a specific report by id.",
			grantByDefault: true,
		},
		{
			name: "exp_reports.report.list",
			title: "List Reports",
			description: "List the reports against every player, or against one player.",
			grantByDefault: true,
		},
		{
			name: "exp_reports.report.subscribe",
			title: "Subscribe to Report Updates",
			description: "Receive updates when reports are made or deleted.",
			grantByDefault: true,
		},
		{
			name: "exp_reports.report.create",
			title: "Create Reports",
			description: "Report a player.",
			grantByDefault: false,
		},
		{
			name: "exp_reports.report.delete",
			title: "Delete Reports",
			description: "Delete reports made against a player.",
			grantByDefault: false,
		},
		{
			name: "exp_reports.report.mark_read",
			title: "Mark Reports Read",
			description: "Mark reports as read or unread.",
			grantByDefault: false,
		},
		{
			name: "exp_reports.watch_list.subscribe",
			title: "Subscribe to Watch List Updates",
			description: "See the watch list and receive updates when players are added or removed.",
			grantByDefault: true,
		},
		{
			name: "exp_reports.watch_list.add",
			title: "Add to Watch List",
			description: "Add a player to the watch list.",
			grantByDefault: false,
		},
		{
			name: "exp_reports.watch_list.remove",
			title: "Remove from Watch List",
			description: "Remove a player from the watch list.",
			grantByDefault: false,
		},
	],

	instanceEntrypoint: "./dist/node/instance.js",

	controllerEntrypoint: "./dist/node/controller.js",
	controllerConfigFields: {
		"exp_reports.discord_webhook_url": {
			title: "Discord Webhook URL",
			description: "Discord channel webhook which new reports and watched player joins are posted to as an embed.",
			type: "string",
			optional: true,
		},
		"exp_reports.json_webhook_url": {
			title: "JSON Webhook URL",
			description: "URL which new reports and watched player joins are posted to as JSON.",
			type: "string",
			optional: true,
		},
		"exp_reports.watch_unread_reports": {
			title: "Watch Unread Reports",
			description: "Treat players with unread reports as if they were on the watch list.",
			type: "boolean",
			initialValue: false,
		},
		"exp_reports.announce_to_all_instances": {
			title: "Announce to All Instances",
			description: "Tell admins on every instance when a watched player joins, instead of only the instance they joined.",
			type: "boolean",
			initialValue: true,
		},
	},

	webEntrypoint: "./web",
	routes: [
		"/reports",
	],
};
