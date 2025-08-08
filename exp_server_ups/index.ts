import * as lib from "@clusterio/lib";

declare module "@clusterio/lib" {
	export interface InstanceConfigFields {
		"exp_server_ups.update_interval": number;
		"exp_server_ups.average_interval": number;
	}
}

export const plugin: lib.PluginDeclaration = {
	name: "exp_server_ups",
	title: "ExpGaming - Server UPS",
	description: "Clusterio plugin providing in game server ups counter",

	instanceEntrypoint: "./dist/node/instance",
	instanceConfigFields: {
		"exp_server_ups.update_interval": {
			title: "Update Interval",
			description: "Frequency at which updates are exchanged with factorio (ms)",
			type: "number",
			initialValue: 1000,
		},
		"exp_server_ups.average_interval": {
			title: "Average Interval",
			description: "Number of update intervals to average updates per second across",
			type: "number",
			initialValue: 60
		},
	},
};
