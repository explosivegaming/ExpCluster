import t from "tap";
import path from "node:path";
import * as lib from "@clusterio/lib";
import { Controller } from "@clusterio/controller";
import entrypoint from "../dist/node/controller.js";
import * as messages from "../dist/node/messages.js";
import { seedRoles, seedGroups } from "../dist/node/seed.js";
import { features } from "../dist/node/features.js";
import * as roles from "@expcluster/roles";
import * as groups from "@expcluster/permission-groups";
import { ControllerPlugin as RolesPlugin } from "@expcluster/roles/dist/node/controller.js";
import { ControllerPlugin as GroupsPlugin } from "@expcluster/permission-groups/dist/node/controller.js";
import { GroupRecord, GroupPermissions, RoleMappingRecord } from "@expcluster/permission-groups";

import { plugin } from "../dist/node/index.js";

// Registering the plugin defines the permissions the seed grants
lib.registerPluginPermissions([plugin]);

// The controller validates message classes against the link registry
for (const Message of [...plugin.messages, ...roles.plugin.messages, ...groups.plugin.messages]) {
	lib.Link.register(Message);
}

const logger = { child: () => logger, info: () => {}, warn: () => {}, error: () => {}, verbose: () => {} };

// Silence the singleton logger to avoid polluting the test output
lib.logger.silent = true;
t.after(() => {
	lib.logger.silent = false;
});

/** Run the plugin on a real controller, which is side effect free while not started, returns the handlers it registered. */
async function startPlugin(t2, { withPlugins = true, databaseDirectory = t2.testdir() } = {}) {
	const controllerConfig = new lib.ControllerConfig("controller", {
		"controller.database_directory": databaseDirectory,
		"controller.default_role_id": lib.Role.DefaultPlayerRoleId,
	});
	const controller = new Controller(logger, [], controllerConfig);
	controller.roles.set(new lib.Role(0, "Cluster Admin", "", new Set(["core.admin"])));
	controller.roles.set(new lib.Role(1, "Player", "", new Set()));

	if (withPlugins) {
		for (const [name, Plugin] of [["exp_roles", RolesPlugin], ["exp_groups", GroupsPlugin]]) {
			await Plugin.fromContext({ plugin: { name }, controller, logger });
		}
	}

	const handlers = new Map();
	const handle = controller.handle.bind(controller);
	controller.handle = (Class, handler) => {
		handlers.set(Class, handler);
		handle(Class, handler);
	};
	const subscriptionHandle = controller.subscriptions.handle.bind(controller.subscriptions);
	controller.subscriptions.handle = (Class, handler) => {
		handlers.set(Class, handler);
		subscriptionHandle(Class, handler);
	};

	await entrypoint({ plugin: { name: "exp_scenario" }, controller, logger });
	return {
		controller,
		seed: () => handlers.get(messages.SeedRequest)(new messages.SeedRequest()),
		listFeatures: () => handlers.get(messages.FeatureListRequest)(new messages.FeatureListRequest()),
		updateFeature: request => handlers.get(messages.FeatureUpdateRequest)(request),
		featureSubscription: request => handlers.get(messages.FeatureUpdatedEvent)(request),
		shutdown: () => controller.hooks.shutdown.invoke(),
	};
}

/** Write the stored features as a previous run would have left them. */
async function storeFeatures(databaseDirectory, records) {
	await new lib.JsonIdDatastoreProvider(
		path.join(databaseDirectory, "exp_scenario", "features.json"),
		messages.FeatureRecord.fromJSON.bind(messages.FeatureRecord),
	).save(new Map(records.map(record => [record.id, record])));
}

/** The feature record with the given id. */
async function getFeature(listFeatures, id) {
	return (await listFeatures()).find(record => record.id === id);
}

const byName = (datastore, name) => [...datastore.values()].find(other => other.name === name);

t.test("controller plugin", t2 => {
	t2.test("SeedRequest throws when the seeded plugins are missing", async t3 => {
		const { seed } = await startPlugin(t3, { withPlugins: false });
		await t3.rejects(
			seed(),
			{ message: "Seeding requires the exp_roles and exp_groups plugins" },
			"the request is rejected",
		);
	});

	t2.test("SeedRequest creates the roles and reuses them by name", async t3 => {
		const { seed, controller } = await startPlugin(t3);
		const rolesPlugin = RolesPlugin.get(controller);

		await seed();
		t3.strictSame(controller.roles.size, seedRoles.length, "every seed role exists");

		const moderator = byName(controller.roles, "Moderator");
		t3.ok(moderator.permissions.has("exp_scenario.command.jail"), "parent permissions are flattened in");
		t3.strictSame(rolesPlugin.roleMeta.get(moderator.id).shortHand, "Mod", "the role properties match the seed");

		await seed();
		t3.strictSame(controller.roles.size, seedRoles.length, "seeding again reuses the roles");
	});

	t2.test("SeedRequest creates the groups and resets them by name", async t3 => {
		const { seed, controller } = await startPlugin(t3);
		const groupsPlugin = GroupsPlugin.get(controller);

		await seed();
		t3.strictSame(groupsPlugin.groups.size, seedGroups.length, "every seed group exists");

		const restricted = byName(groupsPlugin.groups, "Restricted");
		t3.strictSame(restricted.permissions.isBlacklist, false, "the group only allows the listed actions");
		t3.strictSame(restricted.permissions.permissions, ["write_to_console"], "the actions match the seed");

		const admin = byName(groupsPlugin.groups, "Admin");
		groupsPlugin.groups.set(new GroupRecord(admin.id, admin.name, new GroupPermissions(true, [])));
		await seed();
		t3.strictSame(groupsPlugin.groups.size, seedGroups.length, "seeding again reuses the groups");
		t3.ok(
			byName(groupsPlugin.groups, "Admin").permissions.permissions.includes("toggle_map_editor"),
			"seeding again resets the actions",
		);
	});

	t2.test("SeedRequest maps each role onto its group by rank", async t3 => {
		const { seed, controller } = await startPlugin(t3);
		const groupsPlugin = GroupsPlugin.get(controller);

		await seed();
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

	t2.test("SeedRequest reuses mappings and keeps clear of other mappings", async t3 => {
		const { seed, controller } = await startPlugin(t3);
		const groupsPlugin = GroupsPlugin.get(controller);

		groupsPlugin.roleMappings.set(new RoleMappingRecord(99, new Set([0, 1]), 5, 2, true));
		await seed();
		const first = new Map([...groupsPlugin.roleMappings.values()].map(mapping => [mapping.id, mapping.priority]));

		await seed();
		const second = new Map([...groupsPlugin.roleMappings.values()].map(mapping => [mapping.id, mapping.priority]));
		t3.strictSame(second, first, "seeding again reuses the mappings");
		t3.strictSame(groupsPlugin.roleMappings.get(99).priority, 2, "other mappings are left alone");
		t3.notOk([...first.values()].filter(priority => priority === 2).length > 1, "seed priorities skip taken ones");
	});

	t2.test("startup adds every feature with its defaults", async t3 => {
		const { listFeatures } = await startPlugin(t3, { withPlugins: false });
		const records = await listFeatures();
		t3.strictSame(records.map(record => record.id), features.map(feature => feature.name), "one record per feature");
		t3.ok(records.every(record => record.enabled && !Object.keys(record.values).length), "enabled with no overrides");
	});

	t2.test("startup drops stored values and features which no longer exist", async t3 => {
		const databaseDirectory = t3.testdir();
		await storeFeatures(databaseDirectory, [
			new messages.FeatureRecord("afk_kick", false, { afk_minutes: 5, trust_time: 600 }),
			new messages.FeatureRecord("gone", true, {}),
		]);

		const { listFeatures } = await startPlugin(t3, { withPlugins: false, databaseDirectory });
		const record = await getFeature(listFeatures, "afk_kick");
		t3.strictSame([record.enabled, record.values], [false, { afk_minutes: 5 }], "the stale value is dropped, the rest kept");
		const ids = new Set((await listFeatures()).map(other => other.id));
		t3.notOk(ids.has("gone"), "the removed feature is deleted");
		t3.ok(features.every(feature => ids.has(feature.name)), "every declared feature still has a record");
	});

	t2.test("FeatureUpdateRequest stores the values which differ from the default", async t3 => {
		const { controller, listFeatures, updateFeature, featureSubscription } = await startPlugin(t3, { withPlugins: false });
		const broadcasts = [];
		controller.subscriptions.broadcast = event => broadcasts.push(event);

		const record = await updateFeature(new messages.FeatureUpdateRequest(
			"death_markers", false, { show_map_markers: false, collect_corpses: true },
		));
		t3.strictSame(record.values, { show_map_markers: false }, "the default value is dropped");
		t3.equal((await getFeature(listFeatures, "death_markers")).enabled, false, "the feature is disabled");
		t3.strictSame(broadcasts.map(event => event.updates.map(update => update.id)), [["death_markers"]], "the update is broadcast");

		const subscription = await featureSubscription({ lastRequestTimeMs: record.updatedAtMs - 1 });
		t3.strictSame(subscription.updates.map(update => update.id), ["death_markers"], "subscribers catch up on the change");
	});

	t2.test("FeatureUpdateRequest rejects invalid values", async t3 => {
		const { updateFeature } = await startPlugin(t3, { withPlugins: false });
		await t3.rejects(
			updateFeature(new messages.FeatureUpdateRequest("death_markers", true, { unknown: 1 })),
			{ message: "Feature death_markers has no setting unknown" },
		);
	});

	t2.test("stored features are kept across restarts", async t3 => {
		const databaseDirectory = t3.testdir();
		const { updateFeature, shutdown } = await startPlugin(t3, { withPlugins: false, databaseDirectory });
		await updateFeature(new messages.FeatureUpdateRequest("afk_kick", false, { afk_minutes: 5 }));
		await shutdown();

		const { listFeatures } = await startPlugin(t3, { withPlugins: false, databaseDirectory });
		const record = await getFeature(listFeatures, "afk_kick");
		t3.strictSame([record.enabled, record.values], [false, { afk_minutes: 5 }], "the stored record is loaded");
	});

	t2.end();
});
