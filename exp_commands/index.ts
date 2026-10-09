import * as lib from "@clusterio/lib";

export const plugin: lib.PluginDeclaration = {
	name: "exp_commands",
	title: "ExpGaming - Commands",
	description: "Clusterio plugin providing a Lua command processing library.",
	instanceEntrypoint: "./dist/node/instance.js",
};
