import type { Instance, InstancePluginContext } from "@clusterio/host";
import type * as lib from "@clusterio/lib";
import * as messages from "./messages.js";

/** Sent by the lua side when a player uses a link code. */
export type IpcLink = {
	player_name: string,
	code: string,
};

/** Sent by the lua side when a player unlinks their Discord account, or asks which one they are linked to. */
export type IpcPlayer = {
	player_name: string,
};

/** Bridges the lua side and the controller, the answer is printed to the player once it arrives. */
export class InstancePlugin {
	private constructor(
		public instance: Instance,
		public logger: lib.Logger,
		public name: string,
	) {}

	static async fromContext(context: InstancePluginContext) {
		const instance = context.instance;
		const plugin = new InstancePlugin(instance, context.logger, context.plugin.name);

		instance.server.handle("exp_discord:link", plugin.handleLinkIPC.bind(plugin));
		instance.server.handle("exp_discord:unlink", plugin.handleUnlinkIPC.bind(plugin));
		instance.server.handle("exp_discord:get", plugin.handleGetIPC.bind(plugin));
		return plugin;
	}

	async handleLinkIPC(event: IpcLink) {
		try {
			const discord = await this.instance.sendTo("controller", new messages.DiscordLinkRequest(
				event.player_name, event.code,
			));
			await this.luaSend("receive_linked", { player_name: event.player_name, discord_name: discord!.name });
		} catch (err: any) {
			await this.luaSend("receive_error", { player_name: event.player_name, message: err.message });
		}
	}

	async handleUnlinkIPC(event: IpcPlayer) {
		try {
			const discord = await this.instance.sendTo("controller", new messages.DiscordUnlinkRequest(event.player_name));
			await this.luaSend("receive_unlinked", { player_name: event.player_name, discord_name: discord?.name });
		} catch (err: any) {
			await this.luaSend("receive_error", { player_name: event.player_name, message: err.message });
		}
	}

	async handleGetIPC(event: IpcPlayer) {
		try {
			const discord = await this.instance.sendTo("controller", new messages.DiscordLinkGetRequest(event.player_name));
			await this.luaSend("receive_get", { player_name: event.player_name, discord_name: discord?.name });
		} catch (err: any) {
			await this.luaSend("receive_error", { player_name: event.player_name, message: err.message });
		}
	}

	/** Hand an answer to lua, unless the instance stopped while it was being fetched. */
	async luaSend(receiver: string, json: any) {
		if (this.instance.status !== "running") {
			return;
		}
		// Discord names can contain anything, so pick a long bracket level the json does not close
		const text = JSON.stringify(json);
		let level = "=";
		while (text.includes(`]${level}]`)) {
			level += "=";
		}
		await this.instance.sendRcon(
			`/sc exp_discord.${receiver}(helpers.json_to_table[${level}[${text}]${level}])`, true
		);
	}
}

export default async function (context: InstancePluginContext) {
	await InstancePlugin.fromContext(context);
}
