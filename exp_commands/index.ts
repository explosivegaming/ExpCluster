import * as lib from "@clusterio/lib";

export const plugin: lib.PluginDeclaration = {
	name: "exp_commands",
	title: "exp_commands",
	description: "Example Description. Plugin. Change me in index.ts",
	instanceEntrypoint: "./dist/node/instance",
};
