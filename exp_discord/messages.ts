import * as lib from "@clusterio/lib";
import { Type, Static } from "@sinclair/typebox";

/*
	Data records
*/

/** A Discord account and the Factorio accounts linked to it. */
export class DiscordAccountRecord {
	constructor(
		/** Discord user id */
		public id: string,
		/** Discord display name at the time of the last login */
		public name: string,
		public factorioNames: string[],
		public updatedAtMs: number = 0,
		public isDeleted: boolean = false,
	) {}

	static jsonSchema = Type.Object({
		id: Type.String(),
		name: Type.String(),
		factorio_names: Type.Array(Type.String()),
		updated_at_ms: Type.Optional(Type.Number()),
		is_deleted: Type.Optional(Type.Boolean()),
	});

	toJSON() {
		const json: Static<typeof DiscordAccountRecord.jsonSchema> = {
			id: this.id,
			name: this.name,
			factorio_names: this.factorioNames,
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
			json.factorio_names,
			json.updated_at_ms ?? 0,
			json.is_deleted ?? false,
		);
	}
}

/** Users may always act on their own link, otherwise the permission is needed. */
function selfOrPermission(permission: lib.PermissionName) {
	return (user: lib.IUser, message: lib.MessageRequest) => {
		const playerName = (message.data as { player_name: string }).player_name;
		if (user.name.toLowerCase() !== playerName.toLowerCase()) {
			user.checkPermission(permission);
		}
	};
}

const LinkResponse = lib.plainJson(Type.Union([
	Type.Null(),
	Type.Object({
		id: Type.String(),
		name: Type.String(),
	}),
]));

/*
	Link requests
*/

/** Link a player to the Discord account which generated the code, sent when the player uses the code in game. */
export class DiscordLinkRequest {
	declare ["constructor"]: typeof DiscordLinkRequest;
	static plugin = "exp_discord" as const;
	static type = "request" as const;
	static src = "instance" as const;
	static dst = "controller" as const;
	static Response = LinkResponse;

	constructor(
		public playerName: string,
		public code: string,
	) {}

	static jsonSchema = Type.Object({
		player_name: Type.String(),
		code: Type.String(),
	});

	toJSON() {
		return { player_name: this.playerName, code: this.code };
	}

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(json.player_name, json.code);
	}
}

/** Remove the link of a player, responds with the account it was linked to. */
export class DiscordUnlinkRequest {
	declare ["constructor"]: typeof DiscordUnlinkRequest;
	static plugin = "exp_discord" as const;
	static type = "request" as const;
	static src = ["control", "instance"] as const;
	static dst = "controller" as const;
	static permission = selfOrPermission("exp_discord.link.delete");
	static Response = LinkResponse;

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

/** Get the Discord account a player is linked to. */
export class DiscordLinkGetRequest {
	declare ["constructor"]: typeof DiscordLinkGetRequest;
	static plugin = "exp_discord" as const;
	static type = "request" as const;
	static src = ["control", "instance"] as const;
	static dst = "controller" as const;
	static permission = selfOrPermission("exp_discord.link.get");
	static Response = LinkResponse;

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
