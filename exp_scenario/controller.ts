import * as lib from "@clusterio/lib";
import * as path from "node:path";
import type { Controller, ControllerPluginContext } from "@clusterio/controller";
import { RoleMetaRecord } from "@expcluster/roles";
import { GroupRecord, GroupPermissions, RoleMappingRecord } from "@expcluster/permission-groups";
import { ControllerPlugin as RolesPlugin } from "@expcluster/roles/dist/node/controller.js";
import { ControllerPlugin as GroupsPlugin } from "@expcluster/permission-groups/dist/node/controller.js";
import * as messages from "./messages.js";
import { features, pruneFeatureValues, validateFeatureValues } from "./features.js";
import { SeedRole, SeedGroup, seedRoles, seedGroups, flattenSeedPermissions } from "./seed.js";

export class ControllerPlugin {
	controller: Controller;
	logger: lib.Logger;
	name: string;
	features!: lib.SubscribableDatastore<messages.FeatureRecord>;

	constructor(context: ControllerPluginContext) {
		this.controller = context.controller;
		this.logger = context.logger;
		this.name = context.plugin.name;
	}

	async init() {
		const databaseDirectory = this.controller.config.get("controller.database_directory");
		this.features = new lib.SubscribableDatastore(
			...await new lib.JsonIdDatastoreProvider(
				path.join(databaseDirectory, "exp_scenario", "features.json"),
				messages.FeatureRecord.fromJSON.bind(messages.FeatureRecord),
			).bootstrap()
		);

		this.reconcileFeatures();

		this.controller.subscriptions.handle(messages.FeatureUpdatedEvent, this.handleFeatureSubscription.bind(this));
		this.features.on("update", this.featuresUpdated.bind(this));

		this.controller.handle(messages.SeedRequest, this.handleSeedRequest.bind(this));
		this.controller.handle(messages.FeatureListRequest, this.handleFeatureListRequest.bind(this));
		this.controller.handle(messages.FeatureUpdateRequest, this.handleFeatureUpdateRequest.bind(this));

		this.controller.hooks.shutdown.attach(this.name, this.onShutdown.bind(this));
	}

	async onShutdown() {
		await this.features.save();
	}

	/**
	 * Bring the stored records in line with the features declared in features.ts.
	 *
	 * New features begin with their defaults, records of removed features are
	 * deleted, and values which no longer match a field are dropped so the
	 * feature can still be saved from the web interface.
	 */
	reconcileFeatures() {
		const declared = new Map(features.map(feature => [feature.name, feature]));
		for (const record of [...this.features.values()]) {
			const feature = declared.get(record.id);
			if (!feature) {
				this.logger.warn(`Dropping stored config of removed feature ${record.id}`);
				this.features.delete(record);
				continue;
			}

			const { kept, dropped } = pruneFeatureValues(feature, record.values);
			if (dropped.length) {
				this.logger.warn(`Dropping stored values of ${record.id} which no longer match a setting: ${dropped.join(", ")}`);
				this.features.set(new messages.FeatureRecord(record.id, record.enabled, kept));
			}
		}

		const missing = features.filter(feature => !this.features.has(feature.name));
		if (missing.length) {
			this.features.setMany(missing.map(feature => new messages.FeatureRecord(feature.name, true)));
		}
	}

	featuresUpdated(updates: messages.FeatureRecord[]) {
		this.controller.subscriptions.broadcast(new messages.FeatureUpdatedEvent(updates));
	}

	async handleFeatureSubscription(request: lib.SubscriptionRequest) {
		const updates = [...this.features.values()].filter(feature => feature.updatedAtMs > request.lastRequestTimeMs);
		return updates.length ? new messages.FeatureUpdatedEvent(updates) : null;
	}

	async handleFeatureListRequest() {
		return [...this.features.values()];
	}

	async handleFeatureUpdateRequest(request: messages.FeatureUpdateRequest) {
		let values;
		try {
			values = validateFeatureValues(request.id, request.values);
		} catch (err: any) {
			throw new lib.RequestError(err.message);
		}

		const feature = new messages.FeatureRecord(request.id, request.enabled, values);
		this.features.set(feature);
		return feature;
	}

	/**
	 * Create the roles and permission groups the scenario shipped with.
	 *
	 * Roles which already exist by name are reused and only gain the seed
	 * permissions, groups which already exist by name are reset to the seed.
	 */
	async handleSeedRequest() {
		const rolesPlugin = RolesPlugin.get(this.controller);
		const groupsPlugin = GroupsPlugin.get(this.controller);
		if (!rolesPlugin || !groupsPlugin) {
			throw new lib.RequestError("Seeding requires the exp_roles and exp_groups plugins");
		}

		const roleIds = new Map<string, number>();
		for (const [index, seedRole] of seedRoles.entries()) {
			const role = this.seedRole(seedRole);
			if (!role) {
				continue;
			}

			roleIds.set(seedRole.name, role.id);
			rolesPlugin.roleMeta.set(new RoleMetaRecord(
				role.id,
				index + 1,
				seedRole.priority ?? 0,
				seedRole.shortHand,
				"",
				seedRole.color,
				seedRole.autoAssignHours === undefined ? null : seedRole.autoAssignHours * 3600000,
				seedRole.blockAutoAssign ?? false,
			));
		}

		const groupIds = new Map<string, number>();
		for (const seedGroup of seedGroups) {
			groupIds.set(seedGroup.name, this.seedGroup(groupsPlugin, seedGroup).id);
		}

		this.seedRoleMappings(groupsPlugin, roleIds, groupIds);
		this.logger.info(`Seeded ${roleIds.size} roles and ${groupIds.size} permission groups`);
	}

	/** Find or create the clusterio role for a seed role, returns undefined if it has no role to use. */
	seedRole(seedRole: SeedRole) {
		const roles = this.controller.roles;
		if (seedRole.isAdmin) {
			return roles.get(lib.Role.DefaultAdminRoleId);
		}
		if (seedRole.isDefault) {
			const defaultRoleId = this.controller.config.get("controller.default_role_id");
			return defaultRoleId !== null ? roles.get(defaultRoleId) : undefined;
		}

		const permissions = flattenSeedPermissions(seedRole);
		for (const permission of permissions) {
			if (!lib.permissions.has(permission)) {
				this.logger.warn(`Seed role ${seedRole.name} grants unknown permission ${permission}`);
			}
		}

		let role = [...roles.valuesMutable()].find(other => other.name === seedRole.name);
		if (role) {
			for (const permission of permissions) {
				role.permissions.add(permission);
			}
		} else {
			const id = Math.max(5, ...[...roles.keys()].map(other => other + 1));
			role = new lib.Role(id, seedRole.name, "", permissions);
			this.logger.info(`Created role ${seedRole.name}`);
		}
		roles.set(role);
		return role;
	}

	/** Find or create the permission group for a seed group. */
	seedGroup(groupsPlugin: GroupsPlugin, seedGroup: SeedGroup) {
		const permissions = new GroupPermissions(seedGroup.isBlacklist, [...seedGroup.inputActions]);
		const existing = [...groupsPlugin.groups.values()].find(other => other.name === seedGroup.name);
		const group = new GroupRecord(existing?.id ?? newId(groupsPlugin.groups), seedGroup.name, permissions);
		if (!existing) {
			this.logger.info(`Created permission group ${seedGroup.name}`);
		}
		groupsPlugin.groups.set(group);
		return group;
	}

	/**
	 * Map each seed role onto its seed group.
	 *
	 * The mapping with the highest priority decides a player's group, so the
	 * priorities follow how exp_roles picks a player's highest role: role
	 * priority first, then the role order.
	 */
	seedRoleMappings(groupsPlugin: GroupsPlugin, roleIds: Map<string, number>, groupIds: Map<string, number>) {
		// Lowest role first, so the mapping priority rises with the role
		const ranked = seedRoles
			.filter(seedRole => seedRole.group !== undefined && roleIds.has(seedRole.name))
			.reverse()
			.sort((a, b) => (a.priority ?? 0) - (b.priority ?? 0));
		const seededRoleIds = new Set(ranked.map(seedRole => roleIds.get(seedRole.name)!));

		// A mapping of a single seed role is reused, every other mapping keeps its priority
		const existing = new Map<number, RoleMappingRecord>();
		const taken = new Set<number>();
		for (const mapping of groupsPlugin.roleMappings.values()) {
			const [roleId] = mapping.roleIds;
			if (mapping.roleIds.size === 1 && seededRoleIds.has(roleId)) {
				existing.set(roleId, mapping);
			} else {
				taken.add(mapping.priority);
			}
		}

		const mappings = [];
		let priority = 0;
		for (const seedRole of ranked) {
			priority += 1;
			while (taken.has(priority)) {
				priority += 1;
			}

			const roleId = roleIds.get(seedRole.name)!;
			mappings.push(new RoleMappingRecord(
				existing.get(roleId)?.id ?? newId(groupsPlugin.roleMappings),
				new Set([roleId]),
				groupIds.get(seedRole.group!)!,
				priority,
				true,
			));
		}

		groupsPlugin.roleMappings.setMany(mappings);
		return mappings;
	}
}

export default async function (context: ControllerPluginContext) {
	await new ControllerPlugin(context).init();
}

function newId(datastore: { has(id: number): boolean }) {
	let id = Math.random() * 2 ** 31 | 0;
	while (datastore.has(id)) {
		id = Math.random() * 2 ** 31 | 0;
	}
	return id;
}
