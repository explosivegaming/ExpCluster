import * as lib from "@clusterio/lib";
import * as messages from "./messages";
import { permissions as scenarioPermissions, type ScenarioPermissionName } from "./permissions";

declare module "@clusterio/lib" {
	// Everything checked in game through exp_roles, plus the permissions checked on the controller
	export interface Permissions extends Record<ScenarioPermissionName, never> {
		"exp_scenario.config.view": never;
		"exp_scenario.config.edit": never;
		"exp_scenario.seed": never;
	}
}

export const plugin: lib.PluginDeclaration = {
	name: "exp_scenario",
	title: "exp_scenario",
	description: "Example Description. Plugin. Change me in index.ts",
	controllerEntrypoint: "./dist/node/controller",
	instanceEntrypoint: "./dist/node/instance",

	messages: [
		messages.SeedRequest,
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
	],

	webEntrypoint: "./web",
};
