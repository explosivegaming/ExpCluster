import * as lib from "@clusterio/lib";
import { Type, Static } from "@sinclair/typebox";

/*
	Data records
*/

/** Colour used for a role's tag and name in game. */
export class RoleColor {
	constructor(
		public r: number,
		public g: number,
		public b: number,
	) {}

	static jsonSchema = Type.Object({
		r: Type.Number(),
		g: Type.Number(),
		b: Type.Number(),
	});

	toJSON(): Static<typeof RoleColor.jsonSchema> {
		return { r: this.r, g: this.g, b: this.b };
	}

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(json.r, json.g, json.b);
	}
}

/**
 * In game properties of a role which clusterio's own role does not carry.
 *
 * Stored on the controller keyed by the clusterio role id, and created
 * automatically for any role which does not have one yet.
 */
export class RoleMetaRecord {
	constructor(
		/** Id of the clusterio role these properties belong to. */
		public id: number,
		/** Position in the role order, a lower value is a more privileged role. */
		public order: number,
		/**
		 * Only the roles with the highest priority a player holds are considered,
		 * which allows a role such as Jail to suppress all others.
		 */
		public priority: number = 0,
		/** Short form of the role name, used where space is limited. */
		public shortHand: string = "",
		/** Tag shown next to the names of players with this role. */
		public tag: string = "",
		/** Colour used for the role in game, null uses the default colour. */
		public color: RoleColor | null = null,
		/** Online time after which this role is granted, null never grants it. */
		public autoAssignOnlineTimeMs: number | null = null,
		/** When true holders of this role are never granted roles automatically. */
		public blockAutoAssign: boolean = false,
		public updatedAtMs: number = 0,
		public isDeleted: boolean = false,
	) {}

	static jsonSchema = Type.Object({
		id: Type.Integer(),
		order: Type.Number(),
		priority: Type.Optional(Type.Number()),
		short_hand: Type.Optional(Type.String()),
		tag: Type.Optional(Type.String()),
		color: Type.Optional(Type.Union([RoleColor.jsonSchema, Type.Null()])),
		auto_assign_online_time_ms: Type.Optional(Type.Union([Type.Number(), Type.Null()])),
		block_auto_assign: Type.Optional(Type.Boolean()),
		updated_at_ms: Type.Optional(Type.Number()),
		is_deleted: Type.Optional(Type.Boolean()),
	});

	toJSON() {
		const json: Static<typeof RoleMetaRecord.jsonSchema> = {
			id: this.id,
			order: this.order,
		};

		if (this.priority) {
			json.priority = this.priority;
		}

		if (this.shortHand) {
			json.short_hand = this.shortHand;
		}

		if (this.tag) {
			json.tag = this.tag;
		}

		if (this.color) {
			json.color = this.color.toJSON();
		}

		if (this.autoAssignOnlineTimeMs !== null) {
			json.auto_assign_online_time_ms = this.autoAssignOnlineTimeMs;
		}

		if (this.blockAutoAssign) {
			json.block_auto_assign = true;
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
			json.order,
			json.priority ?? 0,
			json.short_hand ?? "",
			json.tag ?? "",
			json.color ? RoleColor.fromJSON(json.color) : null,
			json.auto_assign_online_time_ms ?? null,
			json.block_auto_assign ?? false,
			json.updated_at_ms ?? 0,
			json.is_deleted ?? false,
		);
	}
}

/**
 * A clusterio role combined with its in game properties.
 *
 * This is the form sent to instances, because instances can not subscribe to
 * the core role updates which are only sent to control connections.
 */
export class RoleRecord {
	constructor(
		public id: number,
		public name: string,
		public permissions: string[],
		public meta: RoleMetaRecord,
		/** True for the role every player holds, taken from controller.default_role_id. */
		public isDefault: boolean = false,
		public updatedAtMs: number = 0,
		public isDeleted: boolean = false,
	) {}

	static jsonSchema = Type.Object({
		id: Type.Integer(),
		name: Type.String(),
		permissions: Type.Array(Type.String()),
		meta: RoleMetaRecord.jsonSchema,
		is_default: Type.Optional(Type.Boolean()),
		updated_at_ms: Type.Optional(Type.Number()),
		is_deleted: Type.Optional(Type.Boolean()),
	});

	toJSON() {
		const json: Static<typeof RoleRecord.jsonSchema> = {
			id: this.id,
			name: this.name,
			permissions: this.permissions,
			meta: this.meta.toJSON(),
		};

		if (this.isDefault) {
			json.is_default = true;
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
			json.name,
			json.permissions,
			RoleMetaRecord.fromJSON(json.meta),
			json.is_default ?? false,
			json.updated_at_ms ?? 0,
			json.is_deleted ?? false,
		);
	}
}

/** The roles a single player holds, mirroring the roles of their cluster user. */
export class AssignmentRecord {
	constructor(
		public name: string,
		public roleIds: Set<number>,
		public updatedAtMs: number = 0,
		public isDeleted: boolean = false,
	) {}

	get id() {
		return this.name;
	}

	static jsonSchema = Type.Object({
		name: Type.String(),
		role_ids: Type.Array(Type.Integer()),
		updated_at_ms: Type.Optional(Type.Number()),
		is_deleted: Type.Optional(Type.Boolean()),
	});

	toJSON() {
		const json: Static<typeof AssignmentRecord.jsonSchema> = {
			name: this.name,
			role_ids: [...this.roleIds],
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
			json.name,
			new Set(json.role_ids),
			json.updated_at_ms ?? 0,
			json.is_deleted ?? false,
		);
	}
}

/**
 * Encode roles for the lua initialise call.
 *
 * Roles repeat the same permission names over and over, so each name is sent
 * once and referenced by index. At 15 roles this is 17 KiB rather than 38 KiB
 * and decodes in 0.37 ms rather than 0.50 ms; at 60 roles it is 30 KiB rather
 * than 122 KiB and 0.87 ms rather than 1.52 ms.
 *
 * Single role updates stay in the plain form, they have nothing to share.
 */
export function encodeRolesForLua(roles: RoleRecord[]) {
	const names: string[] = [];
	const indexes = new Map<string, number>();

	const encoded = roles.map(role => {
		const permissions = role.permissions.map(permission => {
			let index = indexes.get(permission);
			if (index === undefined) {
				index = names.length;
				names.push(permission);
				indexes.set(permission, index);
			}
			return index;
		});

		return { ...role.toJSON(), permissions };
	});

	return { permission_names: names, roles: encoded };
}

/*
	Update events
*/

export class RoleUpdatedEvent {
	declare ["constructor"]: typeof RoleUpdatedEvent;
	static plugin = "exp_roles" as const;
	static type = "event" as const;
	static src = "controller" as const;
	static dst = ["control", "instance"] as const;
	static permission = "core.role.subscribe" as const;

	constructor(
		public updates: RoleRecord[],
	) {}

	static jsonSchema = Type.Object({
		updates: Type.Array(RoleRecord.jsonSchema),
	});

	toJSON() {
		return { updates: this.updates.map(role => role.toJSON()) };
	}

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(json.updates.map(role => RoleRecord.fromJSON(role)));
	}
}

export class AssignmentUpdatedEvent {
	declare ["constructor"]: typeof AssignmentUpdatedEvent;
	static plugin = "exp_roles" as const;
	static type = "event" as const;
	static src = "controller" as const;
	static dst = "instance" as const;

	constructor(
		public updates: AssignmentRecord[],
	) {}

	static jsonSchema = Type.Object({
		updates: Type.Array(AssignmentRecord.jsonSchema),
	});

	toJSON() {
		return { updates: this.updates.map(assignment => assignment.toJSON()) };
	}

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(json.updates.map(assignment => AssignmentRecord.fromJSON(assignment)));
	}
}

/*
	Role requests
*/

export class RoleListRequest {
	declare ["constructor"]: typeof RoleListRequest;
	static plugin = "exp_roles" as const;
	static type = "request" as const;
	static src = ["control", "instance"] as const;
	static dst = "controller" as const;
	static permission = "core.role.list" as const;
	static Response = lib.jsonArray(RoleRecord);

	constructor() {}
}

export class RoleMetaUpdateRequest {
	declare ["constructor"]: typeof RoleMetaUpdateRequest;
	static plugin = "exp_roles" as const;
	static type = "request" as const;
	static src = "control" as const;
	static dst = "controller" as const;
	static permission = "core.role.update" as const;

	constructor(
		public meta: RoleMetaRecord,
	) {}

	static jsonSchema = Type.Object({
		meta: RoleMetaRecord.jsonSchema,
	});

	toJSON() {
		return { meta: this.meta.toJSON() };
	}

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(RoleMetaRecord.fromJSON(json.meta));
	}
}

/*
	Assignment requests
*/

export class AssignmentListRequest {
	declare ["constructor"]: typeof AssignmentListRequest;
	static plugin = "exp_roles" as const;
	static type = "request" as const;
	static src = "instance" as const;
	static dst = "controller" as const;
	static Response = lib.jsonArray(AssignmentRecord);

	constructor() {}
}

/**
 * Add or remove roles for a player, sent by an instance when a role is changed
 * in game. Only accepted when the instance is configured as bidirectional.
 */
export class AssignmentUpdateRequest {
	declare ["constructor"]: typeof AssignmentUpdateRequest;
	static plugin = "exp_roles" as const;
	static type = "request" as const;
	static src = "instance" as const;
	static dst = "controller" as const;
	static permission = "core.user.update_roles" as const;

	constructor(
		public name: string,
		public assign: number[],
		public unassign: number[],
	) {}

	static jsonSchema = Type.Object({
		name: Type.String(),
		assign: Type.Array(Type.Integer()),
		unassign: Type.Array(Type.Integer()),
	});

	toJSON() {
		return {
			name: this.name,
			assign: this.assign,
			unassign: this.unassign,
		};
	}

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(json.name, json.assign, json.unassign);
	}
}
