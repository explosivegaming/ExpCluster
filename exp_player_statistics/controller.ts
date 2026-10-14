import type { ControllerPluginContext } from "@clusterio/controller";
import * as lib from "@clusterio/lib";
import * as messages from "./messages.js";
import * as path from "node:path";

/** Keeps the statistics totals of every player, instances send what was gained since their last update. */
export default async function (context: ControllerPluginContext) {
	const { controller, plugin } = context;
	const databaseDirectory = controller.config.get("controller.database_directory");
	const players = new lib.SubscribableDatastore(
		...await new lib.JsonIdDatastoreProvider(
			path.join(databaseDirectory, "exp_player_statistics", "players.json"),
			messages.PlayerStatistics.fromJSON.bind(messages.PlayerStatistics),
		).bootstrap()
	);

	function addDeltas(deltas: messages.StatisticsDelta[]) {
		const changed = new Map<string, messages.PlayerStatistics>();
		for (const delta of deltas) {
			const record = changed.get(delta.name)
				?? players.getMutable(delta.name)
				?? new messages.PlayerStatistics(delta.name);
			for (const [name, value] of Object.entries(delta.stats)) {
				if (Number.isFinite(value) && value !== 0) {
					record.stats[name] = (record.stats[name] ?? 0) + value;
				}
			}
			changed.set(record.id, record);
		}
		if (changed.size) {
			players.setMany([...changed.values()]);
		}
	}

	players.on("update", updates => {
		controller.subscriptions.broadcast(new messages.PlayerStatisticsUpdatedEvent(updates));
	});

	controller.subscriptions.handle(messages.PlayerStatisticsUpdatedEvent, async request => {
		const updates = [...players.values()].filter(player => player.updatedAtMs > request.lastRequestTimeMs);
		return updates.length ? new messages.PlayerStatisticsUpdatedEvent(updates) : null;
	});

	controller.handle(messages.StatisticsUpdateEvent, async (event: messages.StatisticsUpdateEvent) => {
		addDeltas(event.deltas);
	});

	controller.handle(messages.StatisticsGetRequest, async (request: messages.StatisticsGetRequest) => {
		const record = players.get(request.name);
		return new messages.PlayerStatistics(request.name, {
			...record?.stats,
			...messages.userStatistics(controller.users.getByName(request.name)),
		}, record?.updatedAtMs);
	});

	controller.handle(messages.StatisticsListRequest, async () => [...players.values()]);

	controller.hooks.save.attach(plugin.name, async () => {
		await players.save();
	});
	controller.hooks.shutdown.attach(plugin.name, async () => {
		await players.save();
	});
}
