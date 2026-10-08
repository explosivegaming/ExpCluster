import t from "tap";
import * as lib from "@clusterio/lib";
import { Controller, HostRecord, InstanceRecord } from "@clusterio/controller";
import entrypoint, { ControllerPlugin } from "../dist/node/controller.js";
import { plugin as pluginDeclaration } from "../dist/node/index.js";
import * as messages from "../dist/node/messages.js";

// The plugin's config fields must be defined before an InstanceConfig can set them
lib.addPluginConfigFields([pluginDeclaration]);
for (const Message of pluginDeclaration.messages) {
	lib.Link.register(Message);
}

const logger = { child: () => logger, info: () => {}, warn: () => {}, error: () => {}, verbose: () => {} };

/** Build the plugin around a real controller, which is side effect free while not started. */
async function startPlugin(t2, setup = () => {}) {
	const controllerConfig = new lib.ControllerConfig("controller", {
		"controller.database_directory": t2.testdir(),
	});
	const controller = new Controller(logger, [], controllerConfig);
	setup(controller);

	const broadcasts = [];
	controller.subscriptions.broadcast = event => {
		if (event instanceof messages.ServerUpdatesEvent) {
			broadcasts.push(event);
		}
	};

	const context = { controller, logger, plugin: pluginDeclaration, metrics: undefined };
	const plugin = await ControllerPlugin.fromContext(context);
	return { plugin, controller, broadcasts };
}

function addHost(controller, id, publicAddress = "") {
	controller.hosts.set(new HostRecord(id, `host-${id}`, "2.0.0", new Map(), true, "", publicAddress));
}

function addInstance(controller, id, { hostId = 1, status = "running", gamePort, factorioVersion, fields = {} } = {}) {
	const config = new lib.InstanceConfig("controller", {
		"instance.id": id,
		"instance.name": `instance-${id}`,
		"instance.assigned_host": hostId,
		...fields,
	});
	const record = new InstanceRecord(config, status, gamePort, factorioVersion);
	controller.instances.records.set(record);
	controller.instances.addInstanceHooks(record);
	return record;
}

const subscription = since => new lib.SubscriptionRequest("exp_server_list:ServerUpdatesEvent", "subscribe", since);
const join = (controller, name, instanceId) => controller.users.getOrCreateUser(name).notifyJoin(instanceId);

t.test("entrypoint", async t2 => {
	const controllerConfig = new lib.ControllerConfig("controller", { "controller.database_directory": t2.testdir() });
	const controller = new Controller(logger, [], controllerConfig);
	await entrypoint({ controller, logger, plugin: pluginDeclaration, metrics: undefined });
	const hooks = [
		"instanceStatusChanged",
		"instanceConfigFieldChanged",
		"controllerConfigFieldChanged",
		"playerEvent",
		"modPacksUpdated",
	];
	for (const hook of hooks) {
		t2.ok([...controller.hooks[hook].attached].includes("exp_server_list"), `attached to ${hook}`);
	}
	t2.ok(ControllerPlugin.get(controller), "other plugins can find it");
});

t.test("class ControllerPlugin", t2 => {
	t2.test("builds a record for every instance on start", async t3 => {
		const { plugin } = await startPlugin(t3, controller => {
			addHost(controller, 1, "example.com");
			addInstance(controller, 10, {
				gamePort: 34197,
				factorioVersion: "2.1.14",
				fields: {
					"exp_server_list.description": "Weekly reset",
					"exp_server_list.hidden": true,
				},
			});
			addInstance(controller, 11, {
				status: "stopped",
				factorioVersion: "latest",
				fields: { "exp_server_list.short_name": "S11" },
			});
		});

		const server = plugin.servers.get(10);
		t3.equal(server.name, "instance-10");
		t3.equal(server.shortName, "instance-10", "short name falls back to the name");
		t3.equal(server.description, "Weekly reset");
		t3.equal(server.hidden, true);
		t3.equal(server.factorioVersion, "2.1.14");
		t3.equal(server.address, "example.com:34197", "public address of the host and the game port");
		t3.equal(server.status, "running");

		const stopped = plugin.servers.get(11);
		t3.equal(stopped.shortName, "S11");
		t3.equal(stopped.factorioVersion, "", "the latest target is not a version");
		t3.equal(stopped.address, "example.com", "host address alone without a game port");
	});

	t2.test("uses the mod pack of the instance or the default", async t3 => {
		const { plugin, controller } = await startPlugin(t3, c => {
			addHost(c, 1);
			c.modPacks.setMany(lib.ModPack.defaultModPacks.map(pack => lib.ModPack.fromJSON(pack.toJSON())));
			const packs = [...c.modPacks.values()];
			c.config.set("controller.default_mod_pack_id", packs[0].id);
			addInstance(c, 10);
			addInstance(c, 11, { fields: { "factorio.mod_pack_id": packs[1].id } });
		});
		const packs = [...controller.modPacks.values()];
		t3.equal(plugin.servers.get(10).modPackName, packs[0].name, "the default mod pack");
		t3.equal(plugin.servers.get(11).modPackName, packs[1].name, "the instance mod pack");
		t3.equal(plugin.servers.get(10).address, "", "no address while the host has none");
	});

	t2.test("counts players only while running", async t3 => {
		const { plugin, controller, broadcasts } = await startPlugin(t3, c => {
			addHost(c, 1);
			addInstance(c, 10);
		});
		const instance = controller.instances.get(10);

		join(controller, "alice", 10);
		join(controller, "bob", 10);
		await controller.hooks.playerEvent.invoke(instance, { type: "join", name: "bob" });
		t3.equal(plugin.servers.get(10).playerCount, 2);
		t3.equal(broadcasts.at(-1).updates[0].playerCount, 2, "the change is broadcast");

		instance.status = "stopped";
		await controller.hooks.instanceStatusChanged.invoke(instance, "running");
		t3.equal(plugin.servers.get(10).playerCount, 0, "players left online by a crash are not counted");
	});

	t2.test("follows config, host and status changes", async t3 => {
		const { plugin, controller, broadcasts } = await startPlugin(t3, c => {
			addHost(c, 1);
			addInstance(c, 10, { gamePort: 34197 });
		});
		const instance = controller.instances.getMutable(10);

		instance.config.set("instance.name", "Weekly");
		t3.equal(plugin.servers.get(10).name, "Weekly", "renames are picked up");

		instance.config.set("exp_server_list.welcome", "Hello");
		t3.equal(plugin.servers.get(10).welcome, "Hello", "plugin fields are picked up");

		addHost(controller, 1, "example.com");
		t3.equal(plugin.servers.get(10).address, "example.com:34197", "the public address once the host sends it");

		const count = broadcasts.length;
		addHost(controller, 1, "example.com");
		t3.equal(broadcasts.length, count, "nothing is broadcast when nothing changed");

		// What deleteInstance does once the host has deleted it
		controller.instances.records.delete(instance);
		await controller.hooks.instanceStatusChanged.invoke(instance, "running");
		t3.equal(plugin.servers.get(10), undefined, "deleted instances are removed");
		t3.equal(broadcasts.at(-1).updates[0].isDeleted, true, "and broadcast as deleted");
	});

	t2.test(".handleServerSubscription() sends servers updated since the last request", async t3 => {
		const { plugin } = await startPlugin(t3, controller => {
			addHost(controller, 1);
			addInstance(controller, 10);
		});
		const all = await plugin.handleServerSubscription(subscription(0));
		t3.equal(all.updates.length, 1);
		const none = await plugin.handleServerSubscription(subscription(Date.now() + 1000));
		t3.equal(none, null);
		t3.equal((await plugin.handleServerListRequest()).length, 1);
	});

	t2.end();
});

t.test("ServerRecord round trips through json", async t2 => {
	const record = new messages.ServerRecord(
		1, "a", "b", "c", "d", "e", true, "Base", "2.1.14", 3, "running", "localhost:1", 5, true,
	);
	t2.same(messages.ServerRecord.fromJSON(record.toJSON()), record);
	t2.ok(record.sameAs(messages.ServerRecord.fromJSON(record.toJSON())));
});
