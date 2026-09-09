import * as lib from "@clusterio/lib";
import { BaseControllerPlugin } from "@clusterio/controller";
import { RoleMetaRecord, type ControllerPlugin as RolesPlugin } from "@expcluster/roles";
import {
	GroupRecord, GroupPermissions, RoleMappingRecord, type ControllerPlugin as GroupsPlugin,
} from "@expcluster/permission-groups";
import * as messages from "./messages";
import { SeedRole, SeedGroup, seedRoles, seedGroups, flattenSeedPermissions } from "./seed";

export class ControllerPlugin extends BaseControllerPlugin {
	async init() {
		this.controller.handle(messages.SeedRequest, this.handleSeedRequest.bind(this));
	}

	/**
	 * Create the roles and permission groups the scenario shipped with.
	 *
	 * Roles which already exist by name are reused and only gain the seed
	 * permissions, groups which already exist by name are reset to the seed.
	 */
	async handleSeedRequest() {
		const rolesPlugin = this.controller.plugins.get("exp_roles") as RolesPlugin | undefined;
		const groupsPlugin = this.controller.plugins.get("exp_groups") as GroupsPlugin | undefined;
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

function newId(datastore: { has(id: number): boolean }) {
	let id = Math.random() * 2 ** 31 | 0;
	while (datastore.has(id)) {
		id = Math.random() * 2 ** 31 | 0;
	}
	return id;
}
