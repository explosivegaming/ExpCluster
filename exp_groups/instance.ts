import { BaseInstancePlugin } from "@clusterio/host";
import * as lib from "@clusterio/lib";
import * as messages from "./messages";

export type IpcGroupUpdated = {
	group_name: string,
	group_id: number | undefined,
	permissions: { is_blacklist: boolean, permissions: string[] | undefined },
};

export type IpcGroupDeleted = {
	group_name: string,
	group_id: number | undefined,
};

export type IpcPlayerAssignments = {
	assignments: Record<string, number>,
};

export class InstancePlugin extends BaseInstancePlugin {
    // Once only, don't send permissions for these groups
    // This is used for groups created on this instance that only need the controller generated id
    skipSendingPermissions = new Set<string>(); 
    // This is used for groups updated / deleted on this instance to stop cycles
    skipSendingUpdate = new Set<number>(); 
    // Track known online players so that we only apply assignment updates for them
    onlinePlayers = new Set<string>();

    async init() {
        this.instance.handle(messages.GroupUpdatedEvent, this.handleGroupUpdatedEvent.bind(this));
        this.instance.handle(messages.ResolvedAssignmentUpdatedEvent, this.handleResolvedAssignmentUpdatedEvent.bind(this));
        this.instance.server.handle(`exp_group:group_updated`, this.handleGroupUpdatedIPC.bind(this))
        this.instance.server.handle(`exp_group:group_deleted`, this.handleGroupDeletedIPC.bind(this))
        this.instance.server.handle(`exp_group:player_assignments`, this.handlePlayerAssignmentsIPC.bind(this))
    }

    async onInstanceConfigFieldChanged(field: string, curr: unknown, prev: unknown) {
        switch(field) {
            case "exp_groups.sync_mode":
                await this.luaSetEmitEvents(curr == "bidirectional")
                break;
        }
    }

    async onStart() {
        // We use Date.now() because we need to manually initialise the groups on the lua side
        await this.instance.sendTo("controller", new lib.SubscriptionRequest(
            `exp_groups:${messages.GroupUpdatedEvent.name}`, "subscribe", Date.now()
        ));
        const groups = await this.instance.sendTo("controller", new messages.GroupListRequest())
        await this.luaSendInitialGroups(groups);
        await this.luaSetEmitEvents(this.instance.config.get("exp_groups.sync_mode") == "bidirectional")
    }

    async onPlayerEvent(event: lib.PlayerEvent) {
        switch(event.type) {
            case "join":
                this.onlinePlayers.add(event.name);
                await this.subscribePlayerAssignment(event.name);
                break;
            case "leave":
                this.onlinePlayers.delete(event.name);
                await this.unsubscribePlayerAssignment(event.name);
                break;
        }
    }

    async handleGroupUpdatedEvent(event: messages.GroupUpdatedEvent) {
        for (const group of event.updates) {
            await this.luaSendGroupUpdate(group);
        }
    }

    async handleResolvedAssignmentUpdatedEvent(event: messages.ManualAssignmentUpdatedEvent) {
        for (const assignment of event.updates) {
            if (this.onlinePlayers.has(assignment.name)) {
                await this.luaSendAssignmentUpdate(assignment);
            }
        }
    }

    async handleGroupUpdatedIPC(event: IpcGroupUpdated) {
        const permissions = new messages.GroupPermissions(
            event.permissions.is_blacklist,
            event.permissions.permissions ?? [],
        )

        if (event.group_id === undefined) {
            this.skipSendingPermissions.add(event.group_name);
            await this.instance.sendTo("controller",
                new messages.GroupCreateRequest(event.group_name, permissions),
            );
        } else {
            this.skipSendingUpdate.add(event.group_id);
            await this.instance.sendTo("controller", new messages.GroupUpdateRequest(
                new messages.GroupRecord(event.group_id, event.group_name, permissions),
            ));
        }
    }

    async handleGroupDeletedIPC(event: IpcGroupDeleted) {
        if (event.group_id === undefined) {
            return;
        }
        this.skipSendingUpdate.add(event.group_id);
        await this.instance.sendTo("controller", new messages.GroupDeleteRequest(event.group_id));
    }

    async handlePlayerAssignmentsIPC(event: IpcPlayerAssignments) {
        await Promise.all(
            Object.entries(event.assignments).map(([playerName, groupId]) =>
                this.instance.sendTo("controller",
                    new messages.AssignmentUpdateRequest(new messages.AssignmentRecord(playerName, groupId)),
                )
            )
        );
    }

    async subscribePlayerAssignment(playerName: string) {
        await this.instance.sendTo("controller", new lib.SubscriptionRequest(
            `exp_groups:${messages.ResolvedAssignmentUpdatedEvent.name}`, "subscribe", 0, lib.SubscriptionFilters.fromShorthand(playerName)
        ));
    }

    async unsubscribePlayerAssignment(playerName: string) {
        await this.instance.sendTo("controller", new lib.SubscriptionRequest(
            `exp_groups:${messages.ResolvedAssignmentUpdatedEvent.name}`, "unsubscribe", 0, lib.SubscriptionFilters.fromShorthand(playerName)
        ));
    }

    async luaSendInitialGroups(groups: messages.GroupRecord[]) {
        if (this.instance.config.get("exp_groups.sync_mode") === "disabled") {
            return;
        }
        await this.luaSend("initialise_groups", groups);
    }

    async luaSendGroupUpdate(group: messages.GroupRecord) {
        if (this.instance.config.get("exp_groups.sync_mode") === "disabled") {
            return;
        }

        if (this.skipSendingUpdate.has(group.id)) {
            this.skipSendingUpdate.delete(group.id);
            return;
        }

        const json = group.toJSON();
        if (this.skipSendingPermissions.has(group.name)) {
            this.skipSendingPermissions.delete(group.name);
            delete (json as any).permissions;
        }

        await this.luaSend("receive_group_update", json);
    }

    async luaSendAssignmentUpdate(assignment: messages.AssignmentRecord) {
        if (this.instance.config.get("exp_groups.sync_mode") === "disabled") {
            return;
        }
        await this.luaSend("receive_assignment_update", assignment);
    }

    async luaSetEmitEvents(emitEvents: boolean) {
        await this.luaSend("set_emit_events", emitEvents);
    }

    async luaSend(receiver: string, json: any) {
        await this.instance.sendRcon(`/sc exp_groups.${receiver}(helpers.json_to_table[=[${JSON.stringify(json)}]=])`, true)
    }
}
