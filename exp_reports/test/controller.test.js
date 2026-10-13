import t from "tap";
import * as lib from "@clusterio/lib";
import { Controller, InstanceRecord } from "@clusterio/controller";
import entrypoint from "../dist/node/controller.js";
import * as messages from "../dist/node/messages.js";
import { plugin as pluginDeclaration } from "../dist/node/index.js";

// The controller validates message classes against the link registry, and the
// plugin's config fields must be defined before a ControllerConfig can set them
for (const Message of pluginDeclaration.messages) {
	lib.Link.register(Message);
}
lib.addPluginConfigFields([pluginDeclaration]);

const logger = { child: () => logger, info: () => {}, warn: () => {}, error: () => {}, verbose: () => {} };

// Silence the singleton logger to avoid polluting the test output
lib.logger.silent = true;
t.after(() => {
	lib.logger.silent = false;
});

const fromInstance = lib.Address.fromShorthand({ instanceId: 1 });
const fromUnknownInstance = lib.Address.fromShorthand({ instanceId: 9 });
const fromControl = lib.Address.fromShorthand({ controlId: 7 });

/** Run the plugin on a real controller, which is side effect free while not started, returns the handlers it registered. */
async function startPlugin(t2, { config = {} } = {}) {
	const controllerConfig = new lib.ControllerConfig("controller", {
		"controller.database_directory": t2.testdir(),
		...config,
	});
	const controller = new Controller(logger, [], controllerConfig);

	const instanceConfig = new lib.InstanceConfig("controller");
	instanceConfig.set("instance.id", 1);
	instanceConfig.set("instance.name", "EXP");
	controller.instances.records.set(new InstanceRecord(instanceConfig, "running"));
	controller.wsServer.controlConnections.set(7, { user: { name: "admin" } });

	// Spies which record and then defer to the real behaviour
	const state = { broadcasts: [], posts: [], warnings: [] };
	const broadcast = controller.subscriptions.broadcast.bind(controller.subscriptions);
	controller.subscriptions.broadcast = event => {
		state.broadcasts.push(event);
		broadcast(event);
	};

	const realFetch = globalThis.fetch;
	globalThis.fetch = async (url, init) => {
		state.posts.push({ url, body: JSON.parse(init.body) });
		return state.fetchResult();
	};
	state.fetchResult = () => ({ ok: true, status: 200 });
	t2.teardown(() => { globalThis.fetch = realFetch; });

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

	const pluginLogger = { ...logger, warn: message => state.warnings.push(message) };
	await entrypoint({ plugin: { name: "exp_reports" }, controller, logger: pluginLogger });
	const request = (Request, ...args) => handlers.get(Request)(new Request(...args), fromInstance);
	return {
		controller,
		state,
		create: (playerName, reason, byPlayerName, src = fromInstance) => handlers.get(messages.ReportCreateRequest)(
			new messages.ReportCreateRequest(playerName, reason, byPlayerName), src,
		),
		list: playerName => request(messages.ReportListRequest, playerName),
		get: id => request(messages.ReportGetRequest, id),
		remove: id => request(messages.ReportDeleteRequest, id),
		subscription: lastRequestTimeMs => handlers.get(messages.ReportUpdatedEvent)({ lastRequestTimeMs }),
	};
}

/** Let the webhook posts which are not awaited finish. */
const settle = () => new Promise(resolve => setImmediate(resolve));

t.test("entrypoint", async t2 => {
	const controllerConfig = new lib.ControllerConfig("controller", { "controller.database_directory": t2.testdir() });
	const controller = new Controller(logger, [], controllerConfig);
	await entrypoint({ controller, logger, plugin: { name: "exp_reports" }, metrics: undefined });
	for (const hook of ["shutdown"]) {
		t2.ok([...controller.hooks[hook].attached].includes("exp_reports"), `attached to ${hook}`);
	}
	await controller.hooks.shutdown.invoke();
});

t.test("controller plugin", t2 => {
	t2.test("ReportCreateRequest from an instance records the instance and the reporter", async t3 => {
		const { create, list } = await startPlugin(t3);
		const report = await create("bob", " griefing ", "alice", fromInstance);

		t3.strictSame(report.playerName, "bob");
		t3.strictSame(report.byPlayerName, "alice", "the reporter comes from the request");
		t3.strictSame(report.reason, "griefing", "the reason is trimmed");
		t3.strictSame(report.instanceName, "EXP", "the instance is named");
		t3.ok(report.updatedAtMs > 0, "the report is timestamped");
		t3.strictSame(await list(), [report], "the report is stored");

		const unknown = await create("carol", "spam", "alice", fromUnknownInstance);
		t3.strictSame(unknown.instanceName, "9", "an unknown instance is named by its id");
	});

	t2.test("ReportCreateRequest from the web ui uses the user of the connection", async t3 => {
		const { create } = await startPlugin(t3);
		const report = await create("bob", "griefing", "someone-else", fromControl);

		t3.strictSame(report.byPlayerName, "admin", "the reporter is the connected user");
		t3.strictSame(report.instanceName, "", "there is no instance");
	});

	t2.test("ReportCreateRequest rejects reports which can not be stored", async t3 => {
		const { create, list } = await startPlugin(t3);
		await create("bob", "griefing", "alice", fromInstance);

		await t3.rejects(
			create("bob", "again", "alice", fromInstance),
			{ message: "alice has already reported bob" },
			"a player can only report another once",
		);
		await t3.rejects(
			create("bob", "   ", "carol", fromInstance),
			{ message: "A report needs a reason" },
			"a reason is required",
		);
		await t3.rejects(
			create("bob", "spam", "", fromInstance),
			{ message: "A report needs the name of the player making it" },
			"an instance must name the reporter",
		);
		t3.strictSame((await list()).length, 1, "nothing else was stored");
	});

	t2.test("ReportListRequest and ReportGetRequest find reports", async t3 => {
		const { create, list, get } = await startPlugin(t3);
		const first = await create("bob", "griefing", "alice", fromInstance);
		await create("carol", "spam", "alice", fromInstance);

		t3.strictSame((await list()).length, 2, "everything is listed");
		t3.strictSame(
			await list("bob"), [first],
			"a player's reports are listed",
		);
		t3.strictSame(await get(first.id), first);
		await t3.rejects(
			get(123),
			{ message: "Report with ID 123 does not exist" },
		);
	});

	t2.test("ReportDeleteRequest removes the report and broadcasts the deletion", async t3 => {
		const { create, list, remove, state } = await startPlugin(t3);
		const report = await create("bob", "griefing", "alice", fromInstance);

		state.broadcasts.length = 0;
		await remove(report.id);
		t3.strictSame(await list(), [], "the report is gone");
		t3.ok(
			state.broadcasts.some(event => event instanceof messages.ReportUpdatedEvent && event.updates[0].isDeleted),
			"subscribers are told it was deleted",
		);
		await t3.rejects(
			remove(report.id),
			{ message: `Report with ID ${report.id} does not exist` },
		);
	});

	t2.test("subscribing replays only newer records", async t3 => {
		const { create, subscription } = await startPlugin(t3);
		const report = await create("bob", "griefing", "alice", fromInstance);

		const all = await subscription(0);
		t3.strictSame(all.updates, [report], "everything is replayed from the start");
		const none = await subscription(report.updatedAtMs);
		t3.strictSame(none, null, "nothing is replayed when up to date");
	});

	t2.test("new reports are posted to the configured hooks", async t3 => {
		const { create, remove, state } = await startPlugin(t3, { config: {
			"exp_reports.discord_webhook_url": "https://discord.example/hook",
			"exp_reports.json_webhook_url": "https://json.example/hook",
		} });
		const report = await create("bob", "griefing", "alice", fromInstance);

		t3.strictSame(state.posts.map(post => post.url), ["https://discord.example/hook", "https://json.example/hook"]);
		const embed = state.posts[0].body.embeds[0];
		t3.strictSame(embed.fields.map(field => field.value), ["bob", "alice", "EXP", "griefing"], "the embed names the report");
		t3.strictSame(state.posts[1].body, { type: "report_created", report: report.toJSON() }, "the json hook gets the record");

		state.posts.length = 0;
		await remove(report.id);
		t3.strictSame(state.posts, [], "deletions are not posted");
	});

	t2.test("nothing is posted without hooks", async t3 => {
		const { create, state } = await startPlugin(t3);
		await create("bob", "griefing", "alice", fromInstance);
		t3.strictSame(state.posts, []);
	});

	t2.test("webhooks log rather than throw when the hook fails", async t3 => {
		const { create, state } = await startPlugin(t3, { config: {
			"exp_reports.json_webhook_url": "https://down.example/hook",
		} });

		state.fetchResult = () => { throw new Error("connection refused"); };
		await create("bob", "griefing", "alice");
		await settle();
		t3.strictSame(state.warnings, ["Webhook https://down.example/hook failed: connection refused"]);

		state.fetchResult = () => ({ ok: false, status: 404 });
		await create("bob", "griefing", "carol");
		await settle();
		t3.strictSame(state.warnings[1], "Webhook https://down.example/hook responded with 404");
	});

	t2.end();
});
