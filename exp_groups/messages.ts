import * as lib from "@clusterio/lib";
import { Type, Static } from "@sinclair/typebox";

/*
    Data records
*/

export class GroupPermissions {
    constructor(
        public isBlacklist: boolean,
        public permissions: string[],
    ) {}

    static jsonSchema = Type.Object({
        is_blacklist: Type.Boolean(),
        permissions: Type.Array(Type.String()),
    });

    toJSON(): Static<typeof GroupPermissions.jsonSchema> {
        return {
            is_blacklist: this.isBlacklist,
            permissions: this.permissions,
        };
    }

    static fromJSON(json: Static<typeof this.jsonSchema>) {
        return new this(
            json.is_blacklist,
            json.permissions,
        );
    }
}

export class GroupRecord {
    constructor(
        public id: number,
        public name: string,
        public permissions: GroupPermissions,
        public updatedAtMs: number = 0,
        public isDeleted: boolean = false,
    ) {}

    static jsonSchema = Type.Object({
        id: Type.Integer(),
        name: Type.String(),
        permissions: GroupPermissions.jsonSchema,
        updated_at_ms: Type.Optional(Type.Number()),
        is_deleted: Type.Optional(Type.Boolean()),
    });

    toJSON() {
        let json: Static<typeof GroupRecord.jsonSchema> = {
            id: this.id,
            name: this.name,
            permissions: this.permissions.toJSON(),
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
            GroupPermissions.fromJSON(json.permissions),
            json.updated_at_ms ?? 0,
            json.is_deleted ?? false,
        );
    }
}

export class AssignmentRecord {
    constructor(
        public name: string,
        public groupId: number,
        public updatedAtMs: number = 0,
        public isDeleted: boolean = false,
    ) {}

    static jsonSchema = Type.Object({
        name: Type.String(),
        group_id: Type.Integer(),
        updated_at_ms: Type.Optional(Type.Number()),
        is_deleted: Type.Optional(Type.Boolean()),
    });

    toJSON(): Static<typeof AssignmentRecord.jsonSchema> {
        let json: Static<typeof AssignmentRecord.jsonSchema> = {
            name: this.name,
            group_id: this.groupId,
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
            json.group_id,
            json.updated_at_ms ?? 0,
            json.is_deleted ?? false,
        );
    }
}

export class RoleMappingRecord {
    constructor(
        public id: number,
        public roleIds: Set<number>,
        public groupId: number,
        public priority: number,
        public enabled: boolean,
        public updatedAtMs: number = 0,
        public isDeleted: boolean = false,
    ) {}

    static jsonSchema = Type.Object({
        id: Type.Integer(),
        role_ids: Type.Array(Type.Integer()),
        group_id: Type.Integer(),
        priority: Type.Number(),
        enabled: Type.Boolean(),
        updated_at_ms: Type.Optional(Type.Number()),
        is_deleted: Type.Optional(Type.Boolean()),
    });

    toJSON(): Static<typeof RoleMappingRecord.jsonSchema> {
        let json: Static<typeof RoleMappingRecord.jsonSchema> = {
            id: this.id,
            role_ids: [...this.roleIds],
            group_id: this.groupId,
            priority: this.priority,
            enabled: this.enabled,
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
            new Set(json.role_ids),
            json.group_id,
            json.priority,
            json.enabled,
            json.updated_at_ms ?? 0,
            json.is_deleted ?? false,
        );
    }
}

/*
    Update events
*/

export class GroupUpdatedEvent {
    declare ["constructor"]: typeof GroupUpdatedEvent;
    static plugin = "exp_groups" as const;
    static type = "event" as const;
    static src = "controller" as const;
    static dst = ["control", "instance"] as const;
    static permission = "exp_groups.group.subscribe" as const;

    constructor(
        public updates: GroupRecord[],
    ) {}

    static jsonSchema = Type.Object({
        updates: Type.Array(GroupRecord.jsonSchema),
    });

    toJSON() {
        return { updates: this.updates.map(group => group.toJSON()) };
    }

    static fromJSON(json: Static<typeof this.jsonSchema>) {
        return new this(json.updates.map(group => GroupRecord.fromJSON(group)));
    }
}

export class AssignmentUpdatedEvent {
    declare ["constructor"]: typeof AssignmentUpdatedEvent;
    static plugin = "exp_groups" as const;
    static type = "event" as const;
    static src = "controller" as const;
    static dst = ["control", "instance"] as const;
    static permission = "exp_groups.assignment.subscribe" as const;

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

export class RoleMappingUpdatedEvent {
    declare ["constructor"]: typeof RoleMappingUpdatedEvent;
    static plugin = "exp_groups" as const;
    static type = "event" as const;
    static src = "controller" as const;
    static dst = "control" as const;
    static permission = "exp_groups.role_mapping.subscribe" as const;

    constructor(
        public updates: RoleMappingRecord[],
    ) {}

    static jsonSchema = Type.Object({
        updates: Type.Array(RoleMappingRecord.jsonSchema),
    });

    toJSON() {
        return { updates: this.updates.map(roleMapping => roleMapping.toJSON()) };
    }

    static fromJSON(json: Static<typeof this.jsonSchema>) {
        return new this(json.updates.map(roleMapping => RoleMappingRecord.fromJSON(roleMapping)));
    }
}

/*
    Group requests
*/

export class GroupCreateRequest {
    declare ["constructor"]: typeof GroupCreateRequest;
    static plugin = "exp_groups" as const;
    static type = "request" as const;
    static src = ["control", "instance"] as const;
    static dst = "controller" as const;
    static permission = "exp_groups.group.create" as const;

    constructor(
        public name: string,
        public permissions: GroupPermissions,
    ) {}

    static jsonSchema = Type.Object({
        name: Type.String(),
        permissions: GroupPermissions.jsonSchema,
    });

    toJSON() {
        return {
            name: this.name,
            permissions: this.permissions.toJSON(),
        };
    }

    static fromJSON(json: Static<typeof this.jsonSchema>) {
        return new this(
            json.name,
            GroupPermissions.fromJSON(json.permissions),
        );
    }
}

export class GroupUpdateRequest {
    declare ["constructor"]: typeof GroupUpdateRequest;
    static plugin = "exp_groups" as const;
    static type = "request" as const;
    static src = ["control", "instance"] as const;
    static dst = "controller" as const;
    static permission = "exp_groups.group.update" as const;

    constructor(
        public group: GroupRecord,
    ) {}

    static jsonSchema = Type.Object({
        group: GroupRecord.jsonSchema,
    });

    toJSON() {
        return {
            group: this.group.toJSON(),
        };
    }

    static fromJSON(json: Static<typeof this.jsonSchema>) {
        return new this(
            GroupRecord.fromJSON(json.group),
        );
    }
}

export class GroupDeleteRequest {
    declare ["constructor"]: typeof GroupDeleteRequest;
    static plugin = "exp_groups" as const;
    static type = "request" as const;
    static src = ["control", "instance"] as const;
    static dst = "controller" as const;
    static permission = "exp_groups.group.delete" as const;

    constructor(
        public groupId: number,
    ) {}

    static jsonSchema = Type.Object({
        group_id: Type.Integer(),
    });

    toJSON() {
        return {
            group_id: this.groupId,
        };
    }

    static fromJSON(json: Static<typeof this.jsonSchema>) {
        return new this(json.group_id);
    }
}

export class GroupGetRequest {
    declare ["constructor"]: typeof GroupGetRequest;
    static plugin = "exp_groups" as const;
    static type = "request" as const;
    static src = ["control", "instance"] as const;
    static dst = "controller" as const;
    static permission = "exp_groups.group.get" as const;
    static Response = GroupRecord;

    constructor(
        public groupId: number,
    ) {}

    static jsonSchema = Type.Object({
        group_id: Type.Integer(),
    });

    toJSON() {
        return {
            group_id: this.groupId,
        };
    }

    static fromJSON(json: Static<typeof this.jsonSchema>) {
        return new this(json.group_id);
    }
}

export class GroupListRequest {
    declare ["constructor"]: typeof GroupListRequest;
    static plugin = "exp_groups" as const;
    static type = "request" as const;
    static src = ["control", "instance"] as const;
    static dst = "controller" as const;
    static permission = "exp_groups.group.list" as const;
    static Response = lib.jsonArray(GroupRecord);

    constructor() {}
}

/*
    Assignment requests
*/

export class AssignmentCreateRequest {
    declare ["constructor"]: typeof AssignmentCreateRequest;
    static plugin = "exp_groups" as const;
    static type = "request" as const;
    static src = ["control", "instance"] as const;
    static dst = "controller" as const;
    static permission = "exp_groups.assignment.create" as const;

    constructor(
        public name: string,
        public groupId: number,
    ) {}

    static jsonSchema = Type.Object({
        name: Type.String(),
        group_id: Type.Integer(),
    });

    toJSON() {
        return {
            name: this.name,
            group_id: this.groupId,
        };
    }

    static fromJSON(json: Static<typeof this.jsonSchema>) {
        return new this(json.name, json.group_id);
    }
}

export class AssignmentUpdateRequest {
    declare ["constructor"]: typeof AssignmentUpdateRequest;
    static plugin = "exp_groups" as const;
    static type = "request" as const;
    static src = ["control", "instance"] as const;
    static dst = "controller" as const;
    static permission = "exp_groups.assignment.update" as const;

    constructor(
        public assignment: AssignmentRecord,
    ) {}

    static jsonSchema = Type.Object({
        assignment: AssignmentRecord.jsonSchema,
    });

    toJSON() {
        return {
            assignment: this.assignment.toJSON(),
        };
    }

    static fromJSON(json: Static<typeof this.jsonSchema>) {
        return new this(
            AssignmentRecord.fromJSON(json.assignment),
        );
    }
}

export class AssignmentDeleteRequest {
    declare ["constructor"]: typeof AssignmentDeleteRequest;
    static plugin = "exp_groups" as const;
    static type = "request" as const;
    static src = ["control", "instance"] as const;
    static dst = "controller" as const;
    static permission = "exp_groups.assignment.delete" as const;

    constructor(
        public name: string,
    ) {}

    static jsonSchema = Type.Object({
        name: Type.String(),
    });

    toJSON() {
        return {
            name: this.name,
        };
    }

    static fromJSON(json: Static<typeof this.jsonSchema>) {
        return new this(json.name);
    }
}

export class AssignmentGetRequest {
    declare ["constructor"]: typeof AssignmentGetRequest;
    static plugin = "exp_groups" as const;
    static type = "request" as const;
    static src = ["control", "instance"] as const;
    static dst = "controller" as const;
    static permission = "exp_groups.assignment.get" as const;
    static Response = AssignmentRecord;

    constructor(
        public name: string,
    ) {}

    static jsonSchema = Type.Object({
        name: Type.String(),
    });

    toJSON() {
        return {
            name: this.name,
        };
    }

    static fromJSON(json: Static<typeof this.jsonSchema>) {
        return new this(json.name);
    }
}

export class AssignmentListRequest {
    declare ["constructor"]: typeof AssignmentListRequest;
    static plugin = "exp_groups" as const;
    static type = "request" as const;
    static src = ["control", "instance"] as const;
    static dst = "controller" as const;
    static permission = "exp_groups.assignment.list" as const;
    static Response = lib.jsonArray(AssignmentRecord);

    constructor() {}
}

/*
    Role mapping requests
*/

export class RoleMappingCreateRequest {
    declare ["constructor"]: typeof RoleMappingCreateRequest;
    static plugin = "exp_groups" as const;
    static type = "request" as const;
    static src = ["control", "instance"] as const;
    static dst = "controller" as const;
    static permission = "exp_groups.role_mapping.create" as const;

    constructor(
        public roleIds: number[],
        public groupId: number,
        public priority: number,
        public enabled: boolean,
    ) {}

    static jsonSchema = Type.Object({
        role_ids: Type.Array(Type.Integer()),
        group_id: Type.Integer(),
        priority: Type.Number(),
        enabled: Type.Boolean(),
    });

    toJSON() {
        return {
            role_ids: this.roleIds,
            group_id: this.groupId,
            priority: this.priority,
            enabled: this.enabled,
        };
    }

    static fromJSON(json: Static<typeof this.jsonSchema>) {
        return new this(
            json.role_ids,
            json.group_id,
            json.priority,
            json.enabled,
        );
    }
}

export class RoleMappingUpdateRequest {
    declare ["constructor"]: typeof RoleMappingUpdateRequest;
    static plugin = "exp_groups" as const;
    static type = "request" as const;
    static src = ["control", "instance"] as const;
    static dst = "controller" as const;
    static permission = "exp_groups.role_mapping.update" as const;

    constructor(
        public roleMapping: RoleMappingRecord,
    ) {}

    static jsonSchema = Type.Object({
        role_mapping: RoleMappingRecord.jsonSchema,
    });

    toJSON() {
        return {
            role_mapping: this.roleMapping.toJSON(),
        };
    }

    static fromJSON(json: Static<typeof this.jsonSchema>) {
        return new this(
            RoleMappingRecord.fromJSON(json.role_mapping),
        );
    }
}

export class RoleMappingDeleteRequest {
    declare ["constructor"]: typeof RoleMappingDeleteRequest;
    static plugin = "exp_groups" as const;
    static type = "request" as const;
    static src = ["control", "instance"] as const;
    static dst = "controller" as const;
    static permission = "exp_groups.role_mapping.delete" as const;

    constructor(
        public id: number,
    ) {}

    static jsonSchema = Type.Object({
        id: Type.Integer(),
    });

    toJSON() {
        return {
            id: this.id,
        };
    }

    static fromJSON(json: Static<typeof this.jsonSchema>) {
        return new this(json.id);
    }
}

export class RoleMappingGetRequest {
    declare ["constructor"]: typeof RoleMappingGetRequest;
    static plugin = "exp_groups" as const;
    static type = "request" as const;
    static src = ["control", "instance"] as const;
    static dst = "controller" as const;
    static permission = "exp_groups.role_mapping.get" as const;
    static Response = RoleMappingRecord;

    constructor(
        public id: number,
    ) {}

    static jsonSchema = Type.Object({
        id: Type.Integer(),
    });

    toJSON() {
        return {
            id: this.id,
        };
    }

    static fromJSON(json: Static<typeof this.jsonSchema>) {
        return new this(json.id);
    }
}

export class RoleMappingListRequest {
    declare ["constructor"]: typeof RoleMappingListRequest;
    static plugin = "exp_groups" as const;
    static type = "request" as const;
    static src = ["control", "instance"] as const;
    static dst = "controller" as const;
    static permission = "exp_groups.role_mapping.list" as const;
    static Response = lib.jsonArray(RoleMappingRecord);

    constructor() {}
}
