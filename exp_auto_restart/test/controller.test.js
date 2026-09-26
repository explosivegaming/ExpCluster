import t from "tap";
import * as lib from "@clusterio/lib";
import { Controller, HostRecord, InstanceRecord } from "@clusterio/controller";
import entrypoint, { AutoRestart, PENDING_TIMEOUT_MS } from "../dist/node/controller.js";
import { plugin as pluginDeclaration } from "../dist/node/index.js";

// The plugin's config fields must be defined before a ControllerConfig can set them
lib.addPluginConfigFields([pluginDeclaration]);

// Silence the singleton logger to avoid polluting the test output
lib.logger.silent = true;
t.after(() => {
	lib.logger.silent = false;
});

/** Build the plugin around a real controller, which is side effect free while not started. */
async function startPlugin(t2, { config = {}, canRestart = false } = {}) {
	const logs = [];
	const logger = {
		child: () => logger,
		info: message => logs.push(["info", message]),
		warn: message => logs.push(["warn", message]),
		error: message => logs.push(["error", message]),
		verbose: () => {},
	};
	const controllerConfig = new lib.ControllerConfig("controller", {
		"controller.database_directory": t2.testdir(),
		...config,
	});
	const controller = new Controller(logger, [], controllerConfig, canRestart);

	// Record what would be sent to hosts and instances instead of sending it
	const sent = [];
	controller.sendTo = async (address, message) => {
		sent.push({ address, message });
	};

	const plugin = new AutoRestart({ controller, logger, plugin: pluginDeclaration, metrics: undefined });
	plugin.start();
	t2.teardown(() => plugin.stop());
	return { plugin, controller, sent, logs };
}

function addHost(controller, id, connected = true) {
	controller.hosts.set(new HostRecord(id, `host-${id}`, "2.0.0", new Map(), connected));
}

function addInstance(controller, id, hostId, status = "running", fields = {}) {
	const config = new lib.InstanceConfig("controller", {
		"instance.id": id,
		"instance.name": `instance-${id}`,
		"instance.assigned_host": hostId,
		...fields,
	});
	const record = new InstanceRecord(config, status);
	controller.instances.records.set(record);
	return record;
}

function addSystem(controller, id, { restartRequired = true, canRestart = true, processStartedAtMs = 1000 } = {}) {
	controller.systems.set(new lib.SystemInfo(
		id, "box", "v22", "Linux", "x64", "cpu", [], 0, 0, 0, 0,
		canRestart, restartRequired, 0, processStartedAtMs, Date.now(), false,
	));
}

const join = (controller, name, instanceId) => controller.users.getOrCreateUser(name).notifyJoin(instanceId);
const leave = (controller, name, instanceId) => controller.users.getOrCreateUser(name).notifyLeave(instanceId);
const restartsSent = sent => sent.filter(({ message }) => message instanceof lib.HostRestartRequest);
const startsSent = sent => sent.filter(({ message }) => message instanceof lib.InstanceStartRequest);

t.test("entrypoint", async t2 => {
	const logger = { child: () => logger, info: () => {}, warn: () => {}, error: () => {}, verbose: () => {} };
	const controllerConfig = new lib.ControllerConfig("controller", { "controller.database_directory": t2.testdir() });
	const controller = new Controller(logger, [], controllerConfig);
	await entrypoint({ controller, logger, plugin: pluginDeclaration, metrics: undefined });
	for (const hook of ["shutdown", "playerEvent", "instanceStatusChanged", "hostConnectionEvent"]) {
		t2.ok([...controller.hooks[hook].attached].includes("exp_auto_restart"), `attached to ${hook}`);
	}
	await controller.hooks.shutdown.invoke();
});

t.test("class AutoRestart", t2 => {
	t2.test(".onlinePlayers() counts players on running instances per host", async t3 => {
		const { plugin, controller } = await startPlugin(t3);
		addHost(controller, 1);
		addHost(controller, 2);
		addInstance(controller, 10, 1);
		addInstance(controller, 11, 1, "stopped");
		addInstance(controller, 20, 2);
		join(controller, "alice", 10);
		join(controller, "bob", 10);
		join(controller, "carol", 11);
		join(controller, "dave", 20);

		t3.strictSame(plugin.onlinePlayers(), new Map([[1, 2], [2, 1]]), "players on stopped instances are not counted");
	});

	t2.test(".refreshIdle() tracks when hosts and the cluster became empty", async t3 => {
		const { plugin, controller } = await startPlugin(t3);
		addHost(controller, 1);
		addHost(controller, 2);
		addHost(controller, 3, false);
		addInstance(controller, 10, 1);
		join(controller, "alice", 10);

		plugin.refreshIdle(1000);
		t3.notOk(plugin.idleSince.has(1), "a host with players is not idle");
		t3.strictSame(plugin.idleSince.get(2), 1000, "an empty host is idle from now");
		t3.notOk(plugin.idleSince.has(3), "a disconnected host is not tracked");
		t3.notOk(plugin.idleSince.has("cluster"), "the cluster is not idle while anyone is online");

		leave(controller, "alice", 10);
		plugin.refreshIdle(2000);
		t3.strictSame(plugin.idleSince.get(1), 2000, "a host becomes idle when its last player leaves");
		t3.strictSame(plugin.idleSince.get(2), 1000, "an idle host keeps its original time");
		t3.strictSame(plugin.idleSince.get("cluster"), 2000, "the cluster becomes idle with the last player");

		join(controller, "alice", 10);
		plugin.refreshIdle(3000);
		t3.notOk(plugin.idleSince.has(1), "a join clears the idle time");
		t3.notOk(plugin.idleSince.has("cluster"));
	});

	t2.test(".check() restarts a host once it has been empty for long enough", async t3 => {
		const { plugin, controller, sent } = await startPlugin(t3, {
			config: { "exp_auto_restart.idle_seconds": 60 },
		});
		const now = Date.now();
		addHost(controller, 1);
		addInstance(controller, 10, 1);
		addInstance(controller, 11, 1, "stopped");
		addSystem(controller, 1);
		join(controller, "alice", 10);

		await plugin.check(now);
		t3.strictSame(restartsSent(sent).length, 0, "not restarted while a player is online");

		leave(controller, "alice", 10);
		await plugin.check(now + 10_000);
		t3.strictSame(restartsSent(sent).length, 0, "not restarted before the idle time has passed");

		await plugin.check(now + 70_000);
		t3.strictSame(restartsSent(sent).length, 1, "restarted once the idle time has passed");
		t3.strictSame(restartsSent(sent)[0].address, { hostId: 1 }, "the restart is sent to the host");
		t3.strictSame([...plugin.pending.get(1).instanceIds], [10], "only the running instances are remembered");

		await plugin.check(now + 80_000);
		t3.strictSame(restartsSent(sent).length, 1, "not restarted again while waiting for it to come back");
	});

	t2.test(".check() asks each host process only once", async t3 => {
		const { plugin, controller, sent } = await startPlugin(t3, {
			config: { "exp_auto_restart.idle_seconds": 0 },
		});
		const now = Date.now();
		addHost(controller, 1);
		addSystem(controller, 1, { processStartedAtMs: 1000 });

		await plugin.check(now);
		t3.strictSame(restartsSent(sent).length, 1, "restarted with no running instances");
		t3.notOk(plugin.pending.has(1), "nothing to wait for without running instances");

		await plugin.check(now + 10_000);
		t3.strictSame(restartsSent(sent).length, 1, "the same process is not asked again");

		addSystem(controller, 1, { restartRequired: false, processStartedAtMs: 2000 });
		await plugin.check(now + 20_000);
		t3.strictSame(restartsSent(sent).length, 1, "the new process does not need a restart");

		addSystem(controller, 1, { processStartedAtMs: 2000 });
		await plugin.check(now + 30_000);
		t3.strictSame(restartsSent(sent).length, 2, "the new process is restarted when it needs it");
	});

	t2.test(".check() leaves hosts alone that cannot or need not restart", async t3 => {
		const { plugin, controller, sent, logs } = await startPlugin(t3, {
			config: { "exp_auto_restart.idle_seconds": 0 },
		});
		const now = Date.now();
		addHost(controller, 1);
		addSystem(controller, 1, { canRestart: false });
		addHost(controller, 2);
		addSystem(controller, 2, { restartRequired: false });
		addHost(controller, 3, false);
		addSystem(controller, 3);

		await plugin.check(now);
		await plugin.check(now + 10_000);
		t3.strictSame(restartsSent(sent).length, 0, "no host is restarted");
		const warnings = logs.filter(([level, message]) => level === "warn" && message.includes("--can-restart"));
		t3.strictSame(warnings.length, 1, "a host without a process monitor is warned about once");
	});

	t2.test(".check() with scope cluster waits for the whole cluster to be empty", async t3 => {
		const { plugin, controller, sent } = await startPlugin(t3, {
			config: { "exp_auto_restart.idle_seconds": 0, "exp_auto_restart.scope": "cluster" },
		});
		const now = Date.now();
		addHost(controller, 1);
		addSystem(controller, 1);
		addHost(controller, 2);
		addInstance(controller, 20, 2);
		join(controller, "alice", 20);

		await plugin.check(now);
		t3.strictSame(restartsSent(sent).length, 0, "a player on another host holds back the restart");

		leave(controller, "alice", 20);
		await plugin.check(now + 10_000);
		t3.strictSame(restartsSent(sent).length, 1, "restarted once the cluster is empty");
	});

	t2.test(".restartHost() retries transport errors but not refusals", async t3 => {
		const { plugin, controller, sent, logs } = await startPlugin(t3, {
			config: { "exp_auto_restart.idle_seconds": 0 },
		});
		const now = Date.now();
		addHost(controller, 1);
		addInstance(controller, 10, 1);
		addSystem(controller, 1);

		controller.sendTo = async () => { throw new lib.RequestError("Cannot restart"); };
		await plugin.check(now);
		await plugin.check(now + 10_000);
		t3.strictSame(logs.filter(([level]) => level === "error").length, 1, "a refusal is logged once");
		t3.notOk(plugin.pending.has(1), "a refused restart is not waited on");

		addSystem(controller, 1, { processStartedAtMs: 2000 });
		let attempts = 0;
		controller.sendTo = async () => { attempts += 1; throw new Error("Connection lost"); };
		await plugin.check(now + 20_000);
		await plugin.check(now + 30_000);
		t3.strictSame(attempts, 2, "a transport error is retried on the next check");
	});

	t2.test(".instanceReported() starts the instances that were running", async t3 => {
		const { plugin, controller, sent } = await startPlugin(t3, {
			config: { "exp_auto_restart.idle_seconds": 0 },
		});
		const now = Date.now();
		addHost(controller, 1);
		const manual = addInstance(controller, 10, 1);
		const auto = addInstance(controller, 11, 1, "running", { "instance.auto_start": true });
		const stopped = addInstance(controller, 12, 1, "stopped");
		addSystem(controller, 1);
		await plugin.check(now);
		t3.strictSame([...plugin.pending.get(1).instanceIds], [10, 11]);

		// The host comes back and reports every instance as stopped
		for (const instance of [manual, auto, stopped]) {
			instance.status = "stopped";
			await plugin.onInstanceStatusChanged(instance, "unknown");
		}
		t3.strictSame(startsSent(sent).map(({ address }) => address), [{ instanceId: 10 }], "only the instance the host will not start itself is started");
		t3.notOk(plugin.pending.has(1), "the host is no longer waited on");

		// An instance reporting in without a pending restart is ignored
		await plugin.onInstanceStatusChanged(manual, "unknown");
		t3.strictSame(startsSent(sent).length, 1);
	});

	t2.test(".restartHost() does not wait on instances when they are not to be started", async t3 => {
		const { plugin, controller, sent } = await startPlugin(t3, {
			config: { "exp_auto_restart.idle_seconds": 0, "exp_auto_restart.start_instances": false },
		});
		addHost(controller, 1);
		const instance = addInstance(controller, 10, 1);
		addSystem(controller, 1);
		await plugin.check(Date.now());
		t3.strictSame(restartsSent(sent).length, 1);
		t3.notOk(plugin.pending.has(1), "nothing is waited on");

		instance.status = "stopped";
		await plugin.onInstanceStatusChanged(instance, "unknown");
		t3.strictSame(startsSent(sent).length, 0, "nothing is started");
	});

	t2.test(".expirePending() gives up on hosts that never come back", async t3 => {
		const { plugin, controller, logs } = await startPlugin(t3, {
			config: { "exp_auto_restart.idle_seconds": 0 },
		});
		const now = Date.now();
		addHost(controller, 1);
		addInstance(controller, 10, 1);
		addSystem(controller, 1);
		await plugin.check(now);
		t3.ok(plugin.pending.has(1));

		await plugin.check(now + PENDING_TIMEOUT_MS - 1);
		t3.ok(plugin.pending.has(1), "still waited on before the timeout");
		await plugin.check(now + PENDING_TIMEOUT_MS);
		t3.notOk(plugin.pending.has(1), "no longer waited on after the timeout");
		t3.ok(logs.some(([level, message]) => level === "warn" && message.includes("giving up")), "giving up is logged");
	});

	t2.test(".checkController() restarts the controller when the cluster is empty", async t3 => {
		const { plugin, controller } = await startPlugin(t3, {
			config: { "exp_auto_restart.idle_seconds": 60, "exp_auto_restart.restart_controller": true },
			canRestart: true,
		});
		const now = Date.now();
		let stopped = 0;
		controller.stop = async () => { stopped += 1; };
		controller.checkRestartDowngrade = async () => null;
		addHost(controller, 1);
		addInstance(controller, 10, 1);
		addSystem(controller, "controller");
		join(controller, "alice", 10);

		await plugin.check(now);
		t3.strictSame(stopped, 0, "not restarted while a player is online");

		leave(controller, "alice", 10);
		await plugin.check(now + 10_000);
		t3.strictSame(stopped, 0, "not restarted before the idle time has passed");

		await plugin.check(now + 70_000);
		t3.strictSame(stopped, 1, "restarted once the cluster has been empty for long enough");
		t3.ok(controller.shouldRestart, "stopped with the intent to restart");

		await plugin.check(now + 80_000);
		t3.strictSame(stopped, 1, "not restarted twice");
	});

	t2.test(".checkController() refuses downgrades and missing process monitors", async t3 => {
		const { plugin, controller, logs } = await startPlugin(t3, {
			config: { "exp_auto_restart.idle_seconds": 0, "exp_auto_restart.restart_controller": true },
			canRestart: true,
		});
		let stopped = 0;
		controller.stop = async () => { stopped += 1; };
		controller.checkRestartDowngrade = async () => ({ installedVersion: "2.0.0", runningVersion: "2.0.1" });
		addSystem(controller, "controller");

		await plugin.check(Date.now());
		t3.strictSame(stopped, 0, "not restarted into an older version");
		t3.ok(logs.some(([level, message]) => level === "warn" && message.includes("older")), "the downgrade is logged");

		plugin.warned.clear();
		addSystem(controller, "controller", { canRestart: false });
		await plugin.check(Date.now());
		t3.strictSame(stopped, 0, "not restarted without a process monitor");
		t3.ok(logs.some(([level, message]) => level === "warn" && message.includes("--can-restart")));
	});

	t2.test(".start() warns when system metrics are disabled", async t3 => {
		const { logs } = await startPlugin(t3, { config: { "controller.system_metrics_interval": 0 } });
		t3.ok(logs.some(([level, message]) => level === "warn" && message.includes("system_metrics_interval")));
	});

	t2.end();
});
