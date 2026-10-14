import type { InstancePluginContext } from "@clusterio/host";
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
export default async function (context: InstancePluginContext) {
	const { instance } = context;

	/** Hand an answer to lua, unless the instance stopped while it was being fetched. */
	async function luaSend(receiver: string, json: any) {
		if (instance.status !== "running") {
			return;
		}
		// Discord names can contain anything, so pick a long bracket level the json does not close
		const text = JSON.stringify(json);
		let level = "=";
		while (text.includes(`]${level}]`)) {
			level += "=";
		}
		await instance.sendRcon(
			`/sc exp_discord_auth.${receiver}(helpers.json_to_table[${level}[${text}]${level}])`, true
		);
	}

	instance.server.handle("exp_discord_auth:link", async (event: IpcLink) => {
		try {
			const discord = await instance.sendTo("controller", new messages.DiscordLinkRequest(
				event.player_name, event.code,
			));
			await luaSend("receive_linked", { player_name: event.player_name, discord_name: discord!.name });
		} catch (err: any) {
			await luaSend("receive_error", { player_name: event.player_name, message: err.message });
		}
	});

	instance.server.handle("exp_discord_auth:unlink", async (event: IpcPlayer) => {
		try {
			const status = await instance.sendTo("controller", new messages.DiscordUnlinkRequest(event.player_name));
			await luaSend("receive_unlinked", {
				player_name: event.player_name, discord_name: status.link?.name, url: status.url,
			});
		} catch (err: any) {
			await luaSend("receive_error", { player_name: event.player_name, message: err.message });
		}
	});

	instance.server.handle("exp_discord_auth:get", async (event: IpcPlayer) => {
		try {
			const status = await instance.sendTo("controller", new messages.DiscordLinkGetRequest(event.player_name));
			await luaSend("receive_get", {
				player_name: event.player_name, discord_name: status.link?.name, url: status.url,
			});
		} catch (err: any) {
			await luaSend("receive_error", { player_name: event.player_name, message: err.message });
		}
	});
}
