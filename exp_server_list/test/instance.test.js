import t from "tap";
import * as lib from "@clusterio/lib";
import { Instance } from "@clusterio/host";
import entrypoint from "../dist/node/instance.js";
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
	return new messages.ServerRecord(
		id, name, name, "", "", "", false, false, false, "Base", "2.1.14", 0, "running", "",
	);
}

/** Run the plugin on a real instance with spies on what leaves it. */
async function startPlugin(t2, servers = [server(1), server(2)]) {
	const instanceConfig = new lib.InstanceConfig("host");
	instanceConfig.set("instance.id", 1);
	instanceConfig.set("instance.name", "test");


	const state = { sent: [], rcons: [] };
	const server = {
		on: () => {},
		handle: () => {},
		sendRcon: async command => {
			state.rcons.push(command);
			return "";
		},
	};
	const instance = new Instance(
		{ assignGamePort: () => 1 }, new TestConnector(), t2.testdir(), instanceConfig, server
	);
	instance.sendTo = async (dst, request) => {
		if (request instanceof lib.InstanceStatusChangedEvent) {
			return undefined;
		}
		state.sent.push(request);
		return request instanceof messages.ServerListRequest ? servers : undefined;
	};

	const handlers = new Map();
	instance.handle = (Class, handler) => handlers.set(Class, handler);

	await entrypoint({ plugin: { name: "exp_server_list" }, instance, host: {}, logger });
	return {
		instance,
		state,
		/** What the host does once rcon is up */
		start: async () => {
			instance.notifyStatus("starting");
			await instance.hooks.start.invoke();
			instance.notifyStatus("running");
		},
		update: event => handlers.get(messages.ServerUpdatesEvent)(event),
		connection: event => instance.hooks.controllerConnectionEvent.invoke(event),
		clear: () => {
			state.sent.length = 0;
			state.rcons.length = 0;
		},
	};
}

/** The payload of a recorded rcon command. */
function decodeRcon(command) {
	const match = command.match(/^\/sc exp_server_list\.receive_update\(helpers\.json_to_table\[(=+)\[(.*)\]\1\]\)$/s);
	return JSON.parse(match[2]);
}

t.test("start subscribes and replaces the list in lua", async t2 => {
	const { start, state } = await startPlugin(t2);
	await start();

	t2.ok(state.sent[0] instanceof lib.SubscriptionRequest, "subscribes to updates first");
	t2.ok(state.sent[1] instanceof messages.ServerListRequest, "then lists the servers");
	const payload = decodeRcon(state.rcons[0]);
	t2.equal(payload.current_id, 1, "tells lua which server it is");
	t2.equal(payload.replace, true);
	t2.strictSame(payload.servers.map(entry => entry.display_name), ["instance-1", "instance-2"]);
});

t.test("updates are only sent while the game is up", async t2 => {
	const { instance, start, update, clear, state } = await startPlugin(t2);
	const event = new messages.ServerUpdatesEvent([server(2, "renamed")]);

	await update(event);
	t2.strictSame(state.rcons, [], "nothing is sent before start");

	await start();
	clear();
	await update(event);
	const payload = decodeRcon(state.rcons[0]);
	t2.equal(payload.replace, false, "updates are merged");
	t2.strictSame(payload.servers.map(entry => entry.name), ["renamed"]);

	instance.notifyStatus("stopped");
	clear();
	await update(event);
	t2.strictSame(state.rcons, [], "nothing is sent after the game stopped");
});

t.test("syncs again after the controller restarts", async t2 => {
	const { start, connection, clear, state } = await startPlugin(t2);
	await connection("connect");
	t2.strictSame(state.sent, [], "nothing happens before start");

	await start();
	clear();
	await connection("resume");
	t2.strictSame(state.sent, [], "a resumed session keeps its subscription");

	await connection("connect");
	t2.ok(state.sent[0] instanceof lib.SubscriptionRequest, "subscribes again");
	t2.equal(decodeRcon(state.rcons[0]).replace, true, "and replaces the list");
});

t.test("picks a long bracket the values do not close", async t2 => {
	const name = "a]=]b]==]c";
	const { start, state } = await startPlugin(t2, [server(3, name)]);
	await start();
	t2.match(state.rcons[0], "json_to_table[===[", "uses a level not found in the json");
	t2.equal(decodeRcon(state.rcons[0]).servers[0].name, name);
});
