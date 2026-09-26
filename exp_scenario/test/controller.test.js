import t from "tap";
import * as lib from "@clusterio/lib";
import { Controller } from "@clusterio/controller";
import { ControllerPlugin } from "../dist/node/controller.js";
import * as messages from "../dist/node/messages.js";
import { seedRoles, seedGroups } from "../dist/node/seed.js";
import * as roles from "@expcluster/roles";
import * as groups from "@expcluster/permission-groups";
import { ControllerPlugin as RolesPlugin } from "@expcluster/roles/dist/node/controller.js";
import { ControllerPlugin as GroupsPlugin } from "@expcluster/permission-groups/dist/node/controller.js";
import { GroupRecord, GroupPermissions, RoleMappingRecord } from "@expcluster/permission-groups";

import { plugin } from "../dist/node/index.js";

// Registering the plugin defines the permissions the seed grants
lib.registerPluginPermissions([plugin]);

// The controller validates message classes against the link registry
for (const Message of [messages.SeedRequest, ...roles.plugin.messages, ...groups.plugin.messages]) {
	lib.Link.register(Message);
}

const logger = { child: () => logger, info: () => {}, warn: () => {}, error: () => {}, verbose: () => {} };

// Silence the singleton logger to avoid polluting the test output
lib.logger.silent = true;
t.after(() => {
	lib.logger.silent = false;
});

/** Build the plugin around a real controller, which is side effect free while not started. */
async function startPlugin(t2, { withPlugins = true } = {}) {
	const controllerConfig = new lib.ControllerConfig("controller", {
		"controller.database_directory": t2.testdir(),
		"controller.default_role_id": lib.Role.DefaultPlayerRoleId,
	});
	const controller = new Controller(logger, [], controllerConfig);
	controller.roles.set(new lib.Role(0, "Cluster Admin", "", new Set(["core.admin"])));
	controller.roles.set(new lib.Role(1, "Player", "", new Set()));

	if (withPlugins) {
		for (const [name, Plugin] of [["exp_roles", RolesPlugin], ["exp_groups", GroupsPlugin]]) {
			const plugin = new Plugin({ name }, controller, undefined, logger);
			await plugin.init();
			controller.plugins.set(name, plugin);
		}
	}

	const plugin = new ControllerPlugin({ name: "exp_scenario" }, controller, undefined, logger);
	await plugin.init();
	return { plugin, controller };
}

const byName = (datastore, name) => [...datastore.values()].find(other => other.name === name);

t.test("class ControllerPlugin", t2 => {
	t2.test(".handleSeedRequest() throws when the seeded plugins are missing", async t3 => {
		const { plugin } = await startPlugin(t3, { withPlugins: false });
		await t3.rejects(
			plugin.handleSeedRequest(),
			{ message: "Seeding requires the exp_roles and exp_groups plugins" },
			"the request is rejected",
		);
	});

	t2.test(".handleSeedRequest() creates the roles and reuses them by name", async t3 => {
		const { plugin, controller } = await startPlugin(t3);
		const rolesPlugin = controller.plugins.get("exp_roles");

		await plugin.handleSeedRequest();
		t3.strictSame(controller.roles.size, seedRoles.length, "every seed role exists");

		const moderator = byName(controller.roles, "Moderator");
		t3.ok(moderator.permissions.has("exp_scenario.command.jail"), "parent permissions are flattened in");
		t3.strictSame(rolesPlugin.roleMeta.get(moderator.id).shortHand, "Mod", "the role properties match the seed");

		await plugin.handleSeedRequest();
		t3.strictSame(controller.roles.size, seedRoles.length, "seeding again reuses the roles");
	});

	t2.test(".handleSeedRequest() creates the groups and resets them by name", async t3 => {
		const { plugin, controller } = await startPlugin(t3);
		const groupsPlugin = controller.plugins.get("exp_groups");

		await plugin.handleSeedRequest();
		t3.strictSame(groupsPlugin.groups.size, seedGroups.length, "every seed group exists");

		const restricted = byName(groupsPlugin.groups, "Restricted");
		t3.strictSame(restricted.permissions.isBlacklist, false, "the group only allows the listed actions");
		t3.strictSame(restricted.permissions.permissions, ["write_to_console"], "the actions match the seed");

		const admin = byName(groupsPlugin.groups, "Admin");
		groupsPlugin.groups.set(new GroupRecord(admin.id, admin.name, new GroupPermissions(true, [])));
		await plugin.handleSeedRequest();
		t3.strictSame(groupsPlugin.groups.size, seedGroups.length, "seeding again reuses the groups");
		t3.ok(
			byName(groupsPlugin.groups, "Admin").permissions.permissions.includes("toggle_map_editor"),
			"seeding again resets the actions",
		);
	});

	t2.test(".handleSeedRequest() maps each role onto its group by rank", async t3 => {
		const { plugin, controller } = await startPlugin(t3);
		const groupsPlugin = controller.plugins.get("exp_groups");

		await plugin.handleSeedRequest();
		const mapped = seedRoles.filter(role => role.group !== undefined);
		t3.strictSame(groupsPlugin.roleMappings.size, mapped.length, "every role with a group is mapped");

		const mappingOf = name => [...groupsPlugin.roleMappings.values()]
			.find(mapping => mapping.roleIds.has(byName(controller.roles, name).id));
		const groupOf = name => groupsPlugin.groups.get(mappingOf(name).groupId).name;
		t3.strictSame(groupOf("Player"), "Guest", "the default role maps to the guest group");
		t3.strictSame(groupOf("Jail"), "Restricted", "jail maps to the restricted group");
		t3.ok(mappingOf("Jail").priority > mappingOf("Senior Administrator").priority, "jail outranks every role");
		t3.ok(mappingOf("Moderator").priority > mappingOf("Veteran").priority, "the role order sets the rank");
		t3.ok(mappingOf("Veteran").priority > mappingOf("Player").priority, "the default role ranks lowest");
		t3.strictSame(mappingOf("Cluster Admin"), undefined, "the admin role keeps the factorio default group");

		const priorities = [...groupsPlugin.roleMappings.values()].map(mapping => mapping.priority);
		t3.strictSame(priorities.length, new Set(priorities).size, "priorities are unique");
	});

	t2.test(".handleSeedRequest() reuses mappings and keeps clear of other mappings", async t3 => {
		const { plugin, controller } = await startPlugin(t3);
		const groupsPlugin = controller.plugins.get("exp_groups");

		groupsPlugin.roleMappings.set(new RoleMappingRecord(99, new Set([0, 1]), 5, 2, true));
		await plugin.handleSeedRequest();
		const first = new Map([...groupsPlugin.roleMappings.values()].map(mapping => [mapping.id, mapping.priority]));

		await plugin.handleSeedRequest();
		const second = new Map([...groupsPlugin.roleMappings.values()].map(mapping => [mapping.id, mapping.priority]));
		t3.strictSame(second, first, "seeding again reuses the mappings");
		t3.strictSame(groupsPlugin.roleMappings.get(99).priority, 2, "other mappings are left alone");
		t3.notOk([...first.values()].filter(priority => priority === 2).length > 1, "seed priorities skip taken ones");
	});

	t2.end();
});
