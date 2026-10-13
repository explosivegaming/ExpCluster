import type { ControllerPluginContext } from "@clusterio/controller";
import * as lib from "@clusterio/lib";
import * as messages from "./messages.js";
import * as path from "node:path";

export default async function (context: ControllerPluginContext) {
	const { controller, logger, plugin } = context;
	const databaseDirectory = controller.config.get("controller.database_directory");
	const reports = new lib.SubscribableDatastore(
		...await new lib.JsonIdDatastoreProvider(
			path.join(databaseDirectory, "exp_reports", "reports.json"),
			messages.ReportRecord.fromJSON.bind(messages.ReportRecord),
		).bootstrap()
	);

	/** Every report, or only those against one player. */
	function listReports(playerName?: string) {
		const all = [...reports.values()];
		return playerName === undefined ? all : all.filter(report => report.playerName === playerName);
	}

	/** Post a new report to the configured webhooks, failures are logged rather than failing the report. */
	function sendWebhooks(report: messages.ReportRecord) {
		const discordUrl = controller.config.get("exp_reports.discord_webhook_url");
		if (discordUrl) {
			postWebhook(discordUrl, {
				embeds: [{
					title: "Player reported",
					color: 0xffcc00,
					timestamp: new Date(report.updatedAtMs).toISOString(),
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

	controller.subscriptions.handle(messages.ReportUpdatedEvent, async request => {
		const updates = [...reports.values()].filter(report => report.updatedAtMs > request.lastRequestTimeMs);
		return updates.length ? new messages.ReportUpdatedEvent(updates) : null;
	});

	// Reports are immutable, so any update which is not a deletion is a new report
	reports.on("update", updates => {
		controller.subscriptions.broadcast(new messages.ReportUpdatedEvent(updates));
		for (const report of updates) {
			if (!report.isDeleted) {
				sendWebhooks(report);
			}
		}
	});

	controller.handle(messages.ReportListRequest, async (request: messages.ReportListRequest) => (
		listReports(request.playerName)
	));

	controller.handle(messages.ReportGetRequest, async (request: messages.ReportGetRequest) => {
		const report = reports.get(request.id);
		if (!report) {
			throw new lib.RequestError(`Report with ID ${request.id} does not exist`);
		}
		return report;
	});

	controller.handle(messages.ReportCreateRequest, async (request: messages.ReportCreateRequest, src: lib.Address) => {
		let byPlayerName = request.byPlayerName;
		let instanceName = "";
		if (src.type === lib.Address.control) {
			byPlayerName = controller.wsServer.controlConnections.get(src.id)!.user.name;
		} else {
			const instance = controller.instances.get(src.id);
			instanceName = instance ? instance.config.get("instance.name") : String(src.id);
		}

		if (!byPlayerName) {
			throw new lib.RequestError("A report needs the name of the player making it");
		}
		if (!request.reason.trim()) {
			throw new lib.RequestError("A report needs a reason");
		}
		if (listReports(request.playerName).some(report => report.byPlayerName === byPlayerName)) {
			throw new lib.RequestError(`${byPlayerName} has already reported ${request.playerName}`);
		}

		let id = Math.random() * 2 ** 31 | 0;
		while (reports.has(id)) {
			id = Math.random() * 2 ** 31 | 0;
		}

		const report = new messages.ReportRecord(id, request.playerName, byPlayerName, request.reason.trim(), instanceName);
		reports.set(report);
		return report;
	});

	controller.handle(messages.ReportDeleteRequest, async (request: messages.ReportDeleteRequest) => {
		const report = reports.getMutable(request.id);
		if (!report) {
			throw new lib.RequestError(`Report with ID ${request.id} does not exist`);
		}
		reports.delete(report);
	});

	controller.hooks.shutdown.attach(plugin.name, async () => {
		await reports.save();
	});
}
