import t from "tap";
import * as lib from "@clusterio/lib";
import { Controller } from "@clusterio/controller";
import entrypoint from "../dist/node/controller.js";
import * as messages from "../dist/node/messages.js";
import { plugin as pluginDeclaration } from "../dist/node/index.js";

// The controller validates message classes against the link registry
for (const Message of pluginDeclaration.messages) {
	lib.Link.register(Message);
}

const logger = { child: () => logger, info: () => {}, warn: () => {}, error: () => {}, verbose: () => {} };

// Silence the singleton logger to avoid polluting the test output
lib.logger.silent = true;
t.after(() => {
	lib.logger.silent = false;
});

const fromInstance = lib.Address.fromShorthand({ instanceId: 1 });

/** Run the plugin on a real controller, which is side effect free while not started, returns its handlers. */
async function startPlugin(t2, databaseDirectory = t2.testdir()) {
	const controllerConfig = new lib.ControllerConfig("controller", {
		"controller.database_directory": databaseDirectory,
	});
	const controller = new Controller(logger, [], controllerConfig);

	const state = { broadcasts: [] };
	controller.subscriptions.broadcast = event => {
		state.broadcasts.push(event);
	};

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

	await entrypoint({ plugin: { name: "exp_player_statistics" }, controller, logger });
	const delta = (name, stats) => new messages.StatisticsDelta(name, stats);
	return {
		controller,
		state,
		update: (...deltas) => handlers.get(messages.StatisticsUpdateEvent)(
			new messages.StatisticsUpdateEvent(deltas.map(([name, stats]) => delta(name, stats))), fromInstance,
		),
		get: name => handlers.get(messages.StatisticsGetRequest)(new messages.StatisticsGetRequest(name), fromInstance),
		list: () => handlers.get(messages.StatisticsListRequest)(new messages.StatisticsListRequest(), fromInstance),
		/** The stored totals, without the values get adds from the clusterio user */
		stored: async name => (await handlers.get(messages.StatisticsListRequest)(
			new messages.StatisticsListRequest(), fromInstance,
		)).find(player => player.id === name)?.stats,
		subscription: lastRequestTimeMs => handlers.get(messages.PlayerStatisticsUpdatedEvent)({ lastRequestTimeMs }),
	};
}

t.test("entrypoint attaches to save and shutdown", async t2 => {
	const { controller } = await startPlugin(t2);
	for (const hook of ["save", "shutdown"]) {
		t2.ok([...controller.hooks[hook].attached].includes("exp_player_statistics"), `attached to ${hook}`);
	}
});

t.test("controller plugin", t2 => {
	t2.test("StatisticsUpdateEvent adds the deltas to the totals", async t3 => {
		const { update, stored } = await startPlugin(t3);
		await update(["alice", { Kills: 2, AfkTime: 5 }], ["bob", { Deaths: 1 }]);
		await update(["alice", { Kills: 3, Deaths: 1 }]);

		t3.strictSame(await stored("alice"), { Kills: 5, AfkTime: 5, Deaths: 1 }, "deltas are summed per stat");
		t3.strictSame(await stored("bob"), { Deaths: 1 });
	});

	t2.test("StatisticsGetRequest adds Playtime and JoinCount from the clusterio user", async t3 => {
		const { controller, update, get } = await startPlugin(t3);
		const user = controller.users.getOrCreateUser("alice");
		user.instanceStats.set(1, lib.PlayerStats.fromJSON({ join_count: 3, online_time_ms: 125.5 * 60e3 }));
		user.recalculatePlayerStats();
		await update(["alice", { Kills: 1 }]);

		t3.strictSame((await get("alice")).stats, { Kills: 1, Playtime: 125, JoinCount: 3 });
		t3.strictSame((await get("bob")).stats, { Playtime: 0, JoinCount: 0 }, "no user and no record");
	});

	t2.test("StatisticsUpdateEvent merges deltas for the same player in one update", async t3 => {
		const { update, stored, state } = await startPlugin(t3);
		await update(["alice", { Kills: 1 }], ["alice", { Kills: 2 }]);

		t3.strictSame(await stored("alice"), { Kills: 3 });
		t3.equal(state.broadcasts.length, 1, "one broadcast");
		t3.strictSame(state.broadcasts[0].updates.map(player => player.id), ["alice"], "with the player once");
	});

	t2.test("StatisticsUpdateEvent ignores values which are not finite or zero", async t3 => {
		const { update, stored } = await startPlugin(t3);
		await update(["alice", { Kills: 1, Deaths: 0, Bad: Infinity, Worse: NaN }]);
		t3.strictSame(await stored("alice"), { Kills: 1 });
	});

	t2.test("StatisticsGetRequest gives an empty record for an unknown player", async t3 => {
		const { get, list } = await startPlugin(t3);
		const record = await get("carol");
		t3.equal(record.id, "carol");
		t3.strictSame(record.stats, { Playtime: 0, JoinCount: 0 });
		t3.strictSame(await list(), [], "nothing is stored");
	});

	t2.test("StatisticsListRequest lists every player", async t3 => {
		const { update, list } = await startPlugin(t3);
		await update(["alice", { Kills: 1 }], ["bob", { Kills: 2 }]);
		t3.strictSame((await list()).map(player => player.id).sort(), ["alice", "bob"]);
	});

	t2.test("subscribing replays only newer records", async t3 => {
		const { update, subscription } = await startPlugin(t3);
		await update(["alice", { Kills: 1 }]);
		const all = await subscription(0);
		t3.strictSame(all.updates.map(player => player.id), ["alice"]);
		t3.equal(await subscription(all.updates[0].updatedAtMs), null, "nothing newer");
	});

	t2.test("totals are saved and loaded", async t3 => {
		const directory = t3.testdir();
		const first = await startPlugin(t3, directory);
		await first.update(["alice", { Kills: 4 }]);
		await first.controller.hooks.save.invoke();

		const second = await startPlugin(t3, directory);
		t3.strictSame(await second.stored("alice"), { Kills: 4 });
	});

	t2.end();
});

t.test("permissions", async t2 => {
	const names = pluginDeclaration.permissions.map(permission => permission.name);
	t2.strictSame(names, ["exp_player_statistics.view"]);
	for (const Message of [
		messages.StatisticsGetRequest, messages.StatisticsListRequest, messages.PlayerStatisticsUpdatedEvent,
	]) {
		t2.equal(Message.permission, "exp_player_statistics.view", `${Message.name} needs view`);
	}
	t2.equal(messages.StatisticsUpdateEvent.permission, null, "updates only come from instances");
	t2.strictSame(messages.StatisticsUpdateEvent.src, "instance");
});

t.test("messages round trip through json", async t2 => {
	const record = new messages.PlayerStatistics("alice", { Kills: 1 }, 10);
	t2.strictSame(messages.PlayerStatistics.fromJSON(JSON.parse(JSON.stringify(record))), record);
	const event = new messages.StatisticsUpdateEvent([new messages.StatisticsDelta("bob", { Deaths: 2 })]);
	t2.strictSame(messages.StatisticsUpdateEvent.fromJSON(JSON.parse(JSON.stringify(event))), event);
});
