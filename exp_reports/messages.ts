import * as lib from "@clusterio/lib";
import { Type, Static } from "@sinclair/typebox";

/*
	Data records
*/

/**
 * A report made against a player.
 *
 * Only the read state of a report can change, so createdAtMs is kept apart
 * from updatedAtMs.
 */
export class ReportRecord {
	constructor(
		public id: number,
		public playerName: string,
		public byPlayerName: string,
		public reason: string,
		/** Name of the instance the report was made on, empty when made from the web ui. */
		public instanceName: string,
		public createdAtMs: number = 0,
		public isRead: boolean = false,
		public updatedAtMs: number = 0,
		public isDeleted: boolean = false,
	) {}

	static jsonSchema = Type.Object({
		id: Type.Integer(),
		player_name: Type.String(),
		by_player_name: Type.String(),
		reason: Type.String(),
		instance_name: Type.String(),
		created_at_ms: Type.Number(),
		is_read: Type.Optional(Type.Boolean()),
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
			created_at_ms: this.createdAtMs,
		};

		if (this.isRead) {
			json.is_read = true;
		}

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
			json.created_at_ms,
			json.is_read ?? false,
			json.updated_at_ms ?? 0,
			json.is_deleted ?? false,
		);
	}
}

/** A player whose joins are announced to admins and posted to the webhooks. */
export class WatchListRecord {
	constructor(
		public playerName: string,
		public reason: string,
		/** User who added the player, from the web ui or a report. */
		public byPlayerName: string,
		public createdAtMs: number = 0,
		public updatedAtMs: number = 0,
		public isDeleted: boolean = false,
	) {}

	/** Player names are case insensitive in Factorio and Clusterio. */
	get id() {
		return this.playerName.toLowerCase();
	}

	static jsonSchema = Type.Object({
		player_name: Type.String(),
		reason: Type.String(),
		by_player_name: Type.String(),
		created_at_ms: Type.Number(),
		updated_at_ms: Type.Optional(Type.Number()),
		is_deleted: Type.Optional(Type.Boolean()),
	});

	toJSON() {
		const json: Static<typeof WatchListRecord.jsonSchema> = {
			player_name: this.playerName,
			reason: this.reason,
			by_player_name: this.byPlayerName,
			created_at_ms: this.createdAtMs,
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
			json.player_name,
			json.reason,
			json.by_player_name,
			json.created_at_ms,
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

export class WatchListUpdatedEvent {
	declare ["constructor"]: typeof WatchListUpdatedEvent;
	static plugin = "exp_reports" as const;
	static type = "event" as const;
	static src = "controller" as const;
	static dst = "control" as const;
	static permission = "exp_reports.watch_list.subscribe" as const;

	constructor(
		public updates: WatchListRecord[],
	) {}

	static jsonSchema = Type.Object({
		updates: Type.Array(WatchListRecord.jsonSchema),
	});

	toJSON() {
		return { updates: this.updates.map(entry => entry.toJSON()) };
	}

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(json.updates.map(entry => WatchListRecord.fromJSON(entry)));
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

export class ReportSetReadRequest {
	declare ["constructor"]: typeof ReportSetReadRequest;
	static plugin = "exp_reports" as const;
	static type = "request" as const;
	static src = "control" as const;
	static dst = "controller" as const;
	static permission = "exp_reports.report.mark_read" as const;

	constructor(
		public id: number,
		public isRead: boolean,
	) {}

	static jsonSchema = Type.Object({
		id: Type.Integer(),
		is_read: Type.Boolean(),
	});

	toJSON() {
		return { id: this.id, is_read: this.isRead };
	}

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(json.id, json.is_read);
	}
}

/*
	Watch list requests
*/

/** Add a player to the watch list in the name of the web user. */
export class WatchListAddRequest {
	declare ["constructor"]: typeof WatchListAddRequest;
	static plugin = "exp_reports" as const;
	static type = "request" as const;
	static src = "control" as const;
	static dst = "controller" as const;
	static permission = "exp_reports.watch_list.add" as const;
	static Response = WatchListRecord;

	constructor(
		public playerName: string,
		public reason: string,
	) {}

	static jsonSchema = Type.Object({
		player_name: Type.String(),
		reason: Type.String(),
	});

	toJSON() {
		return { player_name: this.playerName, reason: this.reason };
	}

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(json.player_name, json.reason);
	}
}

export class WatchListRemoveRequest {
	declare ["constructor"]: typeof WatchListRemoveRequest;
	static plugin = "exp_reports" as const;
	static type = "request" as const;
	static src = "control" as const;
	static dst = "controller" as const;
	static permission = "exp_reports.watch_list.remove" as const;

	constructor(
		public playerName: string,
	) {}

	static jsonSchema = Type.Object({
		player_name: Type.String(),
	});

	toJSON() {
		return { player_name: this.playerName };
	}

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(json.player_name);
	}
}

/**
 * A watched player joined an instance, sent to every instance so admins
 * everywhere see it, or only to the one they joined when
 * exp_reports.announce_to_all_instances is off.
 *
 * The player is watched because of their watch list entry, their unread
 * reports when exp_reports.watch_unread_reports is set, or both. Unread
 * reports are newest first.
 */
export class WatchedPlayerJoinedEvent {
	declare ["constructor"]: typeof WatchedPlayerJoinedEvent;
	static plugin = "exp_reports" as const;
	static type = "event" as const;
	static src = "controller" as const;
	static dst = "instance" as const;

	constructor(
		public playerName: string,
		public instanceName: string,
		public watchListEntry: WatchListRecord | undefined,
		public unreadReports: ReportRecord[],
	) {}

	static jsonSchema = Type.Object({
		player_name: Type.String(),
		instance_name: Type.String(),
		watch_list_entry: Type.Optional(WatchListRecord.jsonSchema),
		unread_reports: Type.Array(ReportRecord.jsonSchema),
	});

	toJSON() {
		const json: Static<typeof WatchedPlayerJoinedEvent.jsonSchema> = {
			player_name: this.playerName,
			instance_name: this.instanceName,
			unread_reports: this.unreadReports.map(report => report.toJSON()),
		};
		if (this.watchListEntry) {
			json.watch_list_entry = this.watchListEntry.toJSON();
		}
		return json;
	}

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(
			json.player_name,
			json.instance_name,
			json.watch_list_entry ? WatchListRecord.fromJSON(json.watch_list_entry) : undefined,
			json.unread_reports.map(report => ReportRecord.fromJSON(report)),
		);
	}
}
