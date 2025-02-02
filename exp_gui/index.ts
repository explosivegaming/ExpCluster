import * as lib from "@clusterio/lib";

export const plugin: lib.PluginDeclaration = {
	name: "exp_gui",
	title: "exp_gui",
	description: "Example Description. Plugin. Change me in index.ts",
	instanceEntrypoint: "./dist/node/instance",
};
