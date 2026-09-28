import * as lib from "@clusterio/lib";
import { Type, Static } from "@sinclair/typebox";

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

const FeatureValueSchema = Type.Union([Type.Boolean(), Type.Number(), Type.String()]);

/**
 * The config of one scenario feature, see features.ts.
 *
 * Only values which differ from the default are stored, so a changed default
 * applies to every cluster which did not set that value.
 */
export class FeatureRecord {
	constructor(
		/** Name of the feature in features.ts */
		public id: string,
		public enabled: boolean,
		public values: Record<string, boolean | number | string> = {},
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

/** Enable or disable a feature and replace its values, values left out go back to their default. */
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
		public values: Record<string, boolean | number | string>,
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
