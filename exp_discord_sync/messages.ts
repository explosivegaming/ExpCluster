import * as lib from "@clusterio/lib";
import { Type, Static } from "@sinclair/typebox";

/*
	Data records
*/

/** The Discord roles given to linked players holding a clusterio role. */
export class RoleMappingRecord {
	constructor(
		/** Clusterio role id */
		public id: number,
		public discordRoleIds: string[],
		public updatedAtMs: number = 0,
		public isDeleted: boolean = false,
	) {}

	static jsonSchema = Type.Object({
		id: Type.Integer(),
		discord_role_ids: Type.Array(Type.String()),
		updated_at_ms: Type.Optional(Type.Number()),
		is_deleted: Type.Optional(Type.Boolean()),
	});

	toJSON() {
		const json: Static<typeof RoleMappingRecord.jsonSchema> = {
			id: this.id,
			discord_role_ids: this.discordRoleIds,
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
		return new this(json.id, json.discord_role_ids, json.updated_at_ms ?? 0, json.is_deleted ?? false);
	}
}

export class RoleMappingUpdatedEvent {
	declare ["constructor"]: typeof RoleMappingUpdatedEvent;
	static plugin = "exp_discord_sync" as const;
	static type = "event" as const;
	static src = "controller" as const;
	static dst = "control" as const;
	static permission = "core.role.subscribe" as const;

	constructor(
		public updates: RoleMappingRecord[],
	) {}

	static jsonSchema = Type.Object({
		updates: Type.Array(RoleMappingRecord.jsonSchema),
	});

	toJSON() {
		return { updates: this.updates.map(mapping => mapping.toJSON()) };
	}

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(json.updates.map(mapping => RoleMappingRecord.fromJSON(mapping)));
	}
}

/** Set the Discord roles of a clusterio role, an empty list removes the mapping. */
export class RoleMappingUpdateRequest {
	declare ["constructor"]: typeof RoleMappingUpdateRequest;
	static plugin = "exp_discord_sync" as const;
	static type = "request" as const;
	static src = "control" as const;
	static dst = "controller" as const;
	static permission = "exp_discord_sync.mapping.update" as const;

	constructor(
		public roleId: number,
		public discordRoleIds: string[],
	) {}

	static jsonSchema = Type.Object({
		role_id: Type.Integer(),
		discord_role_ids: Type.Array(Type.String()),
	});

	toJSON() {
		return { role_id: this.roleId, discord_role_ids: this.discordRoleIds };
	}

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(json.role_id, json.discord_role_ids);
	}
}

const GuildRole = Type.Object({
	id: Type.String(),
	name: Type.String(),
	color: Type.Integer(),
});

/** The roles of the configured guild which the bot can give, highest first. */
export class GuildRoleListRequest {
	declare ["constructor"]: typeof GuildRoleListRequest;
	static plugin = "exp_discord_sync" as const;
	static type = "request" as const;
	static src = "control" as const;
	static dst = "controller" as const;
	static permission = "core.role.list" as const;
	static Response = lib.plainJson(Type.Array(GuildRole));
}
