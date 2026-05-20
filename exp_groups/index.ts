import * as lib from "@clusterio/lib";

declare module "@clusterio/lib" {
	export interface InstanceConfigFields {
	}
	export interface ControllerConfigFields {
	}
}

export const plugin: lib.PluginDeclaration = {
	name: "exp_groups",
	title: "ExpGaming - Permission Groups",
	description: "Clusterio plugin providing syncing of permission groups",

	instanceEntrypoint: "./dist/node/instance",
	instanceConfigFields: {
	},

	controllerEntrypoint: "./dist/node/controller",
	controllerConfigFields: {
	},
};
