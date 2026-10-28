import type { ControllerPluginContext, InstanceRecord } from "@clusterio/controller";
import * as lib from "@clusterio/lib";
import * as messages from "./messages.js";
import * as path from "node:path";

/** Reports saved before the read state was added used updated_at_ms as the creation time. */
function migrateReports(rawJson: unknown[]) {
	return rawJson.map((report: any) => ({ created_at_ms: report.updated_at_ms ?? 0, ...report }));
}

export default async function (context: ControllerPluginContext) {
	const { controller, logger, plugin } = context;
	const databaseDirectory = controller.config.get("controller.database_directory");
	const reports = await lib.SubscribableDatastore.fromProvider(new lib.JsonIdDatastoreProvider(
		path.join(databaseDirectory, "exp_reports", "reports.json"),
		messages.ReportRecord.fromJSON.bind(messages.ReportRecord),
		migrateReports,
	));
	const watchList = await lib.SubscribableDatastore.fromProvider(new lib.JsonIdDatastoreProvider(
		path.join(databaseDirectory, "exp_reports", "watch_list.json"),
		messages.WatchListRecord.fromJSON.bind(messages.WatchListRecord),
	));

	/** Every report, or only those against one player. */
	function listReports(playerName?: string) {
		const all = [...reports.values()];
		return playerName === undefined ? all : all.filter(report => report.playerName === playerName);
	}

	/** Name of the user behind a control connection. */
	function controlUserName(src: lib.Address) {
		return controller.wsServer.controlConnections.get(src.id)!.user.name;
	}

	/** Post a new report to the configured webhooks, failures are logged rather than failing the report. */
	function sendReportWebhooks(report: messages.ReportRecord) {
		const discordUrl = controller.config.get("exp_reports.discord_webhook_url");
		if (discordUrl) {
			postWebhook(discordUrl, {
				embeds: [{
					title: "Player reported",
					color: 0xffcc00,
					timestamp: new Date(report.createdAtMs).toISOString(),
					fields: [
						{ name: "Player", value: report.playerName, inline: true },
						{ name: "By", value: report.byPlayerName, inline: true },
						{ name: "Instance", value: report.instanceName || "Web UI", inline: true },
						{ name: "Reason", value: report.reason },
					],
				}],
			});
		}

		const jsonUrl = controller.config.get("exp_reports.json_webhook_url");
		if (jsonUrl) {
			postWebhook(jsonUrl, { type: "report_created", report: report.toJSON() });
		}
	}

	/** Post a watched player joining to the configured webhooks. */
	function sendJoinWebhooks(event: messages.WatchedPlayerJoinedEvent) {
		const discordUrl = controller.config.get("exp_reports.discord_webhook_url");
		if (discordUrl) {
			const entry = event.watchListEntry;
			postWebhook(discordUrl, {
				embeds: [{
					title: "Watched player joined",
					color: 0xff6600,
					timestamp: new Date().toISOString(),
					fields: [
						{ name: "Player", value: event.playerName, inline: true },
						{ name: "Instance", value: event.instanceName, inline: true },
						...entry ? [{ name: `Watch list, added by ${entry.byPlayerName}`, value: entry.reason }] : [],
						...event.unreadReports.slice(0, 3).map(report => ({
							name: `Unread report by ${report.byPlayerName}`, value: report.reason,
						})),
					],
					...event.unreadReports.length > 3 ? {
						footer: { text: `+${event.unreadReports.length - 3} more unread reports` },
					} : {},
				}],
			});
		}

		const jsonUrl = controller.config.get("exp_reports.json_webhook_url");
		if (jsonUrl) {
			postWebhook(jsonUrl, { type: "watched_player_joined", ...event.toJSON() });
		}
	}

	async function postWebhook(url: string, body: unknown) {
		try {
			const response = await fetch(url, {
				method: "POST",
				headers: { "Content-Type": "application/json" },
				body: JSON.stringify(body),
			});
			if (!response.ok) {
				logger.warn(`Webhook ${url} responded with ${response.status}`);
			}
		} catch (err: any) {
			logger.warn(`Webhook ${url} failed: ${err.message}`);
		}
	}

	/** Tell the instances and the webhooks when a watched player joins, names are case insensitive. */
	function playerJoined(instance: InstanceRecord, playerName: string) {
		const key = playerName.toLowerCase();
		const watchListEntry = watchList.get(key);
		const unreadReports = controller.config.get("exp_reports.watch_unread_reports")
			? [...reports.values()]
				.filter(report => !report.isRead && report.playerName.toLowerCase() === key)
				.sort((a, b) => b.createdAtMs - a.createdAtMs)
			: [];
		if (!watchListEntry && !unreadReports.length) {
			return;
		}

		const event = new messages.WatchedPlayerJoinedEvent(
			playerName, instance.config.get("instance.name"), watchListEntry, unreadReports,
		);
		if (controller.config.get("exp_reports.announce_to_all_instances")) {
			controller.sendTo("allInstances", event);
		} else {
			controller.sendTo({ instanceId: instance.id }, event);
		}
		sendJoinWebhooks(event);
	}

	controller.subscriptions.handle(messages.ReportUpdatedEvent, async request => {
		const updates = [...reports.values()].filter(report => report.updatedAtMs > request.lastRequestTimeMs);
		return updates.length ? new messages.ReportUpdatedEvent(updates) : null;
	});

	controller.subscriptions.handle(messages.WatchListUpdatedEvent, async request => {
		const updates = [...watchList.values()].filter(entry => entry.updatedAtMs > request.lastRequestTimeMs);
		return updates.length ? new messages.WatchListUpdatedEvent(updates) : null;
	});

	reports.on("update", updates => {
		controller.subscriptions.broadcast(new messages.ReportUpdatedEvent(updates));
	});

	watchList.on("update", updates => {
		controller.subscriptions.broadcast(new messages.WatchListUpdatedEvent(updates));
	});

	controller.hooks.playerEvent.attach(plugin.name, async (instance, event) => {
		if (event.type === "join") {
			playerJoined(instance, event.name);
		}
	});

	controller.handle(messages.ReportListRequest, async (request: messages.ReportListRequest) => (
		listReports(request.playerName)
	));

	controller.handle(messages.ReportGetRequest, async (request: messages.ReportGetRequest) => {
		const report = reports.get(request.id);
		if (!report) {
			throw new lib.NotFoundError(`Report with ID ${request.id} does not exist`);
		}
		return report;
	});

	controller.handle(messages.ReportCreateRequest, async (request: messages.ReportCreateRequest, src: lib.Address) => {
		let byPlayerName = request.byPlayerName;
		let instanceName = "";
		if (src.type === lib.Address.control) {
			byPlayerName = controlUserName(src);
		} else {
			const instance = controller.instances.get(src.id);
			instanceName = instance ? instance.config.get("instance.name") : String(src.id);
		}

		if (!byPlayerName) {
			throw new lib.ValidationError("A report needs the name of the player making it");
		}
		if (!request.reason.trim()) {
			throw new lib.ValidationError("A report needs a reason");
		}
		if (listReports(request.playerName).some(report => report.byPlayerName === byPlayerName)) {
			throw new lib.ConflictError(`${byPlayerName} has already reported ${request.playerName}`);
		}

		let id = Math.random() * 2 ** 31 | 0;
		while (reports.has(id)) {
			id = Math.random() * 2 ** 31 | 0;
		}

		const report = new messages.ReportRecord(
			id, request.playerName, byPlayerName, request.reason.trim(), instanceName, Date.now(),
		);
		reports.set(report);
		sendReportWebhooks(report);
		return report;
	});

	controller.handle(messages.ReportDeleteRequest, async (request: messages.ReportDeleteRequest) => {
		const report = reports.getMutable(request.id);
		if (!report) {
			throw new lib.NotFoundError(`Report with ID ${request.id} does not exist`);
		}
		reports.delete(report);
	});

	controller.handle(messages.ReportSetReadRequest, async (request: messages.ReportSetReadRequest) => {
		const report = reports.getMutable(request.id);
		if (!report) {
			throw new lib.NotFoundError(`Report with ID ${request.id} does not exist`);
		}
		report.isRead = request.isRead;
		reports.set(report);
	});

	controller.handle(messages.WatchListAddRequest, async (request: messages.WatchListAddRequest, src: lib.Address) => {
		const playerName = request.playerName.trim();
		if (!playerName) {
			throw new lib.ValidationError("A player name is required");
		}
		if (!request.reason.trim()) {
			throw new lib.ValidationError("A reason is required");
		}
		const existing = watchList.get(playerName.toLowerCase());
		if (existing) {
			throw new lib.ConflictError(`${existing.playerName} is already on the watch list`);
		}

		const entry = new messages.WatchListRecord(playerName, request.reason.trim(), controlUserName(src), Date.now());
		watchList.set(entry);
		return entry;
	});

	controller.handle(messages.WatchListRemoveRequest, async (request: messages.WatchListRemoveRequest) => {
		const entry = watchList.getMutable(request.playerName.toLowerCase());
		if (!entry) {
			throw new lib.NotFoundError(`${request.playerName} is not on the watch list`);
		}
		watchList.delete(entry);
	});

	controller.hooks.save.attach(plugin.name, async () => {
		await reports.save();
		await watchList.save();
	});
}
