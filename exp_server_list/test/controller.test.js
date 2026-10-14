import t from "tap";
import * as lib from "@clusterio/lib";
import { Controller, HostRecord, InstanceRecord } from "@clusterio/controller";
import entrypoint from "../dist/node/controller.js";
import { plugin as pluginDeclaration } from "../dist/node/index.js";
import * as messages from "../dist/node/messages.js";

// The plugin's config fields must be defined before an InstanceConfig can set them
lib.addPluginConfigFields([pluginDeclaration]);
for (const Message of pluginDeclaration.messages) {
	lib.Link.register(Message);
}

const logger = { child: () => logger, info: () => {}, warn: () => {}, error: () => {}, verbose: () => {} };

/** Run the plugin on a real controller, which is side effect free while not started. */
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

	const handlers = new Map();
	controller.handle = (Class, handler) => handlers.set(Class, handler);
	controller.subscriptions.handle = (Class, handler) => handlers.set(Class, handler);

	await entrypoint({ controller, logger, plugin: pluginDeclaration, metrics: undefined });
	const list = async () => handlers.get(messages.ServerListRequest)(new messages.ServerListRequest());
	return {
		controller,
		broadcasts,
		list,
		/** The record of one instance */
		get: async id => (await list()).find(server => server.id === id),
		subscribe: since => handlers.get(messages.ServerUpdatesEvent)(
			new lib.SubscriptionRequest("exp_server_list:ServerUpdatesEvent", "subscribe", since),
		),
	};
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

const join = (controller, name, instanceId) => controller.users.getOrCreateUser(name).notifyJoin(instanceId);

t.test("entrypoint attaches to the controller hooks", async t2 => {
	const { controller } = await startPlugin(t2);
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
});

t.test("builds a record for every instance on start", async t2 => {
	const { get } = await startPlugin(t2, controller => {
		addHost(controller, 1, "example.com");
		addInstance(controller, 10, {
			gamePort: 34197,
			factorioVersion: "2.1.14",
			fields: {
				"exp_server_list.description": "Weekly reset",
				"exp_server_list.hidden": true,
				"exp_server_list.always_on_top": true,
				"factorio.settings": { description: "From the settings", game_password: "secret" },
			},
		});
		addInstance(controller, 11, {
			status: "stopped",
			factorioVersion: "latest",
			fields: {
				"exp_server_list.display_name": "S11",
				"factorio.settings": { description: "From the settings", game_password: "" },
			},
		});
	});

	const server = await get(10);
	t2.equal(server.name, "instance-10");
	t2.equal(server.displayName, "instance-10", "display name falls back to the name");
	t2.equal(server.description, "Weekly reset", "own description wins over the settings");
	t2.equal(server.hidden, true);
	t2.equal(server.alwaysOnTop, true);
	t2.equal(server.hasPassword, true);
	t2.notMatch(JSON.stringify(server.toJSON()), "secret", "the password is not sent");
	t2.equal(server.factorioVersion, "2.1.14");
	t2.equal(server.address, "example.com:34197", "public address of the host and the game port");
	t2.equal(server.status, "running");

	const stopped = await get(11);
	t2.equal(stopped.displayName, "S11");
	t2.equal(stopped.description, "From the settings", "description falls back to the settings");
	t2.equal(stopped.hasPassword, false, "an empty password is no password");
	t2.equal(stopped.factorioVersion, "", "the latest target is not a version");
	t2.equal(stopped.address, "example.com", "host address alone without a game port");
});

t.test("uses the mod pack of the instance or the default", async t2 => {
	const { get, controller } = await startPlugin(t2, c => {
		addHost(c, 1);
		c.modPacks.setMany(lib.ModPack.defaultModPacks.map(pack => lib.ModPack.fromJSON(pack.toJSON())));
		const packs = [...c.modPacks.values()];
		c.config.set("controller.default_mod_pack_id", packs[0].id);
		addInstance(c, 10);
		addInstance(c, 11, { fields: { "factorio.mod_pack_id": packs[1].id } });
	});
	const packs = [...controller.modPacks.values()];
	t2.equal((await get(10)).modPackName, packs[0].name, "the default mod pack");
	t2.equal((await get(11)).modPackName, packs[1].name, "the instance mod pack");
	t2.equal((await get(10)).address, "", "no address while the host has none");
});

t.test("uses the controller welcome when the instance has none", async t2 => {
	const { get, controller, broadcasts } = await startPlugin(t2, c => {
		addHost(c, 1);
		addInstance(c, 10);
		addInstance(c, 11, { fields: { "exp_server_list.welcome": "Own welcome" } });
	});
	t2.equal((await get(10)).welcome, "", "empty when neither is set");

	controller.config.set("exp_server_list.welcome", "Cluster welcome");
	await controller.hooks.controllerConfigFieldChanged.invoke("exp_server_list.welcome", "");
	t2.equal((await get(10)).welcome, "Cluster welcome");
	t2.equal((await get(11)).welcome, "Own welcome", "the instance welcome wins");
	t2.strictSame(broadcasts.at(-1).updates.map(server => server.id), [10], "only changed records are sent");
});

t.test("counts players only while running", async t2 => {
	const { get, controller, broadcasts } = await startPlugin(t2, c => {
		addHost(c, 1);
		addInstance(c, 10);
	});
	const instance = controller.instances.get(10);

	join(controller, "alice", 10);
	join(controller, "bob", 10);
	await controller.hooks.playerEvent.invoke(instance, { type: "join", name: "bob" });
	t2.equal((await get(10)).playerCount, 2);
	t2.equal(broadcasts.at(-1).updates[0].playerCount, 2, "the change is broadcast");

	instance.status = "stopped";
	await controller.hooks.instanceStatusChanged.invoke(instance, "running");
	t2.equal((await get(10)).playerCount, 0, "players left online by a crash are not counted");
});

t.test("follows config, host and status changes", async t2 => {
	const { get, controller, broadcasts } = await startPlugin(t2, c => {
		addHost(c, 1);
		addHost(c, 2);
		addInstance(c, 10, { gamePort: 34197 });
		addInstance(c, 11, { gamePort: 34198 });
		addInstance(c, 12, { hostId: 2 });
	});
	const instance = controller.instances.getMutable(10);

	instance.config.set("instance.name", "Weekly");
	t2.equal((await get(10)).name, "Weekly", "renames are picked up");

	instance.config.set("exp_server_list.welcome", "Hello");
	t2.equal((await get(10)).welcome, "Hello", "plugin fields are picked up");

	instance.config.set("factorio.settings", { game_password: "secret" });
	t2.equal((await get(10)).hasPassword, true, "server settings are picked up");

	addHost(controller, 1, "example.com");
	t2.equal((await get(10)).address, "example.com:34197", "the public address once the host sends it");
	t2.strictSame(
		broadcasts.at(-1).updates.map(server => server.id), [10, 11], "the instances on that host in one update",
	);

	const count = broadcasts.length;
	addHost(controller, 1, "example.com");
	t2.equal(broadcasts.length, count, "nothing is broadcast when nothing changed");

	// What deleteInstance does once the host has deleted it
	controller.instances.records.delete(instance);
	await controller.hooks.instanceStatusChanged.invoke(instance, "running");
	t2.equal(await get(10), undefined, "deleted instances are removed");
	t2.equal(broadcasts.at(-1).updates[0].isDeleted, true, "and broadcast as deleted");
});

t.test("subscriptions get the servers updated since the last request", async t2 => {
	const { subscribe, list } = await startPlugin(t2, controller => {
		addHost(controller, 1);
		addInstance(controller, 10);
	});
	t2.equal((await subscribe(0)).updates.length, 1);
	t2.equal(await subscribe(Date.now() + 1000), null);
	t2.equal((await list()).length, 1);
});

t.test("ServerRecord round trips through json", async t2 => {
	const record = new messages.ServerRecord(
		1, "a", "b", "c", "d", "e", true, true, true, "Base", "2.1.14", 3, "running", "localhost:1", 5, true,
	);
	t2.same(messages.ServerRecord.fromJSON(record.toJSON()), record);
	t2.ok(record.sameAs(messages.ServerRecord.fromJSON(record.toJSON())));
});
