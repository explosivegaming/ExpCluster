import t from "tap";
import * as lib from "@clusterio/lib";
import { Instance } from "@clusterio/host";
import { InstancePlugin } from "../dist/node/instance.js";
import { plugin as pluginDeclaration } from "../dist/node/index.js";
import * as messages from "../dist/node/messages.js";

// The instance validates message classes against the link registry
for (const Message of pluginDeclaration.messages) {
	lib.Link.register(Message);
}

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

function server(id, name = `instance-${id}`) {
	return new messages.ServerRecord(id, name, name, "", "", "", false, "Base", "2.1.14", 0, "running", "");
}

/** Build a plugin around a real instance with spies on what leaves it. */
async function startPlugin(t2, servers = [server(1), server(2)]) {
	const instanceConfig = new lib.InstanceConfig("host");
	instanceConfig.set("instance.id", 1);
	instanceConfig.set("instance.name", "test");

	const instance = new Instance(
		{ assignGamePort: () => 1 }, new TestConnector(), t2.testdir(), "factorioDir", instanceConfig
	);

	const state = { sent: [], rcons: [] };
	instance.server = {
		handle: () => {},
		sendRcon: async command => {
			state.rcons.push(command);
			return "";
		},
	};
	instance.sendTo = async (dst, request) => {
		state.sent.push(request);
		return request instanceof messages.ServerListRequest ? servers : undefined;
	};

	const context = { plugin: { name: "exp_server_list" }, instance, host: {}, logger };
	const plugin = await InstancePlugin.fromContext(context);
	return { plugin, instance, state };
}

/** The payload of a recorded rcon command. */
function decodeRcon(command) {
	const match = command.match(/^\/sc exp_server_list\.receive_update\(helpers\.json_to_table\[(=+)\[(.*)\]\1\]\)$/s);
	return JSON.parse(match[2]);
}

t.test("class InstancePlugin", t2 => {
	t2.test(".onStart() subscribes and replaces the list in lua", async t3 => {
		const { plugin, state } = await startPlugin(t3);
		await plugin.onStart();

		t3.ok(state.sent[0] instanceof lib.SubscriptionRequest, "subscribes to updates first");
		t3.ok(state.sent[1] instanceof messages.ServerListRequest, "then lists the servers");
		const payload = decodeRcon(state.rcons[0]);
		t3.equal(payload.current_id, 1, "tells lua which server it is");
		t3.equal(payload.replace, true);
		t3.strictSame(payload.servers.map(entry => entry.short_name), ["instance-1", "instance-2"]);
	});

	t2.test(".handleServerUpdatesEvent() only sends while the game is up", async t3 => {
		const { plugin, state } = await startPlugin(t3);
		const event = new messages.ServerUpdatesEvent([server(2, "renamed")]);

		await plugin.handleServerUpdatesEvent(event);
		t3.strictSame(state.rcons, [], "nothing is sent before start");

		await plugin.onStart();
		state.rcons.length = 0;
		await plugin.handleServerUpdatesEvent(event);
		const payload = decodeRcon(state.rcons[0]);
		t3.equal(payload.replace, false, "updates are merged");
		t3.strictSame(payload.servers.map(entry => entry.name), ["renamed"]);

		await plugin.onExit();
		state.rcons.length = 0;
		await plugin.handleServerUpdatesEvent(event);
		t3.strictSame(state.rcons, [], "nothing is sent after exit");
	});

	t2.test(".onControllerConnectionEvent() syncs again after the controller restarts", async t3 => {
		const { plugin, state } = await startPlugin(t3);
		await plugin.onControllerConnectionEvent("connect");
		t3.strictSame(state.sent, [], "nothing happens before start");

		await plugin.onStart();
		state.sent.length = 0;
		state.rcons.length = 0;
		await plugin.onControllerConnectionEvent("resume");
		t3.strictSame(state.sent, [], "a resumed session keeps its subscription");

		await plugin.onControllerConnectionEvent("connect");
		t3.ok(state.sent[0] instanceof lib.SubscriptionRequest, "subscribes again");
		t3.equal(decodeRcon(state.rcons[0]).replace, true, "and replaces the list");
	});

	t2.test(".luaSendServers() picks a long bracket the values do not close", async t3 => {
		const { plugin, state } = await startPlugin(t3);
		const name = "a]=]b]==]c";
		await plugin.luaSendServers([server(3, name)], false);
		t3.match(state.rcons[0], "json_to_table[===[", "uses a level not found in the json");
		t3.equal(decodeRcon(state.rcons[0]).servers[0].name, name);
	});

	t2.end();
});
