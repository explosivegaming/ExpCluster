import * as lib from "@clusterio/lib";
import * as path from "node:path";
import type { ControllerPluginContext } from "@clusterio/controller";
import { RoleMetaRecord } from "@expcluster/roles";
import { GroupRecord, GroupPermissions, RoleMappingRecord } from "@expcluster/permission-groups";
import { ControllerPlugin as RolesPlugin } from "@expcluster/roles/dist/node/controller.js";
import { ControllerPlugin as GroupsPlugin } from "@expcluster/permission-groups/dist/node/controller.js";
import * as messages from "./messages.js";
import { features, pruneFeatureValues, validateFeatureValues } from "./features.js";
import { SeedRole, SeedGroup, seedRoles, seedGroups, flattenSeedPermissions } from "./seed.js";

export default async function (context: ControllerPluginContext) {
	const { controller, logger, plugin } = context;
	const databaseDirectory = controller.config.get("controller.database_directory");
	const featureStore = new lib.SubscribableDatastore(
		...await new lib.JsonIdDatastoreProvider(
			path.join(databaseDirectory, "exp_scenario", "features.json"),
			messages.FeatureRecord.fromJSON.bind(messages.FeatureRecord),
		).bootstrap()
	);

	/** Add new features, delete removed ones, and drop stored values which no longer fit a field */
	function reconcileFeatures() {
		const declared = new Map(features.map(feature => [feature.name, feature]));
		for (const record of featureStore.values()) {
			const feature = declared.get(record.id);
			if (!feature) {
				logger.warn(`Dropping stored config of removed feature ${record.id}`);
				featureStore.delete(record);
				continue;
			}

			const { kept, dropped } = pruneFeatureValues(feature, record.values);
			if (dropped.length) {
				logger.warn(`Dropping stored values of ${record.id} which no longer match a setting: ${dropped.join(", ")}`);
				featureStore.set(new messages.FeatureRecord(record.id, record.enabled, kept));
			}
		}

		const missing = features.filter(feature => !featureStore.has(feature.name));
		if (missing.length) {
			featureStore.setMany(missing.map(feature => new messages.FeatureRecord(feature.name, true)));
		}
	}

	/** Find or create the clusterio role for a seed role, returns undefined if it has no role to use. */
	function ensureRole(seedRole: SeedRole) {
		const roles = controller.roles;
		if (seedRole.isAdmin) {
			return roles.get(lib.Role.DefaultAdminRoleId);
		}
		if (seedRole.isDefault) {
			const defaultRoleId = controller.config.get("controller.default_role_id");
			return defaultRoleId !== null ? roles.get(defaultRoleId) : undefined;
		}

		const permissions = flattenSeedPermissions(seedRole);
		for (const permission of permissions) {
			if (!lib.permissions.has(permission)) {
				logger.warn(`Seed role ${seedRole.name} grants unknown permission ${permission}`);
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
			logger.info(`Created role ${seedRole.name}`);
		}
		roles.set(role);
		return role;
	}

	/** Find or create the permission group for a seed group. */
	function ensureGroup(groupsPlugin: GroupsPlugin, seedGroup: SeedGroup) {
		const permissions = new GroupPermissions(seedGroup.isBlacklist, [...seedGroup.inputActions]);
		const existing = [...groupsPlugin.groups.values()].find(other => other.name === seedGroup.name);
		const group = new GroupRecord(existing?.id ?? newId(groupsPlugin.groups), seedGroup.name, permissions);
		if (!existing) {
			logger.info(`Created permission group ${seedGroup.name}`);
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
	function seedRoleMappings(groupsPlugin: GroupsPlugin, roleIds: Map<string, number>, groupIds: Map<string, number>) {
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
	}

	reconcileFeatures();

	controller.subscriptions.handle(messages.FeatureUpdatedEvent, async request => {
		const updates = [...featureStore.values()].filter(feature => feature.updatedAtMs > request.lastRequestTimeMs);
		return updates.length ? new messages.FeatureUpdatedEvent(updates) : null;
	});
	featureStore.on("update", updates => {
		controller.subscriptions.broadcast(new messages.FeatureUpdatedEvent(updates));
	});

	/**
	 * Create the roles and permission groups the scenario shipped with.
	 *
	 * Roles which already exist by name are reused and only gain the seed
	 * permissions, groups which already exist by name are reset to the seed.
	 */
	controller.handle(messages.SeedRequest, async () => {
		const rolesPlugin = RolesPlugin.get(controller);
		const groupsPlugin = GroupsPlugin.get(controller);
		if (!rolesPlugin || !groupsPlugin) {
			throw new lib.RequestError("Seeding requires the exp_roles and exp_groups plugins");
		}

		const roleIds = new Map<string, number>();
		for (const [index, seed] of seedRoles.entries()) {
			const role = ensureRole(seed);
			if (!role) {
				continue;
			}

			roleIds.set(seed.name, role.id);
			rolesPlugin.roleMeta.set(new RoleMetaRecord(
				role.id,
				index + 1,
				seed.priority ?? 0,
				seed.shortHand,
				"",
				seed.color,
				seed.autoAssignHours === undefined ? null : seed.autoAssignHours * 3600000,
				seed.blockAutoAssign ?? false,
			));
		}

		const groupIds = new Map<string, number>();
		for (const seed of seedGroups) {
			groupIds.set(seed.name, ensureGroup(groupsPlugin, seed).id);
		}

		seedRoleMappings(groupsPlugin, roleIds, groupIds);
		logger.info(`Seeded ${roleIds.size} roles and ${groupIds.size} permission groups`);
	});

	controller.handle(messages.FeatureListRequest, async () => [...featureStore.values()]);

	controller.handle(messages.FeatureUpdateRequest, async (request: messages.FeatureUpdateRequest) => {
		let values;
		try {
			values = validateFeatureValues(request.id, request.values);
		} catch (err: any) {
			throw new lib.RequestError(err.message);
		}

		const feature = new messages.FeatureRecord(request.id, request.enabled, values);
		featureStore.set(feature);
		return feature;
	});

	controller.hooks.shutdown.attach(plugin.name, async () => {
		await featureStore.save();
	});
}

function newId(datastore: { has(id: number): boolean }) {
	let id = Math.random() * 2 ** 31 | 0;
	while (datastore.has(id)) {
		id = Math.random() * 2 ** 31 | 0;
	}
	return id;
}
