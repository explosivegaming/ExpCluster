import * as lib from "@clusterio/lib";
import * as Messages from "./messages";

lib.definePermission({
	name: "exp_groups.create_delete_groups",
	title: "Create and delete permission groups",
	description: "Create and delete permission groups.",
});

lib.definePermission({
	name: "exp_groups.reorder_groups",
	title: "Reorder permission groups",
	description: "Reorder groups and link them to user roles.",
});

lib.definePermission({
	name: "exp_groups.modify_permissions",
	title: "Modify permission groups",
	description: "Modify game permissions for groups.",
});

lib.definePermission({
	name: "exp_groups.assign_players",
	title: "Change player group",
	description: "Change the permission group of a player",
});

lib.definePermission({
	name: "exp_groups.list",
	title: "View permission groups",
	description: "View permission groups.",
});

lib.definePermission({
	name: "exp_groups.list.subscribe",
	title: "Subscribe to permission group updates",
	description: "Subscribe to permission group updates.",
});

declare module "@clusterio/lib" {
	export interface ControllerConfigFields {
		"exp_groups.allow_role_inconsistency": boolean;
	}
	export interface InstanceConfigFields {
		"exp_groups.sync_permission_groups": boolean;
	}
}

export const plugin: lib.PluginDeclaration = {
	name: "exp_groups",
	title: "exp_groups",
	description: "Create, modify, and link factorio permission groups to clusterio user roles.",

	controllerEntrypoint: "./dist/node/controller",
	controllerConfigFields: {
		"exp_groups.allow_role_inconsistency": {
			title: "Allow User Role Inconsistency",
			description: "When true, users can be assgined to any group regardless of their roles",
			type: "boolean",
			initialValue: false,
		},
	},

	instanceEntrypoint: "./dist/node/instance",
	instanceConfigFields: {
		"exp_groups.sync_permission_groups": {
			title: "Sync Permission Groups",
			description: "When true, the instance cannot deviate from the global group settings and will be hidden from the sellection dropdown.",
			type: "boolean",
			initialValue: true,
		},
	},

	messages: [
		Messages.PermissionGroupEditEvent,
		Messages.PermissionStringsUpdate,
		Messages.PermissionGroupUpdate,
	],

	webEntrypoint: "./web",
	routes: [
		"/exp_groups",
	],
};
