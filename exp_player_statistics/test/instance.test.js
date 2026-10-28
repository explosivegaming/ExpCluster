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

/** Run the plugin on a real instance with spies on what leaves it, returns the IPC handlers it registered. */
async function startPlugin(t2, { status = "running", stats = { Kills: 3 } } = {}) {
	const instanceConfig = new lib.InstanceConfig("host");
	instanceConfig.set("instance.id", 1);
	instanceConfig.set("instance.name", "test");


	const state = { sent: [], rcons: [], warnings: [] };
	const ipc = new Map();
	const server = {
		on: () => {},
		handle: (name, handler) => ipc.set(name, handler),
	};
	const instance = new Instance(
		{ assignGamePort: () => 1 }, new TestConnector(), t2.testdir(), instanceConfig, server
	);
	instance.sendRcon = async command => {
		state.rcons.push(command);
		return "";
	};
	instance.sendTo = async (dst, message) => {
		state.sent.push(message);
		if (message instanceof messages.StatisticsGetRequest) {
			return new messages.PlayerStatistics(message.name, stats);
		}
		return undefined;
	};

	instance.notifyStatus(status);
	state.sent.length = 0;

	const pluginLogger = { ...logger, warn: message => state.warnings.push(message) };
	await entrypoint({ plugin: { name: "exp_player_statistics" }, instance, host: {}, logger: pluginLogger });
	return { instance, state, updateIPC: event => ipc.get("exp_player_statistics:update")(event) };
}

/** The payload of a recorded receive_totals command. */
function decodeTotals(command) {
	const pattern = /^\/sc exp_player_statistics\.receive_totals\(helpers\.json_to_table\[(=+)\[(.*)\]\1\]\)$/s;
	const match = command.match(pattern);
	return JSON.parse(match[2]);
}

t.test("instance plugin", t2 => {
	t2.test("exp_player_statistics:update is forwarded to the controller", async t3 => {
		const { state, updateIPC } = await startPlugin(t3);
		await updateIPC({ players: [{ name: "alice", stats: { Kills: 1 } }, { name: "bob", stats: { Deaths: 2 } }] });

		t3.equal(state.sent.length, 1, "one event");
		const event = state.sent[0];
		t3.ok(event instanceof messages.StatisticsUpdateEvent);
		t3.strictSame(event.deltas.map(delta => [delta.name, delta.stats]), [
			["alice", { Kills: 1 }],
			["bob", { Deaths: 2 }],
		]);
	});

	t2.test("a player joining is sent their totals", async t3 => {
		const { instance, state } = await startPlugin(t3);
		await instance.hooks.playerEvent.invoke({ type: "join", name: "alice" });

		const request = state.sent[0];
		t3.ok(request instanceof messages.StatisticsGetRequest);
		t3.equal(request.name, "alice");
		t3.equal(state.rcons.length, 1);
		t3.strictSame(decodeTotals(state.rcons[0]), { name: "alice", stats: { Kills: 3 } });
	});

	t2.test("the long bracket is not in the json", async t3 => {
		const { instance, state } = await startPlugin(t3, { stats: { "]=]": 1 } });
		await instance.hooks.playerEvent.invoke({ type: "join", name: "alice" });
		t3.ok(state.rcons[0].includes("[==["), "a longer bracket is used");
		t3.strictSame(decodeTotals(state.rcons[0]).stats, { "]=]": 1 });
	});

	t2.test("leaving and other player events send nothing", async t3 => {
		const { instance, state } = await startPlugin(t3);
		await instance.hooks.playerEvent.invoke({ type: "leave", name: "alice", reason: "quit" });
		await instance.hooks.playerEvent.invoke({ type: "promote", name: "alice" });
		t3.strictSame(state.sent, []);
		t3.strictSame(state.rcons, []);
	});

	t2.test("totals are not sent once the instance is no longer running", async t3 => {
		const { instance, state } = await startPlugin(t3, { status: "stopping" });
		await instance.hooks.playerEvent.invoke({ type: "join", name: "alice" });
		t3.strictSame(state.rcons, []);
	});

	t2.test("a failed request is logged", async t3 => {
		const { instance, state } = await startPlugin(t3);
		instance.sendTo = async () => { throw new Error("controller gone"); };
		await instance.hooks.playerEvent.invoke({ type: "join", name: "alice" });
		t3.strictSame(state.rcons, []);
		t3.match(state.warnings[0], /alice: controller gone/);
	});

	t2.test("start drops what was unsent and stop sends the rest", async t3 => {
		const { instance, state } = await startPlugin(t3);
		await instance.hooks.start.invoke();
		await instance.hooks.stop.invoke();
		t3.strictSame(state.rcons, [
			"/sc exp_player_statistics.discard_unsent()",
			"/sc exp_player_statistics.send_all()",
		]);
	});

	t2.end();
});
