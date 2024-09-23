import * as lib from "@clusterio/lib";

export const plugin: lib.PluginDeclaration = {
	name: "exp_legacy",
	title: "exp_legacy",
	description: "Example Description. Plugin. Change me in index.ts",
	instanceEntrypoint: "./dist/node/instance",
};
