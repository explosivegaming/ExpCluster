import type { InstancePluginContext } from "@clusterio/host";
import * as lib from "@clusterio/lib";
import * as messages from "./messages.js";

/**
 * Sends the server list to the lua side, see module/control.lua.
 *
 * The subscription is made by the start hook once rcon is up, so updates
 * only arrive while the game can take them.
 */
export default async function (context: InstancePluginContext) {
	const { instance, plugin } = context;

	async function luaSendServers(servers: messages.ServerRecord[], replace: boolean) {
		const json = JSON.stringify({
			current_id: instance.id,
			replace,
			servers: servers.map(server => server.toJSON()),
		});
		// Pick a long bracket the json does not contain
		let level = "=";
		while (json.includes(`]${level}]`)) {
			level += "=";
		}
		await instance.sendRcon(
			`/sc exp_server_list.receive_update(helpers.json_to_table[${level}[${json}]${level}])`, true,
		);
	}

	/** Subscribe, then replace the whole list */
	async function syncServers() {
		await instance.sendTo("controller", new lib.SubscriptionRequest(
			`exp_server_list:${messages.ServerUpdatesEvent.name}`, "subscribe", Date.now(),
		));
		const servers = await instance.sendTo("controller", new messages.ServerListRequest());
		await luaSendServers(servers, true);
	}

	instance.handle(messages.ServerUpdatesEvent, async event => {
		if (instance.status === "starting" || instance.status === "running") {
			await luaSendServers(event.updates, false);
		}
	});

	instance.hooks.start.attach(plugin.name, syncServers);

	// A new session means the controller restarted and forgot the subscription
	instance.hooks.controllerConnectionEvent.attach(plugin.name, async event => {
		if (event === "connect" && instance.status === "running") {
			await syncServers();
		}
	});
}
