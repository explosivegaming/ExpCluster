import type { Controller, ControllerPluginContext } from "@clusterio/controller";
import * as lib from "@clusterio/lib";
import * as messages from "./messages.js";
import * as path from "node:path";

export class ControllerPlugin {
	private constructor(
		public controller: Controller,
		public logger: lib.Logger,
		public name: string,
		public reports: lib.SubscribableDatastore<messages.ReportRecord>,
	) {}

	static async fromContext(context: ControllerPluginContext) {
		const controller = context.controller;
		const databaseDirectory = controller.config.get("controller.database_directory");

		const reports = new lib.SubscribableDatastore(
			...await new lib.JsonIdDatastoreProvider(
				path.join(databaseDirectory, "exp_reports", "reports.json"),
				messages.ReportRecord.fromJSON.bind(messages.ReportRecord),
			).bootstrap()
		);

		const plugin = new ControllerPlugin(controller, context.logger, context.plugin.name, reports);

		controller.subscriptions.handle(messages.ReportUpdatedEvent, plugin.handleReportSubscription.bind(plugin));
		reports.on("update", plugin.reportsUpdated.bind(plugin));

		controller.handle(messages.ReportListRequest, plugin.handleReportListRequest.bind(plugin));
		controller.handle(messages.ReportGetRequest, plugin.handleReportGetRequest.bind(plugin));
		controller.handle(messages.ReportCreateRequest, plugin.handleReportCreateRequest.bind(plugin));
		controller.handle(messages.ReportDeleteRequest, plugin.handleReportDeleteRequest.bind(plugin));

		controller.hooks.shutdown.attach(plugin.name, plugin.onShutdown.bind(plugin));
		return plugin;
	}

	async onShutdown() {
		await this.reports.save();
	}

	/** Reports are immutable, so any update which is not a deletion is a new report. */
	reportsUpdated(reports: messages.ReportRecord[]) {
		this.controller.subscriptions.broadcast(new messages.ReportUpdatedEvent(reports));

		for (const report of reports) {
			if (!report.isDeleted) {
				this.sendWebhooks(report);
			}
		}
	}

	async handleReportSubscription(request: lib.SubscriptionRequest) {
		const reports = [...this.reports.values()].filter(report => report.updatedAtMs > request.lastRequestTimeMs);
		return reports.length ? new messages.ReportUpdatedEvent(reports) : null;
	}

	/** Every report, or only those against one player. */
	listReports(playerName?: string) {
		const reports = [...this.reports.values()];
		return playerName === undefined ? reports : reports.filter(report => report.playerName === playerName);
	}

	async handleReportListRequest(request: messages.ReportListRequest) {
		return this.listReports(request.playerName);
	}

	async handleReportGetRequest(request: messages.ReportGetRequest) {
		const report = this.reports.get(request.id);
		if (!report) {
			throw new lib.RequestError(`Report with ID ${request.id} does not exist`);
		}
		return report;
	}

	async handleReportCreateRequest(request: messages.ReportCreateRequest, src: lib.Address) {
		let byPlayerName = request.byPlayerName;
		let instanceName = "";
		if (src.type === lib.Address.control) {
			byPlayerName = this.controller.wsServer.controlConnections.get(src.id)!.user.name;
		} else {
			const instance = this.controller.instances.get(src.id);
			instanceName = instance ? instance.config.get("instance.name") : String(src.id);
		}

		if (!byPlayerName) {
			throw new lib.RequestError("A report needs the name of the player making it");
		}
		if (!request.reason.trim()) {
			throw new lib.RequestError("A report needs a reason");
		}
		if (this.listReports(request.playerName).some(report => report.byPlayerName === byPlayerName)) {
			throw new lib.RequestError(`${byPlayerName} has already reported ${request.playerName}`);
		}

		let id = Math.random() * 2 ** 31 | 0;
		while (this.reports.has(id)) {
			id = Math.random() * 2 ** 31 | 0;
		}

		const report = new messages.ReportRecord(id, request.playerName, byPlayerName, request.reason.trim(), instanceName);
		this.reports.set(report);
		return report;
	}

	async handleReportDeleteRequest(request: messages.ReportDeleteRequest) {
		const report = this.reports.getMutable(request.id);
		if (!report) {
			throw new lib.RequestError(`Report with ID ${request.id} does not exist`);
		}
		this.reports.delete(report);
	}

	/** Post a new report to the configured webhooks, failures are logged rather than failing the report. */
	sendWebhooks(report: messages.ReportRecord) {
		const discordUrl = this.controller.config.get("exp_reports.discord_webhook_url");
		if (discordUrl) {
			this.postWebhook(discordUrl, {
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

		const jsonUrl = this.controller.config.get("exp_reports.json_webhook_url");
		if (jsonUrl) {
			this.postWebhook(jsonUrl, { type: "report_created", report: report.toJSON() });
		}
	}

	async postWebhook(url: string, body: unknown) {
		try {
			const response = await fetch(url, {
				method: "POST",
				headers: { "Content-Type": "application/json" },
				body: JSON.stringify(body),
			});
			if (!response.ok) {
				this.logger.warn(`Webhook ${url} responded with ${response.status}`);
			}
		} catch (err: any) {
			this.logger.warn(`Webhook ${url} failed: ${err.message}`);
		}
	}
}

export default async function (context: ControllerPluginContext) {
	await ControllerPlugin.fromContext(context);
}
