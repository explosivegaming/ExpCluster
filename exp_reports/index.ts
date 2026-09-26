import * as lib from "@clusterio/lib";
import * as messages from "./messages.js";

declare module "@clusterio/lib" {
	export interface ControllerConfigFields {
		"exp_reports.discord_webhook_url": string | null;
		"exp_reports.json_webhook_url": string | null;
	}
	export interface Permissions {
		"exp_reports.report.get": never;
		"exp_reports.report.list": never;
		"exp_reports.report.subscribe": never;
		"exp_reports.report.create": never;
		"exp_reports.report.delete": never;
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

		messages.ReportListRequest,
		messages.ReportGetRequest,
		messages.ReportCreateRequest,
		messages.ReportDeleteRequest,
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
	],

	instanceEntrypoint: "./dist/node/instance.js",

	controllerEntrypoint: "./dist/node/controller.js",
	controllerConfigFields: {
		"exp_reports.discord_webhook_url": {
			title: "Discord Webhook URL",
			description: "Discord channel webhook which new reports are posted to as an embed.",
			type: "string",
			optional: true,
		},
		"exp_reports.json_webhook_url": {
			title: "JSON Webhook URL",
			description: "URL which new reports are posted to as JSON.",
			type: "string",
			optional: true,
		},
	},

	webEntrypoint: "./web",
	routes: [
		"/reports",
	],
};
