import * as lib from "@clusterio/lib";

export const plugin: lib.PluginDeclaration = {
	name: "exp_legacy",
	title: "ExpGaming - Legacy",
	description: "Clusterio plugin implementing the legacy v6 scenario updated for factorio 2.0",
	instanceEntrypoint: "./dist/node/instance.js",
};
