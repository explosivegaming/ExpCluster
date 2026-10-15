import type { InstancePluginContext } from "@clusterio/host";
import * as messages from "./messages.js";

/** Sent by the lua side with what each player gained since the last update. */
export type IpcStatisticsUpdate = {
	players: { name: string, stats: Record<string, number> }[],
};

/**
 * Forwards the statistics gained in game to the controller, and hands the
 * totals of a player to lua when they join, see module/control.lua.
 */
export default async function (context: InstancePluginContext) {
	const { instance, plugin, logger } = context;

	async function luaCall(code: string) {
		await instance.sendRcon(`/sc ${code}`, true);
	}

	async function luaSendTotals(record: messages.PlayerStatistics) {
		const json = JSON.stringify({ name: record.id, stats: record.stats });
		// Pick a long bracket the json does not contain
		let level = "=";
		while (json.includes(`]${level}]`)) {
			level += "=";
		}
		await luaCall(`exp_player_statistics.receive_totals(helpers.json_to_table[${level}[${json}]${level}])`);
	}

	instance.server.handle("exp_player_statistics:update", async (event: IpcStatisticsUpdate) => {
		instance.sendTo("controller", new messages.StatisticsUpdateEvent(
			event.players.map(player => new messages.StatisticsDelta(player.name, player.stats)),
		));
	});

	instance.hooks.playerEvent.attach(plugin.name, async event => {
		if (event.type !== "join") {
			return;
		}
		try {
			const record = await instance.sendTo("controller", new messages.StatisticsGetRequest(event.name));
			if (instance.status === "running") {
				await luaSendTotals(record);
			}
		} catch (err: any) {
			logger.warn(`Failed to send the statistics of ${event.name}: ${err.message}`);
		}
	});

	// Anything still unsent at start came from a save made before the last
	// update was sent, so it is dropped rather than counted twice
	instance.hooks.start.attach(plugin.name, async () => {
		await luaCall("exp_player_statistics.discard_unsent()");
	});

	instance.hooks.stop.attach(plugin.name, async () => {
		await luaCall("exp_player_statistics.send_all()");
	});
}
