import * as lib from "@clusterio/lib";

export const plugin: lib.PluginDeclaration = {
	name: "exp_server_ups",
	title: "ExpGaming Server UPS",
	description: "Clusterio plugin providing in game server ups counter",
	instanceEntrypoint: "./dist/node/instance",
};
