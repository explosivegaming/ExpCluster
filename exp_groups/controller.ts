import * as lib from "@clusterio/lib";
import { BaseControllerPlugin, InstanceInfo } from "@clusterio/controller";

import {
	PermissionStrings, PermissionStringsUpdate,
	PermissionGroup, PermissionGroupUpdate,
	InstancePermissionGroups,
	PermissionInstanceId,
	PermissionGroupEditEvent,
} from "./messages";

import path from "path";
import fs from "fs-extra";

export class ControllerPlugin extends BaseControllerPlugin {
	static permissionGroupsPath = "exp_groups.json";
	static userGroupsPath = "exp_user_groups.json";

	userToGroup: Map<lib.User["id"], PermissionGroup> = new Map(); // TODO this needs to be per instance
	permissionStrings!: Map<PermissionStrings["id"], PermissionStrings>;
	permissionGroups!: Map<InstancePermissionGroups["id"], InstancePermissionGroups>;

	async init() {
		this.controller.handle(PermissionStringsUpdate, this.handlePermissionStringsUpdate.bind(this));
		this.controller.handle(PermissionGroupUpdate, this.handlePermissionGroupUpdate.bind(this));
		this.controller.handle(PermissionGroupEditEvent, this.handlePermissionGroupEditEvent.bind(this));
		this.controller.subscriptions.handle(PermissionStringsUpdate, this.handlePermissionStringsSubscription.bind(this));
		this.controller.subscriptions.handle(PermissionGroupUpdate, this.handlePermissionGroupSubscription.bind(this));
		this.controller.subscriptions.handle(PermissionGroupEditEvent);
		this.permissionStrings = new Map([["Global", new PermissionStrings("Global", new Set())]]);
		this.permissionGroups = new Map([["Global", new InstancePermissionGroups("Global")]]);
		await this.loadData();

		// Add the default group if missing and add any missing cluster roles
		const clusterRoles = [...this.controller.userManager.roles.values()]
		for (const instanceGroups of this.permissionGroups.values()) {
			const groups = instanceGroups.groups;
			const instanceRoles = [...groups.values()].flatMap(group => [...group.roleIds.values()]);
			const missingRoles = clusterRoles.filter(role => instanceRoles.includes(role.id));
			const defaultGroup = groups.get("Default");
			if (defaultGroup) {
				for (const role of missingRoles) {
					defaultGroup.roleIds.add(role.id)
				}
			} else {
				groups.set("Default", new PermissionGroup(
					instanceGroups.instanceId, 
					"Default",
					groups.size,
					new Set(missingRoles.map(role => role.id))
				));
			}
		}
	}

	async onControllerConfigFieldChanged(field: string, curr: unknown, prev: unknown) {
		if (field === "exp_groups.allow_role_inconsistency") {
			// Do something with this.userToGroup
		}
	}

	async onInstanceConfigFieldChanged(instance: InstanceInfo, field: string, curr: unknown, prev: unknown) {
		this.logger.info(`controller::onInstanceConfigFieldChanged ${instance.id} ${field}`);
		if (field === "exp_groups.sync_permission_groups") {
			const updates = []
			const now = Date.now();
			if (curr) {
				// Global sync enabled, we dont need the instance config
				const instanceGroups = this.permissionGroups.get(instance.id);
				if (instanceGroups) {
					this.permissionGroups.delete(instance.id);
					for (const group of instanceGroups.groups.values()) {
						group.updatedAtMs = now;
						group.isDeleted = true;
						updates.push(group);
					}
				}
			} else {
				// Global sync disabled, make a copy of the global config as a base
				const global = this.permissionGroups.get("Global")!;
				const oldInstanceGroups = this.permissionGroups.get(instance.id);
				const instanceGroups = new InstancePermissionGroups(
					instance.id, new Map([...global.groups.values()].map(group => [group.name, group.copy(instance.id)]))
				)
				this.permissionGroups.set(instance.id, instanceGroups);
				for (const group of instanceGroups.groups.values()) {
					group.updatedAtMs = now; 
					updates.push(group);
				}
				// If it has an old config (unexpected) then deal with it
				if (oldInstanceGroups) {
					for (const group of oldInstanceGroups.groups.values()) {
						if (!instanceGroups.groups.has(group.name)) {
							group.updatedAtMs = now; 
							group.isDeleted = true;
							updates.push(group);
						}
					}
				}
			}
			// Send the updates to all instances and controls
			if (updates.length) {
				this.controller.subscriptions.broadcast(new PermissionGroupUpdate(updates));
			}
		}
	}

	async loadPermissionGroups() {
		const file = path.resolve(this.controller.config.get("controller.database_directory"), ControllerPlugin.permissionGroupsPath);
		this.logger.verbose(`Loading ${file}`);
		try {
			const content = await fs.readFile(file, { encoding: "utf8" });
			for (const groupRaw of JSON.parse(content)) {
				const group = PermissionGroup.fromJSON(groupRaw);
				const instanceGroups = this.permissionGroups.get(group.instanceId);
				if (instanceGroups) {
					instanceGroups.groups.set(group.name, group);
				} else {
					this.permissionGroups.set(group.instanceId,
						new InstancePermissionGroups(group.instanceId, new Map([[group.name, group]]))
					);
				}
			};

		} catch (err: any) {
			if (err.code === "ENOENT") {
				this.logger.verbose("Creating new permission group database");
				return;
			}
			throw err;
		}
	}

	async savePermissionGroups() {
		const file = path.resolve(this.controller.config.get("controller.database_directory"), ControllerPlugin.permissionGroupsPath);
		this.logger.verbose(`Writing ${file}`);
		await lib.safeOutputFile(file, JSON.stringify(
			[...this.permissionGroups.values()].flatMap(instanceGroups => [...instanceGroups.groups.values()])
		));
	}

	async loadUserGroups() {
		if (!this.controller.config.get("exp_groups.allow_role_inconsistency")) return;
		const file = path.resolve(this.controller.config.get("controller.database_directory"), ControllerPlugin.userGroupsPath);
		this.logger.verbose(`Loading ${file}`);
		try {
			const content = await fs.readFile(file, { encoding: "utf8" });
			this.userToGroup = new Map(JSON.parse(content));

		} catch (err: any) {
			if (err.code === "ENOENT") {
				this.logger.verbose("Creating new user group database");
				return;
			}
			throw err;
		}
	}

	async saveUserGroups() {
		if (!this.controller.config.get("exp_groups.allow_role_inconsistency")) return;
		const file = path.resolve(this.controller.config.get("controller.database_directory"), ControllerPlugin.userGroupsPath);
		this.logger.verbose(`Writing ${file}`);
		await lib.safeOutputFile(file, JSON.stringify([...this.permissionGroups.entries()]));
	}

	async loadData() {
		await Promise.all([
			this.loadPermissionGroups(),
			this.loadUserGroups(),
		])
	}

	async onSaveData() {
		await Promise.all([
			this.savePermissionGroups(),
			this.saveUserGroups(),
		])
	}

	addPermisisonGroup(instanceId: PermissionInstanceId, name: string, permissions = new Set<string>(), silent = false) {
		const instanceGroups = this.permissionGroups.get(instanceId);
		if (!instanceGroups) {
			throw new Error("Instance ID does not exist");
		} 
		if (instanceGroups.groups.has(name)) {
			return instanceGroups.groups.get(name)!;
		}
		for (const group of instanceGroups.groups.values()) {
			group.order += 1;
		}
		const group = new PermissionGroup(instanceId, name, 0, new Set(), permissions, Date.now(), false);
		instanceGroups.groups.set(group.id, group);
		if (!silent) {
			this.controller.subscriptions.broadcast(new PermissionGroupUpdate([group]));
		}
		return group;
	}

	removePermissionGroup(instanceId: PermissionInstanceId, name: string, silent = false) {
		const instanceGroups = this.permissionGroups.get(instanceId);
		if (!instanceGroups) {
			throw new Error("Instance ID does not exist");
		}
		const group = instanceGroups.groups.get(name)
		if (!group) {
			return null;
		}
		for (const nextGroup of instanceGroups.groups.values()) {
			if (nextGroup.order > group.order) {
				nextGroup.order -= 1;
			}
		}
		instanceGroups.groups.delete(group.id);
		group.updatedAtMs = Date.now();
		group.isDeleted = true;
		if (!silent) {
			this.controller.subscriptions.broadcast(new PermissionGroupUpdate([group]));
		}
		return group;
	}

	async handlePermissionGroupEditEvent(event: PermissionGroupEditEvent) {
		// TODO
	}

	async handlePermissionStringsUpdate(event: PermissionStringsUpdate) {
		for (const update of event.updates) {
			const global = this.permissionStrings.get("Global")!
			this.permissionStrings.set(update.instanceId as number, update)
			global.updatedAtMs = Math.max(global.updatedAtMs, update.updatedAtMs)
			for (const permission of update.permissions) {
				global.permissions.add(permission)
			}
			// TODO maybe check if changes have happened rather than always pushing updates
			this.controller.subscriptions.broadcast(new PermissionStringsUpdate([global, update]))
		}
	}

	async handlePermissionGroupUpdate(event: PermissionGroupUpdate) {
		const updates = [];
		for (const group of event.updates) {
			const groups = this.permissionGroups.get(group.instanceId);
			if (!groups) continue;
			const existingGroup = groups.groups.get(group.id);
			let update
			if (!existingGroup) {
				update = this.addPermisisonGroup(group.instanceId, group.name, group.permissions, true);
			} else if (group.isDeleted) {
				update = this.removePermissionGroup(group.instanceId, group.name, true);
			} else {
				existingGroup.permissions = group.permissions;
				existingGroup.updatedAtMs = Date.now();
				update = existingGroup;
			}
			if (update) updates.push(update);
		}
		this.controller.subscriptions.broadcast(new PermissionGroupUpdate(updates));
	}

	async handlePermissionStringsSubscription(request: lib.SubscriptionRequest, src: lib.Address) {
		const updates = [ ...this.permissionStrings.values() ]
			.filter(
				value => value.updatedAtMs > request.lastRequestTimeMs,
			)
		return updates.length ? new PermissionStringsUpdate(updates) : null;
	}

	async handlePermissionGroupSubscription(request: lib.SubscriptionRequest, src: lib.Address) {
		const updates = [ ...this.permissionGroups.values() ]
			.flatMap(instanceGroups => [...instanceGroups.groups.values()])
			.filter(
				value => value.updatedAtMs > request.lastRequestTimeMs,
			)
		if (src.type === lib.Address.instance) {
			const instanceUpdates = updates.filter(group => group.instanceId === src.id || group.instanceId === "Global");
			this.logger.info(JSON.stringify(updates))
			this.logger.info(JSON.stringify(instanceUpdates))
			return instanceUpdates.length ? new PermissionGroupUpdate(instanceUpdates) : null;
		}
		return updates.length ? new PermissionGroupUpdate(updates) : null;
	}
}
