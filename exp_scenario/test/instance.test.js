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
async function startPlugin(t2, features = [new messages.FeatureRecord("death_markers", false, { show_map_markers: false })]) {
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
	};
}

/** The payload of a recorded rcon command. */
function decodeRcon(command) {
	const match = command.match(/^\/sc exp_scenario\.features\.receive_update\(helpers\.json_to_table\[(=+)\[(.*)\]\1\]\)$/s);
	return JSON.parse(match[2]);
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
