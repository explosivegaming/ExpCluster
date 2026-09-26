import * as lib from "@clusterio/lib";
import { Type, Static } from "@sinclair/typebox";

/*
	Data records
*/

/**
 * A report made against a player.
 *
 * Reports are immutable, so until it is deleted updatedAtMs is when the
 * report was made.
 */
export class ReportRecord {
	constructor(
		public id: number,
		public playerName: string,
		public byPlayerName: string,
		public reason: string,
		/** Name of the instance the report was made on, empty when made from the web ui. */
		public instanceName: string,
		public updatedAtMs: number = 0,
		public isDeleted: boolean = false,
	) {}

	static jsonSchema = Type.Object({
		id: Type.Integer(),
		player_name: Type.String(),
		by_player_name: Type.String(),
		reason: Type.String(),
		instance_name: Type.String(),
		updated_at_ms: Type.Optional(Type.Number()),
		is_deleted: Type.Optional(Type.Boolean()),
	});

	toJSON() {
		const json: Static<typeof ReportRecord.jsonSchema> = {
			id: this.id,
			player_name: this.playerName,
			by_player_name: this.byPlayerName,
			reason: this.reason,
			instance_name: this.instanceName,
		};

		if (this.updatedAtMs) {
			json.updated_at_ms = this.updatedAtMs;
		}

		if (this.isDeleted) {
			json.is_deleted = true;
		}

		return json;
	}

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(
			json.id,
			json.player_name,
			json.by_player_name,
			json.reason,
			json.instance_name,
			json.updated_at_ms ?? 0,
			json.is_deleted ?? false,
		);
	}
}

/*
	Update events
*/

export class ReportUpdatedEvent {
	declare ["constructor"]: typeof ReportUpdatedEvent;
	static plugin = "exp_reports" as const;
	static type = "event" as const;
	static src = "controller" as const;
	static dst = "control" as const;
	static permission = "exp_reports.report.subscribe" as const;

	constructor(
		public updates: ReportRecord[],
	) {}

	static jsonSchema = Type.Object({
		updates: Type.Array(ReportRecord.jsonSchema),
	});

	toJSON() {
		return { updates: this.updates.map(report => report.toJSON()) };
	}

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(json.updates.map(report => ReportRecord.fromJSON(report)));
	}
}

/*
	Report requests
*/

/** List every report, or only those against one player. */
export class ReportListRequest {
	declare ["constructor"]: typeof ReportListRequest;
	static plugin = "exp_reports" as const;
	static type = "request" as const;
	static src = ["control", "instance"] as const;
	static dst = "controller" as const;
	static permission = "exp_reports.report.list" as const;
	static Response = lib.jsonArray(ReportRecord);

	constructor(
		public playerName?: string,
	) {}

	static jsonSchema = Type.Object({
		player_name: Type.Optional(Type.String()),
	});

	toJSON() {
		const json: Static<typeof ReportListRequest.jsonSchema> = {};
		if (this.playerName !== undefined) {
			json.player_name = this.playerName;
		}
		return json;
	}

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(json.player_name);
	}
}

export class ReportGetRequest {
	declare ["constructor"]: typeof ReportGetRequest;
	static plugin = "exp_reports" as const;
	static type = "request" as const;
	static src = ["control", "instance"] as const;
	static dst = "controller" as const;
	static permission = "exp_reports.report.get" as const;
	static Response = ReportRecord;

	constructor(
		public id: number,
	) {}

	static jsonSchema = Type.Object({
		id: Type.Integer(),
	});

	toJSON() {
		return { id: this.id };
	}

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(json.id);
	}
}

/**
 * Report a player.
 *
 * From an instance byPlayerName is the player who made the report. From the
 * web ui it is ignored and the report is made by the user of the connection.
 */
export class ReportCreateRequest {
	declare ["constructor"]: typeof ReportCreateRequest;
	static plugin = "exp_reports" as const;
	static type = "request" as const;
	static src = ["control", "instance"] as const;
	static dst = "controller" as const;
	static permission = "exp_reports.report.create" as const;
	static Response = ReportRecord;

	constructor(
		public playerName: string,
		public reason: string,
		public byPlayerName: string = "",
	) {}

	static jsonSchema = Type.Object({
		player_name: Type.String(),
		reason: Type.String(),
		by_player_name: Type.String(),
	});

	toJSON() {
		return {
			player_name: this.playerName,
			reason: this.reason,
			by_player_name: this.byPlayerName,
		};
	}

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(json.player_name, json.reason, json.by_player_name);
	}
}

export class ReportDeleteRequest {
	declare ["constructor"]: typeof ReportDeleteRequest;
	static plugin = "exp_reports" as const;
	static type = "request" as const;
	static src = ["control", "instance"] as const;
	static dst = "controller" as const;
	static permission = "exp_reports.report.delete" as const;

	constructor(
		public id: number,
	) {}

	static jsonSchema = Type.Object({
		id: Type.Integer(),
	});

	toJSON() {
		return { id: this.id };
	}

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(json.id);
	}
}
