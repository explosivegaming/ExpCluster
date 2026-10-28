import * as lib from "@clusterio/lib";

declare module "@clusterio/lib" {
	export interface ControllerConfigFields {
		"exp_auto_restart.idle_seconds": number;
		"exp_auto_restart.scope": "host" | "cluster";
		"exp_auto_restart.start_instances": boolean;
		"exp_auto_restart.restart_controller": boolean;
	}
}

export const plugin: lib.PluginDeclaration = {
	name: "exp_auto_restart",
	title: "ExpGaming - Auto Restart",
	description: "Clusterio plugin restarting hosts and the controller once no players are online",

	controllerEntrypoint: "./dist/node/controller.js",
	controllerConfigFields: {
		"exp_auto_restart.idle_seconds": {
			title: "Idle Seconds",
			description: "How long a host must have had no players online before it is restarted",
			type: "number",
			initialValue: 300,
			validator: (value: number) => {
				if (value < 0) {
					throw new Error("Idle seconds cannot be negative");
				}
			},
		},
		"exp_auto_restart.scope": {
			title: "Scope",
			description: "Whether players on other hosts also hold back a restart",
			type: "string",
			enum: ["host", "cluster"],
			initialValue: "host",
		},
		"exp_auto_restart.start_instances": {
			title: "Start Instances",
			description: "Start the instances that were running again once the host is back",
			type: "boolean",
			initialValue: true,
		},
		"exp_auto_restart.restart_controller": {
			title: "Restart Controller",
			description: "Also restart the controller when it needs it and no players are online anywhere",
			type: "boolean",
			initialValue: false,
		},
	},
};
