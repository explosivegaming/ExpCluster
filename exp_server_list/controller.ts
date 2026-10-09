import type { Controller, ControllerPluginContext, HostRecord, InstanceRecord } from "@clusterio/controller";
import * as lib from "@clusterio/lib";
import * as messages from "./messages.js";

const loaded = new WeakMap<Controller, ControllerPlugin>();

/** Instance config fields which change the record */
const recordFields = new Set([
	"instance.name",
	"instance.assigned_host",
	"factorio.mod_pack_id",
	"exp_server_list.short_name",
	"exp_server_list.description",
	"exp_server_list.welcome",
	"exp_server_list.reset_time",
	"exp_server_list.hidden",
]);

/**
 * Keeps a record for every instance and broadcasts the ones which change.
 *
 * Records are rebuilt from controller state on start, nothing is saved.
 */
export class ControllerPlugin {
	/** The plugin loaded on a controller, for other plugins to read the list. */
	static get(controller: Controller) {
		return loaded.get(controller);
	}

	private constructor(
		public controller: Controller,
		public logger: lib.Logger,
		public name: string,
		public servers: lib.SubscribableDatastore<messages.ServerRecord>,
	) {}

	static async fromContext(context: ControllerPluginContext) {
		const controller = context.controller;
		const plugin = new ControllerPlugin(
			controller, context.logger, context.plugin.name, new lib.SubscribableDatastore(),
		);
		loaded.set(controller, plugin);

		plugin.refreshAll();
		plugin.servers.on("update", plugin.serversUpdated.bind(plugin));
		controller.hosts.on("update", plugin.hostsUpdated.bind(plugin));

		controller.subscriptions.handle(messages.ServerUpdatesEvent, plugin.handleServerSubscription.bind(plugin));
		controller.handle(messages.ServerListRequest, plugin.handleServerListRequest.bind(plugin));

		const hooks = controller.hooks;
		hooks.instanceStatusChanged.attach(plugin.name, plugin.onInstanceStatusChanged.bind(plugin));
		hooks.instanceConfigFieldChanged.attach(plugin.name, plugin.onInstanceConfigFieldChanged.bind(plugin));
		hooks.controllerConfigFieldChanged.attach(plugin.name, plugin.onControllerConfigFieldChanged.bind(plugin));
		hooks.playerEvent.attach(plugin.name, plugin.onPlayerEvent.bind(plugin));
		hooks.modPacksUpdated.attach(plugin.name, plugin.onModPacksUpdated.bind(plugin));
		return plugin;
	}

	async onInstanceStatusChanged(instance: InstanceRecord) {
		this.refresh(instance);
	}

	async onInstanceConfigFieldChanged(instance: InstanceRecord, field: string) {
		if (recordFields.has(field)) {
			this.refresh(instance);
		}
	}

	async onControllerConfigFieldChanged(field: string) {
		if (field === "controller.default_mod_pack_id") {
			this.refreshAll();
		}
	}

	async onPlayerEvent(instance: InstanceRecord, event: lib.PlayerEvent) {
		if (event.type === "join" || event.type === "leave") {
			this.refresh(instance);
		}
	}

	async onModPacksUpdated() {
		this.refreshAll();
	}

	/** The public address of a host arrives after it connects */
	hostsUpdated(hosts: HostRecord[]) {
		const hostIds = new Set(hosts.map(host => host.id));
		for (const instance of this.controller.instances.values()) {
			const hostId = instance.config.get("instance.assigned_host");
			if (hostId !== null && hostIds.has(hostId)) {
				this.refresh(instance);
			}
		}
	}

	refreshAll() {
		for (const instance of this.controller.instances.values()) {
			this.refresh(instance);
		}
	}

	/** Rebuild the record of an instance, and store it if anything changed */
	refresh(instance: InstanceRecord) {
		const existing = this.servers.get(instance.id);
		if (instance.isDeleted) {
			if (existing) {
				this.servers.delete(existing);
			}
			return;
		}

		const record = this.buildRecord(instance);
		if (!existing || !existing.sameAs(record)) {
			this.servers.set(record);
		}
	}

	buildRecord(instance: InstanceRecord) {
		const config = instance.config;
		const running = instance.status === "running";
		return new messages.ServerRecord(
			instance.id,
			config.get("instance.name"),
			config.get("exp_server_list.short_name") || config.get("instance.name"),
			config.get("exp_server_list.description"),
			config.get("exp_server_list.welcome"),
			config.get("exp_server_list.reset_time"),
			config.get("exp_server_list.hidden"),
			this.modPackName(instance),
			instance.factorioVersion === "latest" ? "" : instance.factorioVersion ?? "",
			running ? this.playerCount(instance.id) : 0,
			instance.status,
			this.address(instance),
		);
	}

	modPackName(instance: InstanceRecord) {
		const id = instance.config.get("factorio.mod_pack_id")
			?? this.controller.config.get("controller.default_mod_pack_id");
		return id !== null && id !== undefined ? this.controller.modPacks.get(id)?.name ?? "" : "";
	}

	playerCount(instanceId: number) {
		let count = 0;
		for (const user of this.controller.users.records.values()) {
			if (user.instances.has(instanceId)) {
				count += 1;
			}
		}
		return count;
	}

	/** Same as the address the web ui shows for the instance */
	address(instance: InstanceRecord) {
		const hostId = instance.config.get("instance.assigned_host");
		const publicAddress = hostId !== null ? this.controller.hosts.get(hostId)?.publicAddress : undefined;
		if (!publicAddress) {
			return "";
		}
		return instance.gamePort === undefined ? publicAddress : `${publicAddress}:${instance.gamePort}`;
	}

	serversUpdated(updates: messages.ServerRecord[]) {
		this.controller.subscriptions.broadcast(new messages.ServerUpdatesEvent(updates));
	}

	async handleServerSubscription(request: lib.SubscriptionRequest) {
		const updates = [...this.servers.values()].filter(server => server.updatedAtMs > request.lastRequestTimeMs);
		return updates.length ? new messages.ServerUpdatesEvent(updates) : null;
	}

	async handleServerListRequest() {
		return [...this.servers.values()];
	}
}

export default async function (context: ControllerPluginContext) {
	await ControllerPlugin.fromContext(context);
}
