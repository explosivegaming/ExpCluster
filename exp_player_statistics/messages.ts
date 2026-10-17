import * as lib from "@clusterio/lib";
import { Type, Static } from "@sinclair/typebox";

const StatsSchema = Type.Record(Type.String(), Type.Number());

/** Totals for one player across every instance, keyed by player name. */
export class PlayerStatistics {
	constructor(
		public id: string,
		/** Statistic name to total, missing statistics are zero */
		public stats: Record<string, number> = {},
		public updatedAtMs: number = 0,
		public isDeleted: boolean = false,
	) {}

	static jsonSchema = Type.Object({
		id: Type.String(),
		stats: StatsSchema,
		updated_at_ms: Type.Optional(Type.Number()),
		is_deleted: Type.Optional(Type.Boolean()),
	});

	toJSON() {
		const json: Static<typeof PlayerStatistics.jsonSchema> = {
			id: this.id,
			stats: this.stats,
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
		return new this(json.id, { ...json.stats }, json.updated_at_ms ?? 0, json.is_deleted ?? false);
	}
}

/** Statistics clusterio already keeps for every user, shown with the others but never added to, existing stats may contain legacy values */
export function userStatistics(user?: Pick<lib.UserDetails, "playerStats">, stats: Record<string, number> = {}): Record<string, number> {
	return {
		Playtime: (stats.Playtime ?? 0) + Math.floor((user?.playerStats.onlineTimeMs ?? 0) / 60e3),
		JoinCount: (stats.JoinCount ?? 0) + (user?.playerStats.joinCount ?? 0),
	};
}

/** Statistics gained by one player since the last update */
export class StatisticsDelta {
	constructor(
		public name: string,
		public stats: Record<string, number>,
	) {}

	static jsonSchema = Type.Object({
		name: Type.String(),
		stats: StatsSchema,
	});

	toJSON() {
		return { name: this.name, stats: this.stats };
	}

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(json.name, json.stats);
	}
}

/** Sent by an instance to add to the totals of its players. */
export class StatisticsUpdateEvent {
	declare ["constructor"]: typeof StatisticsUpdateEvent;
	static plugin = "exp_player_statistics" as const;
	static type = "event" as const;
	static src = "instance" as const;
	static dst = "controller" as const;
	static permission = null;

	constructor(
		public deltas: StatisticsDelta[],
	) {}

	static jsonSchema = Type.Object({
		deltas: Type.Array(StatisticsDelta.jsonSchema),
	});

	toJSON() {
		return { deltas: this.deltas.map(delta => delta.toJSON()) };
	}

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(json.deltas.map(delta => StatisticsDelta.fromJSON(delta)));
	}
}

export class PlayerStatisticsUpdatedEvent {
	declare ["constructor"]: typeof PlayerStatisticsUpdatedEvent;
	static plugin = "exp_player_statistics" as const;
	static type = "event" as const;
	static src = "controller" as const;
	static dst = "control" as const;
	static permission = "exp_player_statistics.view" as const;

	constructor(
		public updates: PlayerStatistics[],
	) {}

	static jsonSchema = Type.Object({
		updates: Type.Array(PlayerStatistics.jsonSchema),
	});

	toJSON() {
		return { updates: this.updates.map(player => player.toJSON()) };
	}

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(json.updates.map(player => PlayerStatistics.fromJSON(player)));
	}
}

/** Totals for one player, with Playtime and JoinCount from their clusterio user. */
export class StatisticsGetRequest {
	declare ["constructor"]: typeof StatisticsGetRequest;
	static plugin = "exp_player_statistics" as const;
	static type = "request" as const;
	static src = ["control", "instance"] as const;
	static dst = "controller" as const;
	static permission = "exp_player_statistics.view" as const;
	static Response = PlayerStatistics;

	constructor(
		public name: string,
	) {}

	static jsonSchema = Type.Object({
		name: Type.String(),
	});

	toJSON() {
		return { name: this.name };
	}

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(json.name);
	}
}

export class StatisticsListRequest {
	declare ["constructor"]: typeof StatisticsListRequest;
	static plugin = "exp_player_statistics" as const;
	static type = "request" as const;
	static src = ["control", "instance"] as const;
	static dst = "controller" as const;
	static permission = "exp_player_statistics.view" as const;
	static Response = lib.jsonArray(PlayerStatistics);
}
