import type { ControllerPluginContext, InstanceRecord } from "@clusterio/controller";
import * as lib from "@clusterio/lib";
import * as messages from "./messages.js";

/** Instance config fields which change the record */
const recordFields = new Set([
	"instance.name",
	"instance.assigned_host",
	"factorio.mod_pack_id",
	"factorio.settings",
	"exp_server_list.display_name",
	"exp_server_list.description",
	"exp_server_list.welcome",
	"exp_server_list.reset_time",
	"exp_server_list.hidden",
	"exp_server_list.always_on_top",
]);

/** Controller config fields which change every record */
const controllerFields = new Set([
	"controller.default_mod_pack_id",
	"exp_server_list.welcome",
]);

/**
 * Keeps a record for every instance and broadcasts the ones which change.
 *
 * Records are rebuilt from controller state on start, nothing is saved.
 */
export default async function (context: ControllerPluginContext) {
	const { controller, plugin } = context;
	const servers = new lib.SubscribableDatastore<messages.ServerRecord>();

	function modPackName(instance: InstanceRecord) {
		const id = instance.config.get("factorio.mod_pack_id")
			?? controller.config.get("controller.default_mod_pack_id");
		return id !== null && id !== undefined ? controller.modPacks.get(id)?.name ?? "" : "";
	}

	function playerCount(instanceId: number) {
		let count = 0;
		for (const user of controller.users.records.values()) {
			if (user.instances.has(instanceId)) {
				count += 1;
			}
		}
		return count;
	}

	/** Same as the address the web ui shows for the instance */
	function address(instance: InstanceRecord) {
		const hostId = instance.config.get("instance.assigned_host");
		const publicAddress = hostId !== null ? controller.hosts.get(hostId)?.publicAddress : undefined;
		if (!publicAddress) {
			return "";
		}
		return instance.gamePort === undefined ? publicAddress : `${publicAddress}:${instance.gamePort}`;
	}

	function buildRecord(instance: InstanceRecord) {
		const config = instance.config;
		const settings = config.get("factorio.settings");
		const settingString = (name: string) => (typeof settings[name] === "string" ? settings[name] : "");
		return new messages.ServerRecord(
			instance.id,
			config.get("instance.name"),
			config.get("exp_server_list.display_name") || config.get("instance.name"),
			config.get("exp_server_list.description") || settingString("description"),
			config.get("exp_server_list.welcome") || controller.config.get("exp_server_list.welcome"),
			config.get("exp_server_list.reset_time"),
			config.get("exp_server_list.hidden"),
			config.get("exp_server_list.always_on_top"),
			settingString("game_password") !== "",
			modPackName(instance),
			instance.factorioVersion === "latest" ? "" : instance.factorioVersion ?? "",
			instance.status === "running" ? playerCount(instance.id) : 0,
			instance.status,
			address(instance),
		);
	}

	/** Rebuild the records of the instances, and store the ones which changed in one update */
	function refresh(instances: Iterable<InstanceRecord>) {
		const changed: messages.ServerRecord[] = [];
		const deleted: messages.ServerRecord[] = [];
		for (const instance of instances) {
			const existing = servers.get(instance.id);
			if (instance.isDeleted) {
				if (existing) {
					deleted.push(existing);
				}
				continue;
			}

			const record = buildRecord(instance);
			if (!existing || !existing.sameAs(record)) {
				changed.push(record);
			}
		}

		if (changed.length) {
			servers.setMany(changed);
		}
		if (deleted.length) {
			servers.deleteMany(deleted);
		}
	}

	const refreshAll = () => refresh(controller.instances.values());

	refreshAll();
	servers.on("update", updates => {
		controller.subscriptions.broadcast(new messages.ServerUpdatesEvent(updates));
	});

	// The public address of a host arrives after it connects
	controller.hosts.on("update", hosts => {
		const hostIds = new Set(hosts.map(host => host.id));
		refresh([...controller.instances.values()].filter(instance => {
			const hostId = instance.config.get("instance.assigned_host");
			return hostId !== null && hostIds.has(hostId);
		}));
	});

	controller.subscriptions.handle(messages.ServerUpdatesEvent, async request => {
		const updates = [...servers.values()].filter(server => server.updatedAtMs > request.lastRequestTimeMs);
		return updates.length ? new messages.ServerUpdatesEvent(updates) : null;
	});
	controller.handle(messages.ServerListRequest, async () => [...servers.values()]);

	const hooks = controller.hooks;
	hooks.instanceStatusChanged.attach(plugin.name, async instance => {
		refresh([instance]);
	});
	hooks.instanceConfigFieldChanged.attach(plugin.name, async (instance, field) => {
		if (recordFields.has(field)) {
			refresh([instance]);
		}
	});
	hooks.controllerConfigFieldChanged.attach(plugin.name, async field => {
		if (controllerFields.has(field)) {
			refreshAll();
		}
	});
	hooks.playerEvent.attach(plugin.name, async (instance, event) => {
		if (event.type === "join" || event.type === "leave") {
			refresh([instance]);
		}
	});
	hooks.modPacksUpdated.attach(plugin.name, async () => {
		refreshAll();
	});
}
