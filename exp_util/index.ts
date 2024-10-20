import * as lib from "@clusterio/lib";

export const plugin: lib.PluginDeclaration = {
	name: "exp_util",
	title: "ExpGaming Module Utilities",
	description: "Provides extensions and overrides of base Lua library functions, and provides utility modules for improved module compatibly",
	instanceEntrypoint: "./dist/node/instance",
};
