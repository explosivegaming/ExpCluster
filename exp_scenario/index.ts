import * as lib from "@clusterio/lib";
import * as messages from "./messages";

// Defines a permission for every in game action and role flag used by the scenario
import "./permissions";

lib.definePermission({
	name: "exp_scenario.config.view",
	title: "View ExpScenario Config",
	description: "View the config for all submodules of ExpScenario",
});

lib.definePermission({
	name: "exp_scenario.config.edit",
	title: "Edit ExpScenario Config",
	description: "Edit the config for all submodules of ExpScenario",
});

lib.definePermission({
	name: "exp_scenario.seed",
	title: "Seed ExpScenario roles and groups",
	description: "Create the roles and permission groups the scenario shipped with",
});

declare module "@clusterio/lib" {

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

	webEntrypoint: "./web",
};
