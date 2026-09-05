import { BaseInstancePlugin } from "@clusterio/host";
import * as messages from "./messages";

/** Sent by the lua side when a player reports another. */
export type IpcReportCreate = {
	player_name: string,
	by_player_name: string,
	reason: string,
};

/** Sent by the lua side to list the reports for a player, or for everyone. */
export type IpcReportList = {
	caller: string,
	player_name: string | undefined,
};

/** Sent by the lua side to delete the reports against a player, optionally only those from one player. */
export type IpcReportDelete = {
	caller: string,
	player_name: string,
	by_player_name: string | undefined,
};

/**
 * Bridges the lua side and the controller.
 *
 * Nothing is kept in the lua state, every request goes to the controller and
 * the answer is handed back to lua once it arrives. The instance may have
 * stopped by then, in which case the answer is dropped.
 */
export class InstancePlugin extends BaseInstancePlugin {
	async init() {
		this.instance.server.handle("exp_reports:create", this.handleCreateIPC.bind(this));
		this.instance.server.handle("exp_reports:list", this.handleListIPC.bind(this));
		this.instance.server.handle("exp_reports:delete", this.handleDeleteIPC.bind(this));
	}

	async handleCreateIPC(event: IpcReportCreate) {
		try {
			const report = await this.instance.sendTo("controller", new messages.ReportCreateRequest(
				event.player_name, event.reason, event.by_player_name,
			));
			const reports = await this.instance.sendTo("controller", new messages.ReportListRequest(event.player_name));
			await this.luaSend("receive_created", {
				report: report.toJSON(),
				reports: reports.map(other => other.toJSON()),
			});
		} catch (err: any) {
			await this.luaSend("receive_error", { caller: event.by_player_name, message: err.message });
		}
	}

	async handleListIPC(event: IpcReportList) {
		try {
			const reports = await this.instance.sendTo("controller", new messages.ReportListRequest(event.player_name));
			await this.luaSend("receive_list", {
				caller: event.caller,
				player_name: event.player_name,
				reports: reports.map(report => report.toJSON()),
			});
		} catch (err: any) {
			await this.luaSend("receive_error", { caller: event.caller, message: err.message });
		}
	}

	async handleDeleteIPC(event: IpcReportDelete) {
		try {
			let reports = await this.instance.sendTo("controller", new messages.ReportListRequest(event.player_name));
			if (event.by_player_name !== undefined) {
				reports = reports.filter(report => report.byPlayerName === event.by_player_name);
			}
			for (const report of reports) {
				await this.instance.sendTo("controller", new messages.ReportDeleteRequest(report.id));
			}
			await this.luaSend("receive_deleted", {
				caller: event.caller,
				player_name: event.player_name,
				by_player_name: event.by_player_name,
				count: reports.length,
			});
		} catch (err: any) {
			await this.luaSend("receive_error", { caller: event.caller, message: err.message });
		}
	}

	/** Hand an answer to lua, unless the instance stopped while it was being fetched. */
	async luaSend(receiver: string, json: any) {
		if (this.instance.status !== "running") {
			return;
		}
		await this.instance.sendRcon(
			`/sc exp_reports.${receiver}(helpers.json_to_table[=[${JSON.stringify(json)}]=])`, true
		);
	}
}
