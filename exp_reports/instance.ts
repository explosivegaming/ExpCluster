import type { InstancePluginContext } from "@clusterio/host";
import * as messages from "./messages.js";

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
export default async function (context: InstancePluginContext) {
	const { instance } = context;

	/** Hand an answer to lua, unless the instance stopped while it was being fetched. */
	async function luaSend(receiver: string, json: any) {
		if (instance.status !== "running") {
			return;
		}
		await instance.sendRcon(
			`/sc exp_reports.${receiver}(helpers.json_to_table[=[${JSON.stringify(json)}]=])`, true
		);
	}

	instance.server.handle("exp_reports:create", async (event: IpcReportCreate) => {
		try {
			const report = await instance.sendTo("controller", new messages.ReportCreateRequest(
				event.player_name, event.reason, event.by_player_name,
			));
			const reports = await instance.sendTo("controller", new messages.ReportListRequest(event.player_name));
			await luaSend("receive_created", {
				report: report.toJSON(),
				reports: reports.map(other => other.toJSON()),
			});
		} catch (err: any) {
			await luaSend("receive_error", { caller: event.by_player_name, message: err.message });
		}
	});

	instance.server.handle("exp_reports:list", async (event: IpcReportList) => {
		try {
			const reports = await instance.sendTo("controller", new messages.ReportListRequest(event.player_name));
			await luaSend("receive_list", {
				caller: event.caller,
				player_name: event.player_name,
				reports: reports.map(report => report.toJSON()),
			});
		} catch (err: any) {
			await luaSend("receive_error", { caller: event.caller, message: err.message });
		}
	});

	instance.server.handle("exp_reports:delete", async (event: IpcReportDelete) => {
		try {
			let reports = await instance.sendTo("controller", new messages.ReportListRequest(event.player_name));
			if (event.by_player_name !== undefined) {
				reports = reports.filter(report => report.byPlayerName === event.by_player_name);
			}
			for (const report of reports) {
				await instance.sendTo("controller", new messages.ReportDeleteRequest(report.id));
			}
			await luaSend("receive_deleted", {
				caller: event.caller,
				player_name: event.player_name,
				by_player_name: event.by_player_name,
				count: reports.length,
			});
		} catch (err: any) {
			await luaSend("receive_error", { caller: event.caller, message: err.message });
		}
	});
}
