import t from "tap";
import * as lib from "@clusterio/lib";
import { Controller } from "@clusterio/controller";
import { ControllerPlugin } from "../dist/node/controller.js";
import * as messages from "../dist/node/messages.js";

// The controller validates message classes against the link registry
lib.Link.register(messages.RoleUpdatedEvent);
lib.Link.register(messages.AssignmentUpdatedEvent);
lib.Link.register(messages.RoleListRequest);
lib.Link.register(messages.RoleMetaUpdateRequest);
lib.Link.register(messages.AssignmentListRequest);
lib.Link.register(messages.AssignmentUpdateRequest);

const logger = { child: () => logger, info: () => {}, warn: () => {}, error: () => {}, verbose: () => {} };

// Silence the singleton logger to avoid polluting the test output
lib.logger.silent = true;
t.after(() => {
	lib.logger.silent = false;
});

/** Build a plugin around a real controller, which is side effect free while not started. */
async function startPlugin(t2, { roles = [] } = {}) {
	const controllerConfig = new lib.ControllerConfig("controller", {
		"controller.database_directory": t2.testdir(),
		"controller.default_role_id": lib.Role.DefaultPlayerRoleId,
	});
	const controller = new Controller(logger, [], controllerConfig);
	for (const role of roles) {
		controller.roles.set(role);
	}

	// Spies which record and then defer to the real behaviour
	const state = { broadcasts: [], permissionUpdates: [] };
	const broadcast = controller.subscriptions.broadcast.bind(controller.subscriptions);
	controller.subscriptions.broadcast = event => {
		state.broadcasts.push(event);
		broadcast(event);
	};
	const permissionsUpdated = controller.userPermissionsUpdated.bind(controller);
	controller.userPermissionsUpdated = user => {
		state.permissionUpdates.push(user.name);
		permissionsUpdated(user);
	};

	const plugin = new ControllerPlugin({ name: "exp_roles" }, controller, undefined, logger);
	await plugin.init();
	return { plugin, controller, state };
}

const role = (id, name, permissions = []) => new lib.Role(id, name, "", new Set(permissions));

t.test("class ControllerPlugin", t2 => {
	t2.test(".init() and .sweepRoleMeta() manage the role properties", async t3 => {
		const { plugin } = await startPlugin(t3, { roles: [role(0, "Cluster Admin"), role(5, "Moderator")] });

		t3.strictSame(plugin.roleMeta.get(0).order, 1, "the first role is ordered first");
		t3.strictSame(plugin.roleMeta.get(5).order, 2, "the next role is ordered after it");

		plugin.roleMeta.set(new messages.RoleMetaRecord(99, 3));
		plugin.sweepRoleMeta();
		t3.notOk(plugin.roleMeta.get(99), "properties without a role are removed");
		t3.ok(plugin.roleMeta.get(5), "properties with a role are kept");
	});

	t2.test(".buildRoleRecord() combines the role with its properties", async t3 => {
		const { plugin, controller } = await startPlugin(t3, {
			roles: [role(1, "Player"), role(5, "Moderator", ["exp_scenario.command.kill"])],
		});
		plugin.roleMeta.set(new messages.RoleMetaRecord(5, 2, 1, "Mod"));

		const record = plugin.buildRoleRecord(controller.roles.get(5));
		t3.strictSame(record.name, "Moderator", "the name comes from the role");
		t3.strictSame(record.permissions, ["exp_scenario.command.kill"], "the permissions come from the role");
		t3.strictSame(record.meta.shortHand, "Mod", "the properties come from the datastore");
		t3.notOk(record.isDefault, "not the default role");
		t3.ok(plugin.buildRoleRecord(controller.roles.get(1)).isDefault, "the default role is marked");
	});

	t2.test(".rolesUpdated() and .roleMetaUpdated() broadcast to subscribers", async t3 => {
		const { plugin, controller, state } = await startPlugin(t3, { roles: [role(1, "Player")] });

		state.broadcasts.length = 0;
		controller.roles.set(role(5, "Moderator"));
		const updated = state.broadcasts
			.filter(event => event instanceof messages.RoleUpdatedEvent)
			.flatMap(event => event.updates.map(update => update.name));
		t3.ok(updated.includes("Moderator"), "a new role is broadcast");

		state.broadcasts.length = 0;
		plugin.roleMeta.set(new messages.RoleMetaRecord(5, 2, 0, "Mod"));
		t3.ok(state.broadcasts.some(
			event => event instanceof messages.RoleUpdatedEvent && event.updates[0].meta.shortHand === "Mod"
		), "a property change is broadcast as its role");

		state.broadcasts.length = 0;
		await plugin.onControllerConfigFieldChanged("controller.default_role_id");
		t3.ok(
			state.broadcasts.some(event => event instanceof messages.RoleUpdatedEvent),
			"a default role change rebroadcasts",
		);
	});

	t2.test(".handleRoleSubscription() replays only newer records", async t3 => {
		const { plugin, controller } = await startPlugin(t3, { roles: [role(1, "Player")] });
		controller.roles.set(role(5, "Moderator"));
		const updatedAtMs = plugin.buildRoleRecord(controller.roles.get(5)).updatedAtMs;

		const all = await plugin.handleRoleSubscription({ lastRequestTimeMs: 0 });
		t3.strictSame(all.updates.length, 2, "everything is replayed from the start");
		const none = await plugin.handleRoleSubscription({ lastRequestTimeMs: updatedAtMs });
		t3.strictSame(none, null, "nothing is replayed when up to date");
	});

	t2.test(".listAssignmentRecords() mirrors users without the default role", async t3 => {
		const { plugin, controller } = await startPlugin(t3, { roles: [role(1, "Player"), role(5, "Moderator")] });
		controller.users.createUser("alice").set("roleIds", new Set([lib.Role.DefaultPlayerRoleId, 5]));
		controller.users.createUser("bob");

		const records = plugin.listAssignmentRecords();
		t3.strictSame(records.length, 1, "users with only the default role are left out");
		t3.strictSame(records[0].name, "alice");
		t3.strictSame([...records[0].roleIds], [5], "the default role is not listed");
	});

	t2.test(".handleAssignmentUpdateRequest() validates the user and roles", async t3 => {
		const { plugin, controller, state } = await startPlugin(t3, {
			roles: [role(1, "Player"), role(5, "Moderator"), role(6, "Regular")],
		});
		controller.users.createUser("alice").set("roleIds", new Set([5]));

		await t3.rejects(
			plugin.handleAssignmentUpdateRequest(new messages.AssignmentUpdateRequest("nobody", [], [])),
			{ message: /does not exist/ }, "an unknown user is refused",
		);
		await t3.rejects(
			plugin.handleAssignmentUpdateRequest(new messages.AssignmentUpdateRequest("alice", [99], [])),
			{ message: /does not exist/ }, "an unknown role is refused",
		);

		await plugin.handleAssignmentUpdateRequest(new messages.AssignmentUpdateRequest("alice", [6], [5]));
		t3.strictSame([...controller.users.getByName("alice").roleIds], [6], "roles are added and removed");
		t3.ok(state.permissionUpdates.includes("alice"), "permission changes are pushed to the user");
	});

	t2.test(".applyAutoAssign() and .onPlayerEvent() grant roles from online time", async t3 => {
		const { plugin, controller } = await startPlugin(t3, {
			roles: [role(1, "Player"), role(6, "Regular"), role(7, "Jail")],
		});
		const onlineTime = ms => new Map([[1, lib.PlayerStats.fromJSON({ online_time_ms: ms })]]);
		controller.users.createUser("newcomer").set("instanceStats", onlineTime(3600000));
		controller.users.createUser("veteran").set("instanceStats", onlineTime(7200000));
		const jailed = controller.users.createUser("jailed");
		jailed.set("roleIds", new Set([7]));
		jailed.set("instanceStats", onlineTime(7200000));
		const roleIds = name => controller.users.getByName(name).roleIds;

		// The blocking role is marked first, since setting properties applies auto assignment
		plugin.roleMeta.set(new messages.RoleMetaRecord(7, 3, 1, "", "", null, null, true));
		plugin.roleMeta.set(new messages.RoleMetaRecord(6, 2, 0, "", "", null, 7200000));
		t3.ok(roleIds("veteran").has(6), "enough online time grants the role");
		t3.notOk(roleIds("newcomer").has(6), "not enough online time does not");
		t3.notOk(roleIds("jailed").has(6), "a blocking role prevents the grant");

		// Any user update also applies auto assignment, so the leave path is
		// observed directly rather than through a role change
		const applied = [];
		plugin.applyAutoAssign = names => applied.push(names);
		await plugin.onPlayerEvent(undefined, { type: "leave", name: "veteran" });
		t3.strictSame(applied, [["veteran"]], "a leave applies auto assignment for that user");
		await plugin.onPlayerEvent(undefined, { type: "join", name: "veteran" });
		t3.strictSame(applied.length, 1, "other player events do not");
	});

	t2.test(".handleRoleListRequest() returns the current roles", async t3 => {
		const { plugin } = await startPlugin(t3, {
			roles: [role(1, "Player"), role(5, "Moderator")],
		});
		plugin.roleMeta.set(new messages.RoleMetaRecord(5, 2, 0, "Mod"));

		const response = await plugin.handleRoleListRequest(new messages.RoleListRequest());
		t3.strictSame(response.length, 2, "the current roles are returned");
		t3.ok(response.some(record => record.name === "Moderator"));
		t3.ok(response.some(record => record.name === "Player"));
	});

	t2.test(".handleRoleMetaUpdateRequest() validates the role", async t3 => {
		const { plugin } = await startPlugin(t3, { roles: [role(1, "Player"), role(5, "Moderator")] });

		await t3.rejects(
			plugin.handleRoleMetaUpdateRequest(new messages.RoleMetaUpdateRequest(new messages.RoleMetaRecord(99, 1))),
			{ message: /does not exist/ }, "properties for an unknown role are refused",
		);

		await plugin.handleRoleMetaUpdateRequest(new messages.RoleMetaUpdateRequest(
			new messages.RoleMetaRecord(5, 2, 0, "Mod"),
		));
		t3.strictSame(plugin.roleMeta.get(5).shortHand, "Mod", "the properties are stored");
	});

	t2.test(".handleAssignmentListRequest() returns the current assignments", async t3 => {
		const { plugin, controller } = await startPlugin(t3, {
			roles: [role(1, "Player"), role(5, "Moderator")],
		});
		controller.users.createUser("alice").set("roleIds", new Set([5]));
		controller.users.createUser("bob");

		const response = await plugin.handleAssignmentListRequest(new messages.AssignmentListRequest());
		t3.strictSame(response.length, 1, "the current assignments are returned");
		t3.strictSame(response[0].name, "alice");
		t3.strictSame(response[0].roleIds, new Set([5]), "the default role is not listed");
	});

	t2.test(".handleAssignmentSubscription() replays only newer records", async t3 => {
		const { plugin, controller } = await startPlugin(t3, { roles: [role(1, "Player"), role(5, "Moderator")] });
		controller.users.createUser("alice").set("roleIds", new Set([5]));
		const updatedAtMs = plugin.listAssignmentRecords()[0].updatedAtMs;

		const all = await plugin.handleAssignmentSubscription({ lastRequestTimeMs: 0 });
		t3.strictSame(all.updates.length, 1, "everything is replayed from the start");
		const none = await plugin.handleAssignmentSubscription({ lastRequestTimeMs: updatedAtMs });
		t3.strictSame(none, null, "nothing is replayed when up to date");
	});

	t2.end();
});
