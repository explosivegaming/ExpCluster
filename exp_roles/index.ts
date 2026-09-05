import * as lib from "@clusterio/lib";
import * as messages from "./messages";

declare module "@clusterio/lib" {
	export interface InstanceConfigFields {
		"exp_roles.sync_mode": "disabled" | "enabled" | "bidirectional";
	}
}

// The in game properties of a role are part of the role, so they are covered by
// the core role permissions rather than permissions of their own. Assignments
// are only ever sent between the controller and an instance, so they need none.

export const plugin: lib.PluginDeclaration = {
	name: "exp_roles",
	title: "ExpGaming - Roles",
	description: "Clusterio plugin providing syncing of in game roles",

	features: [
		"SavePatching",
		"ScriptCommands",
	],

	messages: [
		messages.RoleUpdatedEvent,
		messages.AssignmentUpdatedEvent,

		messages.RoleListRequest,
		messages.RoleMetaUpdateRequest,

		messages.AssignmentListRequest,
		messages.AssignmentUpdateRequest,
	],

	instanceEntrypoint: "./dist/node/instance",
	instanceConfigFields: {
		"exp_roles.sync_mode": {
			description: "Synchronize in game roles with the controller",
			type: "string",
			enum: ["disabled", "enabled", "bidirectional"],
			initialValue: "bidirectional",
		},
	},

	controllerEntrypoint: "./dist/node/controller",
	controllerConfigFields: {
	},

	webEntrypoint: "./web",
};
