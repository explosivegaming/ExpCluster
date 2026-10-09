import type { Instance, InstancePluginContext } from "@clusterio/host";
import * as lib from "@clusterio/lib";
import * as messages from "./messages.js";

/** Sends the server list to the lua side, see module/control.lua. */
export class InstancePlugin {
	/** Rcon is up and the lua side can take updates */
	started = false;

	private constructor(
		public instance: Instance,
		public logger: lib.Logger,
		public name: string,
	) {}

	static async fromContext(context: InstancePluginContext) {
		const instance = context.instance;
		const plugin = new InstancePlugin(instance, context.logger, context.plugin.name);

		instance.handle(messages.ServerUpdatesEvent, plugin.handleServerUpdatesEvent.bind(plugin));
		instance.hooks.start.attach(plugin.name, plugin.onStart.bind(plugin));
		instance.hooks.exit.attach(plugin.name, plugin.onExit.bind(plugin));
		instance.hooks.controllerConnectionEvent.attach(plugin.name, plugin.onControllerConnectionEvent.bind(plugin));
		return plugin;
	}

	async onStart() {
		this.started = true;
		await this.syncServers();
	}

	async onExit() {
		this.started = false;
	}

	/** A new session means the controller restarted and forgot the subscription. */
	async onControllerConnectionEvent(event: "connect" | "drop" | "resume" | "close") {
		if (event === "connect" && this.started) {
			await this.syncServers();
		}
	}

	/** Subscribe, then replace the whole list */
	async syncServers() {
		await this.instance.sendTo("controller", new lib.SubscriptionRequest(
			`exp_server_list:${messages.ServerUpdatesEvent.name}`, "subscribe", Date.now(),
		));
		const servers = await this.instance.sendTo("controller", new messages.ServerListRequest());
		await this.luaSendServers(servers, true);
	}

	async handleServerUpdatesEvent(event: messages.ServerUpdatesEvent) {
		if (this.started) {
			await this.luaSendServers(event.updates, false);
		}
	}

	async luaSendServers(servers: messages.ServerRecord[], replace: boolean) {
		const json = JSON.stringify({
			current_id: this.instance.id,
			replace,
			servers: servers.map(server => server.toJSON()),
		});
		// Pick a long bracket the json does not contain
		let level = "=";
		while (json.includes(`]${level}]`)) {
			level += "=";
		}
		await this.instance.sendRcon(
			`/sc exp_server_list.receive_update(helpers.json_to_table[${level}[${json}]${level}])`, true,
		);
	}
}

export default async function (context: InstancePluginContext) {
	await InstancePlugin.fromContext(context);
}
