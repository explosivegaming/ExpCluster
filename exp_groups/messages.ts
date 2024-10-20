import { User, InstanceDetails, IControllerUser, Link, MessageRequest, StringEnum, PermissionError, Address } from "@clusterio/lib";
import { Type, Static } from "@sinclair/typebox";

export const PermissionInstanceIdSchema = Type.Union([InstanceDetails.jsonSchema.properties.id, Type.Literal("Global")])
export type PermissionInstanceId = InstanceDetails["id"] | "Global"
export type GamePermission = string; // todo: maybe enum this?

/**
 * Data class for permission groups
 */
export class PermissionGroup {
	constructor(
		public instanceId: PermissionInstanceId,
		public name: string,
		/** A lower order assumes a lower permission group */
		public order: number = 0,
		/** A role will use the highest order group it is apart of */
		public roleIds: User["roleIds"] = new Set(),
		public permissions: Set<GamePermission> = new Set(),
		public updatedAtMs: number = 0,
		public isDeleted: boolean = false,
	) {
	}

	static jsonSchema = Type.Object({
		instanceId: PermissionInstanceIdSchema,
		name: Type.String(),
		order: Type.Number(),
		roleIds: Type.Array(Type.Number()),
		permissions: Type.Array(Type.String()),
		updatedAtMs: Type.Optional(Type.Number()),
		isDeleted: Type.Optional(Type.Boolean()),
	});

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(
			json.instanceId,
			json.name,
			json.order,
			new Set(json.roleIds),
			new Set(json.permissions),
			json.updatedAtMs,
			json.isDeleted
		);
	}

	toJSON(): Static<typeof PermissionGroup.jsonSchema> {
		return {
			instanceId: this.instanceId,
			name: this.name,
			order: this.order,
			roleIds: [...this.roleIds.values()],
			permissions: [...this.permissions.values()],
			updatedAtMs: this.updatedAtMs > 0 ? this.updatedAtMs : undefined,
			isDeleted: this.isDeleted ? this.isDeleted : undefined,
		}
	}

	get id() {
		return `${this.instanceId}:${this.name}`;
	}

	copy(newInstanceId: PermissionInstanceId) {
		return new PermissionGroup(
			newInstanceId,
			this.name,
			this.order,
			new Set(this.roleIds),
			new Set(this.permissions),
			Date.now(),
			false
		)
	}
}

export class InstancePermissionGroups {
	constructor(
		public instanceId: PermissionInstanceId,
		public groups: Map<PermissionGroup["name"], PermissionGroup> = new Map(),
	) {
	}

	static jsonSchema = Type.Object({
		instanceId: PermissionInstanceIdSchema,
		permissionsGroups: Type.Array(PermissionGroup.jsonSchema),
	});

	static fromJSON(json: Static<typeof InstancePermissionGroups.jsonSchema>) {
		return new InstancePermissionGroups(
			json.instanceId,
			new Map(json.permissionsGroups.map(group => [group.name, PermissionGroup.fromJSON(group)])),
		);
	}

	toJSON() {
		return {
			instanceId: this.instanceId,
			permissionsGroups: [...this.groups.values()],
		}
	}

	getUserGroup(user: User) {
		const groups = [...user.roleIds.values()].map(roleId => 
			// There will always be one and only one group for each role
			[...this.groups.values()].find(group => group.roleIds.has(roleId))!
		);
		return groups.reduce((highest, group) => highest.order > group.order ? highest : group);
	}

	get id() {
		return this.instanceId;
	}
}

export class PermissionGroupUpdate {
	declare ["constructor"]: typeof PermissionGroupUpdate;
	static type = "event" as const;
	static src = ["controller", "instance"] as const;
	static dst = ["control", "instance", "controller"] as const;
	static plugin = "exp_groups" as const;
	static permission = "exp_groups.list.subscribe";

	constructor(
		public updates: PermissionGroup[],
	) { }

	static jsonSchema = Type.Object({
		"updates": Type.Array(PermissionGroup.jsonSchema),
	});

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(
			json.updates.map(update => PermissionGroup.fromJSON(update))
		);
	}
}

export type PermissionGroupEditType = "assign_players" | "add_permissions" | "remove_permissions";

export class PermissionGroupEditEvent {
	declare ["constructor"]: typeof PermissionGroupEditEvent;
	static type = "event" as const;
	static src = ["instance", "controller"] as const;
	static dst = ["control", "instance", "controller"]  as const;
	static plugin = "exp_groups" as const;

	static permission(user: IControllerUser, message: MessageRequest) {
		if (typeof message.data === "object" && message.data !== null) {
			const data = message.data as Static<typeof PermissionGroupEditEvent.jsonSchema>;
			if (data.type === "add_permissions" || data.type === "remove_permissions") {
				user.checkPermission("exp_groups.modify_permissions")
			} else if (data.type === "assign_players") {
				user.checkPermission("exp_groups.assign_players")
			} else {
				throw new PermissionError("Permission denied");
			}
		};
	}

	constructor(
		public src: Address,
		public type: PermissionGroupEditType,
		public group: string,
		public changes: String[],
	) { }

	static jsonSchema = Type.Object({
		"src": Address.jsonSchema,
		"type": StringEnum(["assign_players", "add_permissions", "remove_permissions"]),
		"group": Type.String(),
		"changes": Type.Array(Type.String()),
	});

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(Address.fromJSON(json.src), json.type, json.group, json.changes);
	}
}

export class PermissionStrings {
	constructor(
		public instanceId: PermissionInstanceId,
		public permissions: Set<GamePermission>,
		public updatedAtMs: number = 0,
		public isDeleted: boolean = false,
	) {
	}

	static jsonSchema = Type.Object({
		instanceId: PermissionInstanceIdSchema,
		permissions: Type.Array(Type.String()),
		updatedAtMs: Type.Optional(Type.Number()),
		isDeleted: Type.Optional(Type.Boolean()),
	});

	static fromJSON(json: Static<typeof PermissionStrings.jsonSchema>) {
		return new PermissionStrings(
			json.instanceId,
			new Set(json.permissions),
			json.updatedAtMs,
			json.isDeleted
		);
	}

	toJSON() {
		return {
			instanceId: this.instanceId,
			permissions: [...this.permissions.values()],
			updatedAtMs: this.updatedAtMs > 0 ? this.updatedAtMs : undefined,
			isDeleted: this.isDeleted ? this.isDeleted : undefined,
		}
	}

	get id() {
		return this.instanceId
	}
}

export class PermissionStringsUpdate {
	declare ["constructor"]: typeof PermissionStringsUpdate;
	static type = "event" as const;
	static src = ["instance", "controller"] as const;
	static dst = ["controller", "control"] as const;
	static plugin = "exp_groups" as const;
	static permission = "exp_groups.list.subscribe";

	constructor(
		public updates: PermissionStrings[],
	) { }

	static jsonSchema = Type.Object({
		"updates": Type.Array(PermissionStrings.jsonSchema),
	});

	static fromJSON(json: Static<typeof this.jsonSchema>) {
		return new this(
			json.updates.map(update => PermissionStrings.fromJSON(update))
		);
	}
}
