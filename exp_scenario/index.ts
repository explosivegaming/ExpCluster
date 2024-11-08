import * as lib from "@clusterio/lib";
import * as Messages from "./messages";

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

declare module "@clusterio/lib" {

}

export const plugin: lib.PluginDeclaration = {
	name: "exp_scenario",
	title: "exp_scenario",
	description: "Example Description. Plugin. Change me in index.ts",
	controllerEntrypoint: "./dist/node/controller",
	instanceEntrypoint: "./dist/node/instance",

	messages: [
	],

	webEntrypoint: "./web",
	routes: [
		"/exp_scenario",
	],
};
