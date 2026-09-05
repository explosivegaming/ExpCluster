"use strict";
const t = require("tap");
const lib = require("@clusterio/lib");
const { Controller, InstanceRecord } = require("@clusterio/controller");
const { ControllerPlugin } = require("../dist/node/controller");
const messages = require("../dist/node/messages");
const { plugin: pluginDeclaration } = require("../dist/node/index");

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

/** Build the plugin around a real controller, which is side effect free while not started. */
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

	const plugin = new ControllerPlugin({ name: "exp_reports" }, controller, undefined, logger);
	plugin.logger = { ...logger, warn: message => state.warnings.push(message) };
	plugin.postWebhook = async (url, body) => { state.posts.push({ url, body }); };
	await plugin.init();
	return { plugin, controller, state };
}

t.test("class ControllerPlugin", t2 => {
	t2.test(".handleReportCreateRequest() from an instance records the instance and the reporter", async t3 => {
		const { plugin } = await startPlugin(t3);
		const report = await plugin.handleReportCreateRequest(
			new messages.ReportCreateRequest("bob", " griefing ", "alice"), fromInstance,
		);

		t3.strictSame(report.playerName, "bob");
		t3.strictSame(report.byPlayerName, "alice", "the reporter comes from the request");
		t3.strictSame(report.reason, "griefing", "the reason is trimmed");
		t3.strictSame(report.instanceName, "EXP", "the instance is named");
		t3.ok(report.updatedAtMs > 0, "the report is timestamped");
		t3.strictSame(plugin.listReports(), [report], "the report is stored");

		const unknown = await plugin.handleReportCreateRequest(
			new messages.ReportCreateRequest("carol", "spam", "alice"), fromUnknownInstance,
		);
		t3.strictSame(unknown.instanceName, "9", "an unknown instance is named by its id");
	});

	t2.test(".handleReportCreateRequest() from the web ui uses the user of the connection", async t3 => {
		const { plugin } = await startPlugin(t3);
		const report = await plugin.handleReportCreateRequest(
			new messages.ReportCreateRequest("bob", "griefing", "someone-else"), fromControl,
		);

		t3.strictSame(report.byPlayerName, "admin", "the reporter is the connected user");
		t3.strictSame(report.instanceName, "", "there is no instance");
	});

	t2.test(".handleReportCreateRequest() rejects reports which can not be stored", async t3 => {
		const { plugin } = await startPlugin(t3);
		await plugin.handleReportCreateRequest(new messages.ReportCreateRequest("bob", "griefing", "alice"), fromInstance);

		await t3.rejects(
			plugin.handleReportCreateRequest(new messages.ReportCreateRequest("bob", "again", "alice"), fromInstance),
			{ message: "alice has already reported bob" },
			"a player can only report another once",
		);
		await t3.rejects(
			plugin.handleReportCreateRequest(new messages.ReportCreateRequest("bob", "   ", "carol"), fromInstance),
			{ message: "A report needs a reason" },
			"a reason is required",
		);
		await t3.rejects(
			plugin.handleReportCreateRequest(new messages.ReportCreateRequest("bob", "spam", ""), fromInstance),
			{ message: "A report needs the name of the player making it" },
			"an instance must name the reporter",
		);
		t3.strictSame(plugin.listReports().length, 1, "nothing else was stored");
	});

	t2.test(".handleReportListRequest() and .handleReportGetRequest() find reports", async t3 => {
		const { plugin } = await startPlugin(t3);
		const first = await plugin.handleReportCreateRequest(new messages.ReportCreateRequest("bob", "griefing", "alice"), fromInstance);
		await plugin.handleReportCreateRequest(new messages.ReportCreateRequest("carol", "spam", "alice"), fromInstance);

		t3.strictSame((await plugin.handleReportListRequest(new messages.ReportListRequest())).length, 2, "everything is listed");
		t3.strictSame(
			await plugin.handleReportListRequest(new messages.ReportListRequest("bob")), [first],
			"a player's reports are listed",
		);
		t3.strictSame(await plugin.handleReportGetRequest(new messages.ReportGetRequest(first.id)), first);
		await t3.rejects(
			plugin.handleReportGetRequest(new messages.ReportGetRequest(123)),
			{ message: "Report with ID 123 does not exist" },
		);
	});

	t2.test(".handleReportDeleteRequest() removes the report and broadcasts the deletion", async t3 => {
		const { plugin, state } = await startPlugin(t3);
		const report = await plugin.handleReportCreateRequest(new messages.ReportCreateRequest("bob", "griefing", "alice"), fromInstance);

		state.broadcasts.length = 0;
		await plugin.handleReportDeleteRequest(new messages.ReportDeleteRequest(report.id));
		t3.strictSame(plugin.listReports(), [], "the report is gone");
		t3.ok(
			state.broadcasts.some(event => event instanceof messages.ReportUpdatedEvent && event.updates[0].isDeleted),
			"subscribers are told it was deleted",
		);
		await t3.rejects(
			plugin.handleReportDeleteRequest(new messages.ReportDeleteRequest(report.id)),
			{ message: `Report with ID ${report.id} does not exist` },
		);
	});

	t2.test(".handleReportSubscription() replays only newer records", async t3 => {
		const { plugin } = await startPlugin(t3);
		const report = await plugin.handleReportCreateRequest(new messages.ReportCreateRequest("bob", "griefing", "alice"), fromInstance);

		const all = await plugin.handleReportSubscription({ lastRequestTimeMs: 0 });
		t3.strictSame(all.updates, [report], "everything is replayed from the start");
		const none = await plugin.handleReportSubscription({ lastRequestTimeMs: report.updatedAtMs });
		t3.strictSame(none, null, "nothing is replayed when up to date");
	});

	t2.test(".sendWebhooks() posts new reports to the configured hooks", async t3 => {
		const { plugin, state } = await startPlugin(t3, { config: {
			"exp_reports.discord_webhook_url": "https://discord.example/hook",
			"exp_reports.json_webhook_url": "https://json.example/hook",
		} });
		const report = await plugin.handleReportCreateRequest(new messages.ReportCreateRequest("bob", "griefing", "alice"), fromInstance);

		t3.strictSame(state.posts.map(post => post.url), ["https://discord.example/hook", "https://json.example/hook"]);
		const embed = state.posts[0].body.embeds[0];
		t3.strictSame(embed.fields.map(field => field.value), ["bob", "alice", "EXP", "griefing"], "the embed names the report");
		t3.strictSame(state.posts[1].body, { type: "report_created", report: report.toJSON() }, "the json hook gets the record");

		state.posts.length = 0;
		await plugin.handleReportDeleteRequest(new messages.ReportDeleteRequest(report.id));
		t3.strictSame(state.posts, [], "deletions are not posted");
	});

	t2.test(".sendWebhooks() does nothing without hooks", async t3 => {
		const { plugin, state } = await startPlugin(t3);
		await plugin.handleReportCreateRequest(new messages.ReportCreateRequest("bob", "griefing", "alice"), fromInstance);
		t3.strictSame(state.posts, []);
	});

	t2.test(".postWebhook() logs rather than throws when the hook fails", async t3 => {
		const { plugin, state } = await startPlugin(t3);
		plugin.postWebhook = ControllerPlugin.prototype.postWebhook;

		const realFetch = globalThis.fetch;
		globalThis.fetch = async () => { throw new Error("connection refused"); };
		t3.teardown(() => { globalThis.fetch = realFetch; });

		await plugin.postWebhook("https://down.example/hook", {});
		t3.strictSame(state.warnings, ["Webhook https://down.example/hook failed: connection refused"]);

		globalThis.fetch = async () => ({ ok: false, status: 404 });
		await plugin.postWebhook("https://down.example/hook", {});
		t3.strictSame(state.warnings[1], "Webhook https://down.example/hook responded with 404");
	});

	t2.end();
});
