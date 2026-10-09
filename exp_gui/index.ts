import * as lib from "@clusterio/lib";

export const plugin: lib.PluginDeclaration = {
	name: "exp_gui",
	title: "ExpGaming - GUI",
	description: "Clusterio plugin providing a Lua GUI definition library.",
	instanceEntrypoint: "./dist/node/instance.js",
};
