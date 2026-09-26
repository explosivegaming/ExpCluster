import * as lib from "@clusterio/lib";
import * as messages from "./messages.js";

export * from "./messages.js";
export type { ControllerPlugin } from "./controller.js";

declare module "@clusterio/lib" {
	export interface InstanceConfigFields {
		"exp_groups.sync_mode": "enabled" | "disabled" | "bidirectional"
	}
	export interface ControllerConfigFields {
	}
}

export const plugin: lib.PluginDeclaration = {
	name: "exp_groups",
	title: "ExpGaming - Permission Groups",
	description: "Clusterio plugin providing syncing of permission groups",

	features: [
		"SavePatching",
		"ScriptCommands",
	],

	messages: [
		messages.GroupUpdatedEvent,
		messages.ManualAssignmentUpdatedEvent,
		messages.ResolvedAssignmentUpdatedEvent,
		messages.RoleMappingUpdatedEvent,

		messages.GroupCreateRequest,
		messages.GroupUpdateRequest,
		messages.GroupDeleteRequest,
		messages.GroupGetRequest,
		messages.GroupListRequest,

		messages.AssignmentCreateRequest,
		messages.AssignmentUpdateRequest,
		messages.AssignmentDeleteRequest,
		messages.AssignmentGetRequest,
		messages.AssignmentListRequest,

		messages.RoleMappingCreateRequest,
		messages.RoleMappingUpdateRequest,
		messages.RoleMappingDeleteRequest,
		messages.RoleMappingGetRequest,
		messages.RoleMappingListRequest,
	],

	permissions: [
		// Group permissions

		{
			name: "exp_groups.group.get",
			title: "Get Groups",
			description: "Retrieve a specific Factorio permission group by ID.",
			grantByDefault: true,
		},
		{
			name: "exp_groups.group.list",
			title: "List Groups",
			description: "List all Factorio permission groups.",
			grantByDefault: true,
		},
		{
			name: "exp_groups.group.subscribe",
			title: "Subscribe to Group Updates",
			description: "Receive updates when Factorio permission groups change.",
			grantByDefault: true,
		},
		{
			name: "exp_groups.group.create",
			title: "Create Groups",
			description: "Create new Factorio permission groups.",
			grantByDefault: false,
		},
		{
			name: "exp_groups.group.update",
			title: "Update Groups",
			description: "Modify existing Factorio permission groups.",
			grantByDefault: false,
		},
		{
			name: "exp_groups.group.delete",
			title: "Delete Groups",
			description: "Delete Factorio permission groups.",
			grantByDefault: false,
		},

		// Assignment permissions

		{
			name: "exp_groups.assignment.get",
			title: "Get Assignments",
			description: "Retrieve a specific manual group assignment for a player.",
			grantByDefault: true,
		},
		{
			name: "exp_groups.assignment.list",
			title: "List Assignments",
			description: "List all manual group assignments.",
			grantByDefault: true,
		},
		{
			name: "exp_groups.assignment.subscribe",
			title: "Subscribe to Assignment Updates",
			description: "Receive updates when manual group assignments change.",
			grantByDefault: true,
		},
		{
			name: "exp_groups.assignment.create",
			title: "Create Assignments",
			description: "Manually assign players to groups, overriding role mappings.",
			grantByDefault: false,
		},
		{
			name: "exp_groups.assignment.update",
			title: "Update Assignments",
			description: "Modify existing manual group assignments.",
			grantByDefault: false,
		},
		{
			name: "exp_groups.assignment.delete",
			title: "Delete Assignments",
			description: "Remove manual group assignments.",
			grantByDefault: false,
		},

		// Role mapping permissions

		{
			name: "exp_groups.role_mapping.get",
			title: "Get Role Mappings",
			description: "Retrieve a specific role mapping rule.",
			grantByDefault: true,
		},
		{
			name: "exp_groups.role_mapping.list",
			title: "List Role Mappings",
			description: "List all role mapping rules.",
			grantByDefault: true,
		},
		{
			name: "exp_groups.role_mapping.subscribe",
			title: "Subscribe to Role Mapping Updates",
			description: "Receive updates when role mapping rules change.",
			grantByDefault: true,
		},
		{
			name: "exp_groups.role_mapping.create",
			title: "Create Role Mappings",
			description: "Create rules that map user roles to Factorio permission groups.",
			grantByDefault: false,
		},
		{
			name: "exp_groups.role_mapping.update",
			title: "Update Role Mappings",
			description: "Modify existing role mapping rules.",
			grantByDefault: false,
		},
		{
			name: "exp_groups.role_mapping.delete",
			title: "Delete Role Mappings",
			description: "Delete role mapping rules.",
			grantByDefault: false,
		},
	],

	instanceEntrypoint: "./dist/node/instance.js",
	instanceConfigFields: {
		"exp_groups.sync_mode": {
			description: "Synchronize permission groups with the controller",
			type: "string",
			enum: ["disabled", "enabled", "bidirectional"],
			initialValue: "bidirectional",
		},
	},

	controllerEntrypoint: "./dist/node/controller.js",
	controllerConfigFields: {
	},

	webEntrypoint: "./web",
	routes: [
		"/permission_groups",
		"/permission_groups/:id/view",
	]
};
