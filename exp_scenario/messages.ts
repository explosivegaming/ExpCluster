import * as lib from "@clusterio/lib";
import { Type, Static } from "@sinclair/typebox";
import type { FeatureValue } from "./features.js";

/** Create the roles and permission groups the scenario shipped with, see seed.ts. */
export class SeedRequest {
	declare ["constructor"]: typeof SeedRequest;
	static plugin = "exp_scenario" as const;
	static type = "request" as const;
	static src = "control" as const;
	static dst = "controller" as const;
	static permission = "exp_scenario.seed" as const;

	constructor() {}
}

const FeatureValueSchema = Type.Union([Type.Boolean(), Type.Number(), Type.String(), Type.Array(Type.String()), Type.Null()]);

/** The config of one feature, see features.ts. Only values which differ from the default are stored. */
export class FeatureRecord {
	constructor(
		/** Name of the feature in features.ts */
		public id: string,
		public enabled: boolean,
		public values: Record<string, FeatureValue> = {},
		public updatedAtMs: number = 0,
		public isDeleted: boolean = false,
	) {}

	static jsonSchema = Type.Object({
		id: Type.String(),
		enabled: Type.Boolean(),
		values: Type.Record(Type.String(), FeatureValueSchema),
		updated_at_ms: Type.Optional(Type.Number()),
		is_deleted: Type.Optional(Type.Boolean()),
	});

	toJSON() {
		const json: Static<typeof FeatureRecord.jsonSchema> = {
			id: this.id,
			enabled: this.enabled,
			values: this.values,
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
			json.enabled,
			json.values,
			json.updated_at_ms ?? 0,
			json.is_deleted ?? false,
		);
	}
}

export class FeatureUpdatedEvent {
	declare ["constructor"]: typeof FeatureUpdatedEvent;
	static plugin = "exp_scenario" as const;
	static type = "event" as const;
	static src = "controller" as const;
	static dst = ["control", "instance"] as const;
	static permission = "exp_scenario.config.view" as const;

	constructor(
		public updates: FeatureRecord[],
	) {}

	static jsonSchema = Type.Object({
		updates: Type.Array(FeatureRecord.jsonSchema),
	});

	toJSON() {
		return { updates: this.updates.map(feature => feature.toJSON()) };
	}

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(json.updates.map(feature => FeatureRecord.fromJSON(feature)));
	}
}

/** List the config of every feature. */
export class FeatureListRequest {
	declare ["constructor"]: typeof FeatureListRequest;
	static plugin = "exp_scenario" as const;
	static type = "request" as const;
	static src = ["control", "instance"] as const;
	static dst = "controller" as const;
	static permission = "exp_scenario.config.view" as const;
	static Response = lib.jsonArray(FeatureRecord);
}

/** Replace the config of a feature, values left out go back to their default. */
export class FeatureUpdateRequest {
	declare ["constructor"]: typeof FeatureUpdateRequest;
	static plugin = "exp_scenario" as const;
	static type = "request" as const;
	static src = "control" as const;
	static dst = "controller" as const;
	static permission = "exp_scenario.config.edit" as const;
	static Response = FeatureRecord;

	constructor(
		public id: string,
		public enabled: boolean,
		public values: Record<string, FeatureValue>,
	) {}

	static jsonSchema = Type.Object({
		id: Type.String(),
		enabled: Type.Boolean(),
		values: Type.Record(Type.String(), FeatureValueSchema),
	});

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(json.id, json.enabled, json.values);
	}
}

/** Settings of a player kept by the controller, by player name. Only set values are stored. */
export class PlayerRecord {
	constructor(
		/** Name of the player */
		public id: string,
		/** Shown to everyone when the player joins */
		public joinMessage?: string,
		/** The language of their game, such as "en" or "pt-BR" */
		public locale?: string,
		/** Toolbar state from Gui.toolbar.get_state, json compressed with helpers.encode_string */
		public toolbar?: string,
		public updatedAtMs: number = 0,
		public isDeleted: boolean = false,
	) {}

	static jsonSchema = Type.Object({
		id: Type.String(),
		join_message: Type.Optional(Type.String()),
		locale: Type.Optional(Type.String()),
		toolbar: Type.Optional(Type.String()),
		updated_at_ms: Type.Optional(Type.Number()),
		is_deleted: Type.Optional(Type.Boolean()),
	});

	toJSON() {
		const json: Static<typeof PlayerRecord.jsonSchema> = { id: this.id };
		if (this.joinMessage) {
			json.join_message = this.joinMessage;
		}
		if (this.locale) {
			json.locale = this.locale;
		}
		if (this.toolbar) {
			json.toolbar = this.toolbar;
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
			json.join_message,
			json.locale,
			json.toolbar,
			json.updated_at_ms ?? 0,
			json.is_deleted ?? false,
		);
	}
}

/** Users may always read their own settings, otherwise they need to be able to see users. */
function selfOrPermission(permission: lib.PermissionName) {
	return (user: lib.IUser, message: lib.MessageRequest) => {
		const playerName = (message.data as { player_name: string }).player_name;
		if (user.name.toLowerCase() !== playerName.toLowerCase()) {
			user.checkPermission(permission);
		}
	};
}

/** Get the settings of a player, an empty record when nothing is stored. */
export class PlayerGetRequest {
	declare ["constructor"]: typeof PlayerGetRequest;
	static plugin = "exp_scenario" as const;
	static type = "request" as const;
	static src = ["control", "instance"] as const;
	static dst = "controller" as const;
	static permission = selfOrPermission("core.user.get");
	static Response = PlayerRecord;

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

export const joinMessageMaxLength = 255;

/** Set or clear (null or empty) the join message of a player. */
export class JoinMessageSetRequest {
	declare ["constructor"]: typeof JoinMessageSetRequest;
	static plugin = "exp_scenario" as const;
	static type = "request" as const;
	static src = ["control", "instance"] as const;
	static dst = "controller" as const;
	static permission(user: lib.IUser, message: lib.MessageRequest) {
		const playerName = (message.data as { player_name: string }).player_name;
		if (user.name.toLowerCase() === playerName.toLowerCase()) {
			user.checkPermission("exp_scenario.join_message.set");
		} else {
			user.checkPermission("exp_scenario.join_message.set_other");
		}
	}

	constructor(
		public playerName: string,
		public message: string | null,
	) {}

	static jsonSchema = Type.Object({
		player_name: Type.String(),
		message: Type.Union([Type.String({ maxLength: joinMessageMaxLength }), Type.Null()]),
	});

	toJSON() {
		return { player_name: this.playerName, message: this.message };
	}

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(json.player_name, json.message);
	}
}

/** The language a player's game uses, sent when they join and when they change it. */
export class PlayerLocaleEvent {
	declare ["constructor"]: typeof PlayerLocaleEvent;
	static plugin = "exp_scenario" as const;
	static type = "event" as const;
	static src = "instance" as const;
	static dst = "controller" as const;

	constructor(
		public playerName: string,
		public locale: string,
	) {}

	static jsonSchema = Type.Object({
		player_name: Type.String(),
		locale: Type.String(),
	});

	toJSON() {
		return { player_name: this.playerName, locale: this.locale };
	}

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(json.player_name, json.locale);
	}
}

/** The toolbar of a player, sent when they leave. */
export class PlayerToolbarEvent {
	declare ["constructor"]: typeof PlayerToolbarEvent;
	static plugin = "exp_scenario" as const;
	static type = "event" as const;
	static src = "instance" as const;
	static dst = "controller" as const;

	constructor(
		public playerName: string,
		public toolbar: string,
	) {}

	static jsonSchema = Type.Object({
		player_name: Type.String(),
		toolbar: Type.String(),
	});

	toJSON() {
		return { player_name: this.playerName, toolbar: this.toolbar };
	}

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(json.player_name, json.toolbar);
	}
}
