import * as lib from "@clusterio/lib";
import * as messages from "./messages.js";
import { permissions as scenarioPermissions, type ScenarioPermissionName } from "./permissions.js";

declare module "@clusterio/lib" {
	// Everything checked in game through exp_roles, plus the permissions checked on the controller
	export interface Permissions extends Record<ScenarioPermissionName, never> {
		"exp_scenario.config.view": never;
		"exp_scenario.config.edit": never;
		"exp_scenario.seed": never;
		"exp_scenario.join_message.set": never;
		"exp_scenario.join_message.set_other": never;
	}
}

export const plugin: lib.PluginDeclaration = {
	name: "exp_scenario",
	title: "ExpGaming - Scenario",
	description: "Clusterio plugin implementing the Explosive Gaming scenario.",
	controllerEntrypoint: "./dist/node/controller.js",
	instanceEntrypoint: "./dist/node/instance.js",

	messages: [
		messages.SeedRequest,
		messages.FeatureUpdatedEvent,
		messages.FeatureListRequest,
		messages.FeatureUpdateRequest,
		messages.PlayerGetRequest,
		messages.JoinMessageSetRequest,
		messages.PlayerToolbarEvent,
	],

	permissions: [
		...scenarioPermissions,
		{
			name: "exp_scenario.config.view",
			title: "View ExpScenario Config",
			description: "View the config for all submodules of ExpScenario",
		},
		{
			name: "exp_scenario.config.edit",
			title: "Edit ExpScenario Config",
			description: "Edit the config for all submodules of ExpScenario",
		},
		{
			name: "exp_scenario.seed",
			title: "Seed ExpScenario roles and groups",
			description: "Create the roles and permission groups the scenario shipped with",
		},
		{
			name: "exp_scenario.join_message.set",
			title: "Set own join message",
			description: "Set the message shown to everyone when you join, in game this is /set-join-message",
		},
		{
			name: "exp_scenario.join_message.set_other",
			title: "Set join messages of others",
			description: "Set the message shown to everyone when another user joins",
		},
	],

	webEntrypoint: "./web",
	routes: [
		"/scenario_features",
	],
};
