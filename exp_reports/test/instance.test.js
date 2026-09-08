"use strict";
const t = require("tap");
const lib = require("@clusterio/lib");
const { Instance } = require("@clusterio/host");
const { InstancePlugin } = require("../dist/node/instance");
const { plugin: pluginDeclaration } = require("../dist/node/index");
const messages = require("../dist/node/messages");

// The instance validates message classes against the link registry
for (const Message of pluginDeclaration.messages) {
	lib.Link.register(Message);
}

class TestConnector extends lib.BaseConnector {
	constructor() {
		super(lib.Address.fromShorthand({ instanceId: 1 }), lib.Address.fromShorthand({ hostId: 1 }));
		this.valid = true;
		this.connected = true;
		this.hasSession = true;
	}

	send() {}
}

const report = (id, playerName, byPlayerName) => new messages.ReportRecord(id, playerName, byPlayerName, "griefing", "EXP", 1000);

/** Build a plugin around a real running instance with spies on what leaves it. */
async function startPlugin(t2, { reports = [report(1, "bob", "alice"), report(2, "bob", "carol")] } = {}) {
	const instanceConfig = new lib.InstanceConfig("host");
	instanceConfig.set("instance.id", 1);
	instanceConfig.set("instance.name", "test");

	const instance = new Instance(
		{ assignGamePort: () => 1 }, new TestConnector(), t2.testdir(), "factorioDir", instanceConfig
	);

	// Spies which record the messages and commands leaving the instance
	const state = { sent: [], rcons: [], failNext: null };
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
		if (request instanceof messages.ReportCreateRequest) {
			return report(3, request.playerName, request.byPlayerName);
		}
		if (request instanceof messages.ReportListRequest) {
			return reports.filter(other => request.playerName === undefined || other.playerName === request.playerName);
		}
		return undefined;
	};

	instance.notifyStatus("running");
	state.sent.length = 0;

	const plugin = new InstancePlugin({ name: "exp_reports" }, instance, {});
	await plugin.init();
	return { plugin, instance, state };
}

/** The lua receiver and payload of a recorded rcon command. */
function decodeRcon(command) {
	const match = command.match(/^\/sc exp_reports\.(\w+)\(helpers\.json_to_table\[=\[(.*)\]=\]\)$/s);
	return { receiver: match[1], payload: JSON.parse(match[2]) };
}

t.test("class InstancePlugin", t2 => {
	t2.test(".handleCreateIPC() creates the report and hands it to lua with the others against the player", async t3 => {
		const { plugin, state } = await startPlugin(t3);
		await plugin.handleCreateIPC({ player_name: "bob", by_player_name: "dave", reason: "griefing" });

		const create = state.sent.find(request => request instanceof messages.ReportCreateRequest);
		t3.strictSame([create.playerName, create.byPlayerName, create.reason], ["bob", "dave", "griefing"]);
		t3.ok(state.sent.some(request => request instanceof messages.ReportListRequest && request.playerName === "bob"),
			"the reports against the player are requested");

		const { receiver, payload } = decodeRcon(state.rcons[0]);
		t3.strictSame(receiver, "receive_created");
		t3.strictSame(payload.report.by_player_name, "dave", "the new report is sent");
		t3.strictSame(payload.reports.map(other => other.by_player_name), ["alice", "carol"], "along with the existing ones");
	});

	t2.test(".handleCreateIPC() prints a refusal to the reporter", async t3 => {
		const { plugin, state } = await startPlugin(t3);
		state.failNext = new lib.RequestError("dave has already reported bob");
		await plugin.handleCreateIPC({ player_name: "bob", by_player_name: "dave", reason: "griefing" });

		const { receiver, payload } = decodeRcon(state.rcons[0]);
		t3.strictSame(receiver, "receive_error");
		t3.strictSame(payload, { caller: "dave", message: "dave has already reported bob" });
	});

	t2.test(".handleListIPC() lists the reports for the caller", async t3 => {
		const { plugin, state } = await startPlugin(t3);
		await plugin.handleListIPC({ caller: "admin", player_name: "bob" });
		await plugin.handleListIPC({ caller: "admin", player_name: undefined });

		const forPlayer = decodeRcon(state.rcons[0]);
		t3.strictSame(forPlayer.receiver, "receive_list");
		t3.strictSame([forPlayer.payload.caller, forPlayer.payload.player_name], ["admin", "bob"]);
		t3.strictSame(forPlayer.payload.reports.length, 2);

		const forAll = decodeRcon(state.rcons[1]);
		t3.strictSame(forAll.payload.player_name, undefined, "no player when listing everyone");
	});

	t2.test(".handleDeleteIPC() deletes only the matching reports", async t3 => {
		const { plugin, state } = await startPlugin(t3);
		await plugin.handleDeleteIPC({ caller: "admin", player_name: "bob", by_player_name: "carol" });

		const deletes = state.sent.filter(request => request instanceof messages.ReportDeleteRequest);
		t3.strictSame(deletes.map(request => request.id), [2], "only carol's report is deleted");
		const { receiver, payload } = decodeRcon(state.rcons[0]);
		t3.strictSame(receiver, "receive_deleted");
		t3.strictSame(payload, { caller: "admin", player_name: "bob", by_player_name: "carol", count: 1 });

		state.sent.length = 0;
		await plugin.handleDeleteIPC({ caller: "admin", player_name: "bob", by_player_name: undefined });
		t3.strictSame(
			state.sent.filter(request => request instanceof messages.ReportDeleteRequest).length, 2,
			"every report is deleted without a reporter",
		);
	});

	t2.test(".luaSend() drops answers once the instance has stopped", async t3 => {
		const { plugin, instance, state } = await startPlugin(t3);
		instance.notifyStatus("stopped");
		await plugin.handleListIPC({ caller: "admin", player_name: undefined });
		t3.strictSame(state.rcons, [], "nothing is sent to a stopped instance");
	});

	t2.end();
});
