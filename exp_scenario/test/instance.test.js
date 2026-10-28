import t from "tap";
import * as lib from "@clusterio/lib";
import { Instance } from "@clusterio/host";
import entrypoint from "../dist/node/instance.js";
import { plugin as pluginDeclaration } from "../dist/node/index.js";
import * as messages from "../dist/node/messages.js";
import { features } from "../dist/node/features.js";

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

/** Run the plugin on a real instance with spies on what leaves it, returns the event handler it registered. */
async function startPlugin(
	t2, features = [new messages.FeatureRecord("death_markers", false, { show_map_markers: false })], players = [],
) {
	const instanceConfig = new lib.InstanceConfig("host");
	instanceConfig.set("instance.id", 1);
	instanceConfig.set("instance.name", "test");

	const state = { sent: [], rcons: [] };
	const ipcHandlers = new Map();
	const server = {
		on: () => {},
		handle: (channel, handler) => ipcHandlers.set(channel, handler),
		sendRcon: async command => {
			state.rcons.push(command);
			return "";
		},
	};
	const instance = new Instance(
		{ assignGamePort: () => 1 }, new TestConnector(), t2.testdir(), instanceConfig, server
	);
	instance.sendTo = async (dst, request) => {
		state.sent.push(request);
		if (request instanceof messages.PlayerGetRequest) {
			const found = players.find(record => record.id === request.playerName);
			return found ?? new messages.PlayerRecord(request.playerName);
		}
		return request instanceof messages.FeatureListRequest ? features : undefined;
	};

	const handlers = new Map();
	instance.handle = (Event, handler) => handlers.set(Event, handler);

	await entrypoint({ plugin: { name: "exp_scenario" }, instance, host: {}, logger });
	const hooks = instance.hooks;
	return {
		state,
		start: () => hooks.start.invoke(),
		exit: () => hooks.exit.invoke(),
		connectionEvent: event => hooks.controllerConnectionEvent.invoke(event),
		featureUpdated: handlers.get(messages.FeatureUpdatedEvent),
		ipc: (channel, event) => ipcHandlers.get(channel)(event),
		playerEvent: event => hooks.playerEvent.invoke(event),
		setStatus: status => { instance._status = status; },
	};
}

/** The payload of a recorded rcon command. */
function decodeRcon(command) {
	const match = command.match(/^\/sc exp_scenario\.features\.receive_update\(helpers\.json_to_table\[(=+)\[(.*)\]\1\]\)$/s);
	return JSON.parse(match[2]);
}

/** The player data and code of a recorded rcon command made by luaWithPlayer. */
function decodePlayerRcon(command) {
	const match = command.match(
		/^\/sc local d = helpers\.json_to_table\[(=+)\[(.*)\]\1\] local p = game\.get_player\(d\.name\) if p then (.*) end$/s,
	);
	return { data: JSON.parse(match[2]), code: match[3] };
}

t.test("instance plugin", t2 => {
	t2.test("start subscribes and sends every feature to lua", async t3 => {
		const { start, state } = await startPlugin(t3);
		await start();

		t3.ok(state.sent[0] instanceof lib.SubscriptionRequest, "subscribes to updates first");
		t3.ok(state.sent[1] instanceof messages.FeatureListRequest, "then lists the features");
		const [update] = decodeRcon(state.rcons[0]);
		const deathMarkers = features.find(feature => feature.name === "death_markers");
		t3.equal(update.name, "death_markers");
		t3.strictSame([update.values.enabled, update.values.show_map_markers], [false, false], "stored values are sent");
		t3.equal(update.values.collect_corpses, true, "the rest are filled with their defaults");
		t3.equal(Object.keys(update.values).length, deathMarkers.fields.length + 1, "every field and enabled");
	});

	t2.test("FeatureUpdatedEvent only sends while the game is up", async t3 => {
		const { start, exit, featureUpdated, state } = await startPlugin(t3);
		const event = new messages.FeatureUpdatedEvent([
			new messages.FeatureRecord("afk_kick", true, { afk_minutes: 5 }),
			new messages.FeatureRecord("removed", true, {}, 0, true),
		]);

		await featureUpdated(event);
		t3.strictSame(state.rcons, [], "nothing is sent before start");

		await start();
		state.rcons.length = 0;
		await featureUpdated(event);
		const updates = decodeRcon(state.rcons[0]);
		t3.strictSame(updates.map(update => update.name), ["afk_kick"], "deleted features are left out");
		t3.strictSame([updates[0].values.enabled, updates[0].values.afk_minutes], [true, 5]);

		await exit();
		state.rcons.length = 0;
		await featureUpdated(event);
		t3.strictSame(state.rcons, [], "nothing is sent after exit");
	});

	t2.test("a new controller connection syncs again after the controller restarts", async t3 => {
		const { start, connectionEvent, state } = await startPlugin(t3);
		await connectionEvent("connect");
		t3.strictSame(state.sent, [], "nothing happens before start");

		await start();
		state.sent.length = 0;
		state.rcons.length = 0;
		await connectionEvent("resume");
		t3.strictSame(state.sent, [], "a resumed session keeps its subscription");

		await connectionEvent("connect");
		t3.ok(state.sent[0] instanceof lib.SubscriptionRequest, "subscribes again");
		t3.equal(state.rcons.length, 1, "and sends every feature");
	});

	t2.test("feature updates pick a long bracket the values do not close", async t3 => {
		const { start, featureUpdated, state } = await startPlugin(t3, []);
		await start();
		const name = "a]=]b]==]c";
		await featureUpdated(new messages.FeatureUpdatedEvent([
			new messages.FeatureRecord("station_auto_name", true, { station_name: name }),
		]));
		t3.match(state.rcons[0], "json_to_table[===[", "uses a level not found in the json");
		t3.strictSame(decodeRcon(state.rcons[0])[0].values.station_name, name);
	});

	t2.end();
});

t.test("player settings", t2 => {
	const alice = new messages.PlayerRecord("Alice", "Alice has arrived ]=] ]==]");

	t2.test("a joining player's message is printed to everyone", async t3 => {
		const { start, playerEvent, setStatus, state } = await startPlugin(t3, [], [alice]);
		await start();
		setStatus("running");
		state.rcons.length = 0;

		await playerEvent({ type: "join", name: "Alice" });
		t3.equal(state.rcons.length, 1);
		const { data, code } = decodePlayerRcon(state.rcons[0]);
		t3.strictSame(data, { message: alice.joinMessage, name: "Alice" }, "the message survives the long bracket");
		t3.equal(code, "game.print(d.message, { color = p.color })");

		await playerEvent({ type: "join", name: "Bob" });
		await playerEvent({ type: "leave", name: "Alice" });
		t3.equal(state.rcons.length, 1, "players without a message and leaves print nothing");
	});

	t2.test("nothing is printed while the instance is not running or greetings are disabled", async t3 => {
		const { start, playerEvent, setStatus, featureUpdated, state } = await startPlugin(t3, [], [alice]);
		await start();
		state.rcons.length = 0;
		await playerEvent({ type: "join", name: "Alice" });
		t3.strictSame(state.rcons, [], "not running");

		setStatus("running");
		await featureUpdated(new messages.FeatureUpdatedEvent([new messages.FeatureRecord("greetings", false)]));
		state.rcons.length = 0;
		await playerEvent({ type: "join", name: "Alice" });
		t3.strictSame(state.rcons, [], "greetings disabled");
	});

	t2.test("ipc from the set and remove commands is forwarded to the controller", async t3 => {
		const { ipc, state } = await startPlugin(t3);
		await ipc("exp_scenario:join_message_set", { player_name: "Alice", message: "Hi" });
		await ipc("exp_scenario:join_message_set", { player_name: "Alice" });
		const sent = state.sent.filter(request => request instanceof messages.JoinMessageSetRequest);
		t3.strictSame(sent.map(request => [request.playerName, request.message]), [["Alice", "Hi"], ["Alice", null]]);
	});

	t2.test("a joining player's stored toolbar is sent to the lua side", async t3 => {
		const bob = new messages.PlayerRecord("Bob", undefined, "eNqrVkrLz1eyUlBKSixSqgUAGQwD8g==");
		const { start, playerEvent, setStatus, state } = await startPlugin(t3, [], [bob]);
		await start();
		setStatus("running");
		state.rcons.length = 0;

		await playerEvent({ type: "join", name: "Bob" });
		t3.equal(state.rcons.length, 1, "only the toolbar, Bob has no join message");
		const { data, code } = decodePlayerRcon(state.rcons[0]);
		t3.strictSame(data, { toolbar: bob.toolbar, name: "Bob" });
		t3.equal(code, "exp_scenario.player_settings.receive_toolbar(d.name, d.toolbar)");
	});

	t2.test("ipc with a toolbar is forwarded to the controller", async t3 => {
		const { ipc, state } = await startPlugin(t3);
		await ipc("exp_scenario:toolbar", { player_name: "Alice", toolbar: "abc" });
		const [event] = state.sent.filter(request => request instanceof messages.PlayerToolbarEvent);
		t3.strictSame([event.playerName, event.toolbar], ["Alice", "abc"]);
	});

	t2.test("ipc asking for the message prints it to the player", async t3 => {
		const { ipc, setStatus, state } = await startPlugin(t3, [], [alice]);
		setStatus("running");
		await ipc("exp_scenario:join_message_get", { player_name: "Alice" });
		await ipc("exp_scenario:join_message_get", { player_name: "Bob" });
		const [found, missing] = state.rcons.map(decodePlayerRcon);
		t3.equal(found.data.message, alice.joinMessage);
		t3.equal(missing.data.message, undefined, "no message key, so the lua side prints message-none");
		t3.match(found.code, "exp_greetings.message-none");
	});

	t2.end();
});
