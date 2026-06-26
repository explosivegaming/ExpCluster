import { BaseControllerPlugin } from "@clusterio/controller";
import * as lib from "@clusterio/lib";
import * as messages from "./messages";
import * as path from "node:path";

export class ControllerPlugin extends BaseControllerPlugin {
    groups!: lib.SubscribableDatastore<messages.GroupRecord>;
    roleMappings!: lib.SubscribableDatastore<messages.RoleMappingRecord>;
    manualAssignments!: lib.SubscribableDatastore<messages.AssignmentRecord>;
    resolvedAssignments!: lib.SubscribableDatastore<messages.AssignmentRecord>;

    async init() {
        const databaseDirectory = this.controller.config.get("controller.database_directory");

        this.groups = new lib.SubscribableDatastore(
            ...await new lib.JsonIdDatastoreProvider(
                path.join(databaseDirectory, "exp_groups", "groups.json"),
                messages.GroupRecord.fromJSON.bind(messages.GroupRecord),
            ).bootstrap()
        );

        this.roleMappings = new lib.SubscribableDatastore(
            ...await new lib.JsonIdDatastoreProvider(
                path.join(databaseDirectory, "exp_groups", "role_mappings.json"),
                messages.RoleMappingRecord.fromJSON.bind(messages.RoleMappingRecord),
            ).bootstrap()
        );

        this.manualAssignments = new lib.SubscribableDatastore(
            ...await new lib.JsonIdDatastoreProvider(
                path.join(databaseDirectory, "exp_groups", "assignments.json"),
                messages.AssignmentRecord.fromJSON.bind(messages.AssignmentRecord),
            ).bootstrap()
        );

        this.resolvedAssignments = new lib.SubscribableDatastore();

        this.controller.subscriptions.handle(messages.GroupUpdatedEvent, this.handleGroupSubscription.bind(this));
        this.controller.subscriptions.handle(messages.RoleMappingUpdatedEvent, this.handleRoleMappingSubscription.bind(this));
        this.controller.subscriptions.handle(messages.ManualAssignmentUpdatedEvent, this.handleManualAssignmentSubscription.bind(this));
        this.controller.subscriptions.handle(messages.ResolvedAssignmentUpdatedEvent, this.handleResolvedAssignmentSubscription.bind(this));

        this.groups.on("update", this.groupsUpdated.bind(this));
        this.roleMappings.on("update", this.roleMappingsUpdated.bind(this));
        this.manualAssignments.on("update", this.manualAssignmentsUpdated.bind(this));
        this.resolvedAssignments.on("update", this.resolvedAssignmentsUpdated.bind(this));

        this.controller.handle(messages.GroupCreateRequest, this.handleGroupCreateRequest.bind(this));
        this.controller.handle(messages.GroupUpdateRequest, this.handleGroupUpdateRequest.bind(this));
        this.controller.handle(messages.GroupDeleteRequest, this.handleGroupDeleteRequest.bind(this));
        this.controller.handle(messages.GroupGetRequest, this.handleGroupGetRequest.bind(this));
        this.controller.handle(messages.GroupListRequest, this.handleGroupListRequest.bind(this));

        this.controller.handle(messages.AssignmentCreateRequest, this.handleAssignmentCreateRequest.bind(this));
        this.controller.handle(messages.AssignmentUpdateRequest, this.handleAssignmentUpdateRequest.bind(this));
        this.controller.handle(messages.AssignmentDeleteRequest, this.handleAssignmentDeleteRequest.bind(this));
        this.controller.handle(messages.AssignmentGetRequest, this.handleAssignmentGetRequest.bind(this));
        this.controller.handle(messages.AssignmentListRequest, this.handleAssignmentListRequest.bind(this));

        this.controller.handle(messages.RoleMappingCreateRequest, this.handleRoleMappingCreateRequest.bind(this));
        this.controller.handle(messages.RoleMappingUpdateRequest, this.handleRoleMappingUpdateRequest.bind(this));
        this.controller.handle(messages.RoleMappingDeleteRequest, this.handleRoleMappingDeleteRequest.bind(this));
        this.controller.handle(messages.RoleMappingGetRequest, this.handleRoleMappingGetRequest.bind(this));
        this.controller.handle(messages.RoleMappingListRequest, this.handleRoleMappingListRequest.bind(this));
    }

    async onShutdown() {
        await Promise.all([
            this.groups.save(),
            this.manualAssignments.save(),
            this.roleMappings.save(),
        ])
    }

    /*
        Subscriptions
    */

    async groupsUpdated(groups: messages.GroupRecord[]) {
        this.controller.subscriptions.broadcast(new messages.GroupUpdatedEvent(groups));

        // We need to do extra work if the group was deleted
        const deletedGroupIds = groups.filter(g => g.isDeleted).map(g => g.id);
        if (!deletedGroupIds.length) {
            return;
        }

        // Cascade the delete down to affected role mappings
        const mappingsToDelete = [];
        for (const mapping of this.roleMappings.values()) {
            if (deletedGroupIds.includes(mapping.groupId)) {
                mappingsToDelete.push(mapping);
            }
        }
        if (mappingsToDelete.length) {
            this.roleMappings.deleteMany(mappingsToDelete);
        }

        // Cascade the delete down to affected manual assignments
        const affectedPlayers = new Set<string>();
        const assignmentsToDelete = [];
        for (const assignment of this.manualAssignments.values()) {
            if (deletedGroupIds.includes(assignment.groupId)) {
                assignmentsToDelete.push(assignment);
                affectedPlayers.add(assignment.name);
            }
        }
        if (assignmentsToDelete.length) {
            this.manualAssignments.deleteMany(assignmentsToDelete);
        }

        // Find all the affected players who were assigned to this group
        for (const resolved of this.resolvedAssignments.values()) {
            if (deletedGroupIds.includes(resolved.groupId)) {
                affectedPlayers.add(resolved.name);
            }
        }
        if (affectedPlayers.size) {
            this.resolvedAssignments.setMany(await this.computeResolvedAssignments([...affectedPlayers]));
        }
    }

    async handleGroupSubscription(request: lib.SubscriptionRequest) {
        const groups = [...this.groups.values()]
            .filter(group => group.updatedAtMs > request.lastRequestTimeMs);
        return groups.length ? new messages.GroupUpdatedEvent(groups) : null;
    }

    async roleMappingsUpdated(roleMappings: messages.RoleMappingRecord[]) {
        this.controller.subscriptions.broadcast(new messages.RoleMappingUpdatedEvent(roleMappings));

        // Mappings pointing to a deleted group have already been handled
        // But if any are active, then we still must recompute all assignments
        let hasActiveGroup = false;
        for (const roleMapping of roleMappings) {
            const group = this.groups.get(roleMapping.groupId);
            if (group && !group.isDeleted) {
                hasActiveGroup = true;
                break;
            }
        }
        if (!hasActiveGroup) {
            return;
        }

        // Affected players are those without manual assignments
        const affectedPlayers = [];
        for (const resolved of this.resolvedAssignments.values()) {
            if (!this.manualAssignments.has(resolved.name)) {
                affectedPlayers.push(resolved.name);
            }
        }
        if (affectedPlayers.length) {
            this.resolvedAssignments.setMany(await this.computeResolvedAssignments(affectedPlayers));
        }
    }

    async handleRoleMappingSubscription(request: lib.SubscriptionRequest) {
        const mappings = [...this.roleMappings.values()]
            .filter(mapping => mapping.updatedAtMs > request.lastRequestTimeMs);
        return mappings.length ? new messages.RoleMappingUpdatedEvent(mappings) : null;
    }

    async manualAssignmentsUpdated(assignments: messages.AssignmentRecord[]) {
        this.controller.subscriptions.broadcast(new messages.ManualAssignmentUpdatedEvent(assignments));

        // Assignments pointing to a deleted group have already been handled
        const affectedPlayers: string[] = [];
        for (const assignment of assignments) {
            const group = this.groups.get(assignment.groupId);
            if (!group || group.isDeleted) continue;
            affectedPlayers.push(assignment.name);
        }
        if (affectedPlayers.length) {
            this.resolvedAssignments.setMany(await this.computeResolvedAssignments(affectedPlayers));
        }
    }

    async handleManualAssignmentSubscription(request: lib.SubscriptionRequest) {
        const assignments = [...this.resolvedAssignments.values()]
            .filter(a => a.updatedAtMs > request.lastRequestTimeMs);
        return assignments.length ? new messages.ManualAssignmentUpdatedEvent(assignments) : null;
    }

    resolvedAssignmentsUpdated(assignments: messages.AssignmentRecord[]) {
        this.controller.subscriptions.broadcast(
            new messages.ResolvedAssignmentUpdatedEvent(assignments),
            assignments.map(assignment => assignment.name),
        );
    }

    async handleResolvedAssignmentSubscription(request: lib.SubscriptionRequest) {
        // Check for any missing assignments to be computed on demand
        const filters = request.filters.toJSON();
        if (filters.length) {
            const missing = filters.filter(name => !this.resolvedAssignments.has(name));
            if (missing.length) {
                this.resolvedAssignments.setMany(await this.computeResolvedAssignments(missing));
            }
        }

        // Filter the assignments
        const assignments = (filters.length
            ? filters.map(name => this.resolvedAssignments.get(name)).filter(Boolean)
            : [...this.resolvedAssignments.values()]
        ).filter(a => a.updatedAtMs > request.lastRequestTimeMs);

        return assignments.length ? new messages.ResolvedAssignmentUpdatedEvent(assignments) : null;
    }

    /*
        Groups
    */

    async handleGroupListRequest() {
        return [...this.groups.values()];
    }

    async handleGroupCreateRequest(request: messages.GroupCreateRequest) {
        if ([...this.groups.values()].some(g => g.name === request.name)) {
            throw new lib.RequestError(`Group with name '${request.name}' already exists`);
        }

        let id = Math.random() * 2**31 | 0;
        while (this.groups.has(id)) {
            id = Math.random() * 2**31 | 0;
        }

        const group = new messages.GroupRecord(id, request.name, request.permissions);
        this.groups.set(group);
        return group;
    }

    async handleGroupUpdateRequest(request: messages.GroupUpdateRequest) {
        const group = request.group;
        if (group.id === undefined || !this.groups.has(group.id)) {
            throw new lib.RequestError(`Group with ID ${group.id} does not exist`);
        }

        this.groups.set(group);
    }

    async handleGroupDeleteRequest(request: messages.GroupDeleteRequest) {
        const { groupId } = request;

        const group = this.groups.getMutable(groupId);
        if (!group) {
            throw new lib.RequestError(`Group with ID ${groupId} does not exist`);
        }

        this.groups.delete(group);
    }

    async handleGroupGetRequest(request: messages.GroupGetRequest) {
        const group = this.groups.get(request.groupId);
        if (!group) {
            throw new lib.RequestError(`Group with ID ${request.groupId} does not exist`);
        }

        return group;
    }

    /*
        Groups
    */

    async handleAssignmentListRequest() {
        return [...this.manualAssignments.values()];
    }

    async handleAssignmentCreateRequest(request: messages.AssignmentCreateRequest) {
        const { name, groupId } = request;
        if (this.manualAssignments.has(name)) {
            throw new lib.RequestError(`Assignment for '${name}' already exists`);
        }

        const assignment = new messages.AssignmentRecord(name, groupId);
        this.manualAssignments.set(assignment);
        return assignment;
    }

    async handleAssignmentUpdateRequest(request: messages.AssignmentUpdateRequest) {
        const assignment = request.assignment;
        if (!this.manualAssignments.has(assignment.name)) {
            throw new lib.RequestError(`Assignment for '${assignment.name}' does not exist`);
        }

        this.manualAssignments.set(assignment);
    }

    async handleAssignmentDeleteRequest(request: messages.AssignmentDeleteRequest) {
        const { name } = request;

        const assignment = this.manualAssignments.getMutable(name);
        if (!assignment) {
            throw new lib.RequestError(`Assignment for '${name}' does not exist`);
        }

        this.manualAssignments.delete(assignment);
    }

    async handleAssignmentGetRequest(request: messages.AssignmentGetRequest) {
        if (request.resolve) {
            let assignment = this.resolvedAssignments.get(request.name);
            if (!assignment) {
                assignment = await this.computeResolvedAssignment(request.name);
                this.resolvedAssignments.set(assignment);
            }

            return assignment;
        }

        const assignment = this.manualAssignments.get(request.name);
        if (!assignment) {
            throw new lib.RequestError(`Assignment for '${request.name}' does not exist`);
        }

        return assignment;
    }

    /*
        Role mappings
    */

    async handleRoleMappingListRequest() {
        return [...this.roleMappings.values()];
    }

    async handleRoleMappingCreateRequest(request: messages.RoleMappingCreateRequest) {
        let id = Math.random() * 2**31 | 0;
        while (this.roleMappings.has(id)) {
            id = Math.random() * 2**31 | 0;
        }

        let priority = request.priority;
        const existing = new Set([...this.roleMappings.values()].map(m => m.priority));
        while (existing.has(priority)) {
            priority++;
        }

        const roleMapping = new messages.RoleMappingRecord(
            id, new Set(request.roleIds), request.groupId, priority, request.enabled,
        );

        this.roleMappings.set(roleMapping);
        return roleMapping;
    }

    async handleRoleMappingUpdateRequest(request: messages.RoleMappingUpdateRequest) {
        const roleMapping = request.roleMapping;
        if (roleMapping.id === undefined || !this.roleMappings.has(roleMapping.id)) {
            throw new lib.RequestError(`Role mapping with ID ${roleMapping.id} does not exist`);
        }

        const existing = new Set(
            [...this.roleMappings.values()]
                .filter(m => m.id !== roleMapping.id)
                .map(m => m.priority)
        );

        let priority = roleMapping.priority;
        while (existing.has(priority)) {
            priority++;
        }

        this.roleMappings.set(roleMapping);
    }

    async handleRoleMappingDeleteRequest(request: messages.RoleMappingDeleteRequest) {
        const { id } = request;

        const mapping = this.roleMappings.getMutable(id);
        if (!mapping) {
            throw new lib.RequestError(`Role mapping with ID ${id} does not exist`);
        }

        this.roleMappings.delete(mapping);
    }

    async handleRoleMappingGetRequest(request: messages.RoleMappingGetRequest) {
        const mapping = this.roleMappings.get(request.id);
        if (!mapping) {
            throw new lib.RequestError(`Role mapping with ID ${request.id} does not exist`);
        }

        return mapping;
    }

    /*
        Calculating assignments
    */

    async computeResolvedAssignment(playerName: string): Promise<messages.AssignmentRecord> {
        // 1) Manual override
        const manual = this.manualAssignments.get(playerName);
        if (manual) {
            return manual;
        }

        const user = this.controller.users.getByName(playerName);
        const userRoles = user?.roleIds ?? new Set<number>();

        // 2) Role mappings
        let best: messages.RoleMappingRecord | null = null;
        for (const mapping of this.roleMappings.values()) {
            if (!mapping.enabled) continue;

            let matches = true;
            for (const roleId of mapping.roleIds) {
                if (!userRoles.has(roleId)) {
                    matches = false;
                    break;
                }
            }

            if (!matches) continue;

            if (!best || mapping.priority > best.priority) {
                best = mapping;
            }
        }

        if (best) {
            return new messages.AssignmentRecord(playerName, best.groupId);
        }

        // 3) Default (deleted assignment, assigns to 'Default' in game)
        return new messages.AssignmentRecord(playerName, 0, 0, true);
    }

    async computeResolvedAssignments(playerNames: string[]): Promise<messages.AssignmentRecord[]> {
        return Promise.all(playerNames.map(name => this.computeResolvedAssignment(name)));
    }
}
