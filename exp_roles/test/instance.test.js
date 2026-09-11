import t from "tap";
import * as lib from "@clusterio/lib";
import { Instance } from "@clusterio/host";
import { InstancePlugin } from "../dist/node/instance.js";
import { plugin as pluginDeclaration } from "../dist/node/index.js";
import * as messages from "../dist/node/messages.js";

// The instance validates message classes against the link registry, and the
// plugin's config fields must be defined before an InstanceConfig can set them
lib.Link.register(messages.RoleUpdatedEvent);
lib.Link.register(messages.AssignmentUpdatedEvent);
lib.Link.register(messages.RoleListRequest);
lib.Link.register(messages.AssignmentListRequest);
lib.Link.register(messages.AssignmentUpdateRequest);
lib.addPluginConfigFields([pluginDeclaration]);

const logger = { child: () => logger, info: () => {}, warn: () => {}, error: () => {}, verbose: () => {} };

class TestConnector extends lib.BaseConnector {
	constructor() {
		super(lib.Address.fromShorthand({ instanceId: 1 }), lib.Address.fromShorthand({ hostId: 1 }));
		this.valid = true;
		this.connected = true;
		this.hasSession = true;
	}

	send() {}
}

const sampleRoles = () => [
	new messages.RoleRecord(1, "Player", ["exp_scenario.gui.readme"], new messages.RoleMetaRecord(1, 2), true),
	new messages.RoleRecord(5, "Moderator", ["exp_scenario.gui.readme", "core.admin"], new messages.RoleMetaRecord(5, 1)),
];
const sampleAssignments = () => [new messages.AssignmentRecord("alice", new Set([5]))];

/** Build a plugin around a real instance with spies on what leaves it, started on first use by each test. */
async function startPlugin(t2, { syncMode = "bidirectional", roles = sampleRoles() } = {}) {
	const instanceConfig = new lib.InstanceConfig("host");
	instanceConfig.set("instance.id", 1);
	instanceConfig.set("instance.name", "test");
	instanceConfig.set("exp_roles.sync_mode", syncMode);

	const instance = new Instance(
		{ assignGamePort: () => 1 }, new TestConnector(), t2.testdir(), "factorioDir", instanceConfig
	);

	// Spies which record the messages and commands leaving the instance
	const state = { sent: [], rcons: [], warnings: [], failNext: null };
	instance.server = {
		handle: () => {},
		sendRcon: async command => {
			state.rcons.push(command);
			return "";
		},
	};
	instance.sendTo = async (dst, request) => {
		state.sent.push(request);
		if (state.failNext) {
			const error = state.failNext;
			state.failNext = null;
			throw error;
		}
		if (request instanceof messages.RoleListRequest) {
			return roles;
		}
		if (request instanceof messages.AssignmentListRequest) {
			return sampleAssignments();
		}
		return undefined;
	};

	const plugin = new InstancePlugin({ name: "exp_roles" }, instance, {});
	plugin.logger = { ...logger, warn: message => state.warnings.push(message) };
	await plugin.init();
	return { plugin, state };
}

/** The lua receiver and payload of a recorded rcon command. */
function decodeRcon(command) {
	const match = command.match(/^\/sc exp_roles\.(\w+)\(helpers\.json_to_table\[=\[(.*)\]=\]\)$/s);
	return { receiver: match[1], payload: JSON.parse(match[2]) };
}

t.test("class InstancePlugin", t2 => {
	t2.test(".onStart() subscribes and initialises the lua module", async t3 => {
		const { plugin, state } = await startPlugin(t3, { syncMode: "enabled" });
		await plugin.onStart();

		const subscribed = state.sent.filter(request => request instanceof lib.SubscriptionRequest);
		t3.strictSame(subscribed.length, 2, "roles and assignments are subscribed to");
		t3.ok(state.sent.some(request => request instanceof messages.RoleListRequest), "the roles are requested");
		t3.ok(
			state.sent.some(request => request instanceof messages.AssignmentListRequest),
			"the assignments are requested",
		);

		const initialise = decodeRcon(state.rcons[0]);
		t3.strictSame(initialise.receiver, "initialise", "the lua module is initialised");
		t3.strictSame(initialise.payload.permission_names, ["exp_scenario.gui.readme", "core.admin"],
			"each permission name is sent once");
		t3.strictSame(initialise.payload.roles[1].permissions, [0, 1], "roles reference permissions by index");
		t3.strictSame(initialise.payload.assignments, [{ name: "alice", role_ids: [5] }], "the assignments are sent");

		const emit = decodeRcon(state.rcons[1]);
		t3.strictSame([emit.receiver, emit.payload], ["set_emit_events", false], "enabled does not emit changes back");
		t3.strictSame(state.warnings.length, 0, "no warnings with a default role");
	});

	t2.test(".onStart() with bidirectional emits changes back", async t3 => {
		const { plugin, state } = await startPlugin(t3);
		await plugin.onStart();
		const emit = decodeRcon(state.rcons[state.rcons.length - 1]);
		t3.strictSame([emit.receiver, emit.payload], ["set_emit_events", true]);
	});

	t2.test(".onStart() with disabled does nothing", async t3 => {
		const { plugin, state } = await startPlugin(t3, { syncMode: "disabled" });
		await plugin.onStart();
		t3.strictSame(state.sent.length, 0, "nothing is sent");
		t3.strictSame(state.rcons.length, 0, "no commands are run");
	});

	t2.test(".onStart() warns when no default role is set", async t3 => {
		const roles = sampleRoles().map(record => { record.isDefault = false; return record; });
		const { plugin, state } = await startPlugin(t3, { roles });
		await plugin.onStart();
		t3.ok(state.warnings.some(message => /default role/.test(message)), "the warning names the default role");
	});

	t2.test(".handleRoleUpdatedEvent() and .handleAssignmentUpdatedEvent() forward to lua", async t3 => {
		const { plugin, state } = await startPlugin(t3);
		await plugin.handleRoleUpdatedEvent(new messages.RoleUpdatedEvent(sampleRoles()));
		const roles = decodeRcon(state.rcons[0]);
		t3.strictSame(roles.receiver, "receive_role_updates", "role updates are forwarded");
		t3.strictSame(roles.payload[0].name, "Player", "the records are sent in plain form");

		await plugin.handleAssignmentUpdatedEvent(new messages.AssignmentUpdatedEvent(sampleAssignments()));
		const assignments = decodeRcon(state.rcons[1]);
		t3.strictSame(assignments.receiver, "receive_assignment_updates", "assignment updates are forwarded");
	});

	t2.test(".handleRoleUpdatedEvent() and .handleAssignmentUpdatedEvent() are gated while disabled", async t3 => {
		const { plugin, state } = await startPlugin(t3, { syncMode: "disabled" });
		await plugin.handleRoleUpdatedEvent(new messages.RoleUpdatedEvent(sampleRoles()));
		await plugin.handleAssignmentUpdatedEvent(new messages.AssignmentUpdatedEvent(sampleAssignments()));
		t3.strictSame(state.rcons.length, 0, "no commands are run");
	});

	t2.test(".handleAssignmentUpdateIPC() sends the change and rolls back a refusal", async t3 => {
		const { plugin, state } = await startPlugin(t3);
		await plugin.handleAssignmentUpdateIPC({ name: "alice", assign: [5], unassign: undefined });
		const request = state.sent[0];
		t3.ok(request instanceof messages.AssignmentUpdateRequest, "the change is sent as a request");
		t3.strictSame([request.name, request.assign, request.unassign], ["alice", [5], []], "the request names the change");

		await plugin.handleAssignmentUpdateIPC({ name: "alice", assign: undefined, unassign: [5] });
		t3.strictSame(state.sent[1].unassign, [5], "removals are sent the same way");

		state.failNext = new Error("User 'alice' does not exist");
		await plugin.handleAssignmentUpdateIPC({ name: "alice", assign: [5], unassign: undefined });
		const rollback = decodeRcon(state.rcons[0]);
		t3.strictSame(rollback.receiver, "reject_assignment", "the refusal is rolled back in lua");
		t3.strictSame(rollback.payload, { name: "alice", role_ids: [5] }, "the rollback names the refused roles");

		state.failNext = new Error("User 'alice' does not exist");
		await plugin.handleAssignmentUpdateIPC({ name: "alice", assign: undefined, unassign: [5] });
		t3.strictSame(state.rcons.length, 1, "a refused removal has nothing to roll back");
	});

	t2.test(".handleAssignmentUpdateIPC() is gated unless bidirectional", async t3 => {
		const { plugin, state } = await startPlugin(t3, { syncMode: "enabled" });
		await plugin.handleAssignmentUpdateIPC({ name: "alice", assign: [5], unassign: undefined });
		t3.strictSame(state.sent.length, 0, "nothing is sent");
	});

	t2.test(".onInstanceConfigFieldChanged() toggles emit with the sync mode", async t3 => {
		const { plugin, state } = await startPlugin(t3);
		await plugin.onInstanceConfigFieldChanged("exp_roles.sync_mode", "enabled", "bidirectional");
		const emit = decodeRcon(state.rcons[0]);
		t3.strictSame([emit.receiver, emit.payload], ["set_emit_events", false], "leaving bidirectional stops emitting");
	});

	t2.end();
});
