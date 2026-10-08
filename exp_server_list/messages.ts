import * as lib from "@clusterio/lib";
import { Type, Static } from "@sinclair/typebox";

/**
 * What the rest of the cluster knows about one instance.
 *
 * Built by the controller from the instance, its host and its mod pack, so
 * it is never stored. The id is the instance id.
 */
export class ServerRecord {
	constructor(
		public id: number,
		public name: string,
		public shortName: string,
		public description: string,
		public welcome: string,
		public resetTime: string,
		public hidden: boolean,
		/** Empty when the instance has no mod pack */
		public modPackName: string,
		/** Version the server last ran, empty if it has never started */
		public factorioVersion: string,
		public playerCount: number,
		public status: lib.InstanceStatus,
		/** Empty when the host has no public address */
		public address: string,
		public updatedAtMs: number = 0,
		public isDeleted: boolean = false,
	) {}

	static jsonSchema = Type.Object({
		id: Type.Integer(),
		name: Type.String(),
		short_name: Type.String(),
		description: Type.String(),
		welcome: Type.String(),
		reset_time: Type.String(),
		hidden: Type.Boolean(),
		mod_pack_name: Type.String(),
		factorio_version: Type.String(),
		player_count: Type.Integer(),
		status: lib.InstanceStatus,
		address: Type.String(),
		updated_at_ms: Type.Optional(Type.Number()),
		is_deleted: Type.Optional(Type.Boolean()),
	});

	toJSON() {
		const json: Static<typeof ServerRecord.jsonSchema> = {
			id: this.id,
			name: this.name,
			short_name: this.shortName,
			description: this.description,
			welcome: this.welcome,
			reset_time: this.resetTime,
			hidden: this.hidden,
			mod_pack_name: this.modPackName,
			factorio_version: this.factorioVersion,
			player_count: this.playerCount,
			status: this.status,
			address: this.address,
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
			json.name,
			json.short_name,
			json.description,
			json.welcome,
			json.reset_time,
			json.hidden,
			json.mod_pack_name,
			json.factorio_version,
			json.player_count,
			json.status,
			json.address,
			json.updated_at_ms ?? 0,
			json.is_deleted ?? false,
		);
	}

	/** True when every field other than updatedAtMs matches */
	sameAs(other: ServerRecord) {
		return this.id === other.id
			&& this.name === other.name
			&& this.shortName === other.shortName
			&& this.description === other.description
			&& this.welcome === other.welcome
			&& this.resetTime === other.resetTime
			&& this.hidden === other.hidden
			&& this.modPackName === other.modPackName
			&& this.factorioVersion === other.factorioVersion
			&& this.playerCount === other.playerCount
			&& this.status === other.status
			&& this.address === other.address
			&& this.isDeleted === other.isDeleted;
	}
}

export class ServerUpdatesEvent {
	declare ["constructor"]: typeof ServerUpdatesEvent;
	static plugin = "exp_server_list" as const;
	static type = "event" as const;
	static src = "controller" as const;
	static dst = ["control", "instance"] as const;
	static permission = "exp_server_list.list" as const;

	constructor(
		public updates: ServerRecord[],
	) {}

	static jsonSchema = Type.Object({
		updates: Type.Array(ServerRecord.jsonSchema),
	});

	toJSON() {
		return { updates: this.updates.map(server => server.toJSON()) };
	}

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(json.updates.map(server => ServerRecord.fromJSON(server)));
	}
}

/** List every instance, hidden ones included. */
export class ServerListRequest {
	declare ["constructor"]: typeof ServerListRequest;
	static plugin = "exp_server_list" as const;
	static type = "request" as const;
	static src = ["control", "instance"] as const;
	static dst = "controller" as const;
	static permission = "exp_server_list.list" as const;
	static Response = lib.jsonArray(ServerRecord);
}
