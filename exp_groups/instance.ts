import { BaseInstancePlugin } from "@clusterio/host";
import * as lib from "@clusterio/lib";
import * as messages from "./messages";

export type IpcGroupUpdated = {
	group_name: string,
	group_id: number | undefined,
	permissions: { is_blacklist: boolean, permissions: string[] },
};

export type IpcGroupDeleted = {
	group_name: string,
	group_id: number | undefined,
};

export type IpcPlayerAssignments = {
	assignments: Record<string, number>,
};

export class InstancePlugin extends BaseInstancePlugin {
    async init() {
        this.instance.handle(messages.GroupUpdatedEvent, this.handleGroupUpdatedEvent.bind(this));
        this.instance.handle(messages.AssignmentUpdatedEvent, this.handleAssignmentUpdatedEvent.bind(this));
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
        await this.instance.sendTo("controller", new lib.SubscriptionRequest(
            `exp_groups:${messages.GroupUpdatedEvent.name}`, true
        ));
        const groups = await this.instance.sendTo("controller", new messages.GroupListRequest())
        await this.luaSendInitialGroups(groups);
        await this.luaSetEmitEvents(this.instance.config.get("exp_groups.sync_mode") == "bidirectional")
    }

    async onPlayerEvent(event: lib.PlayerEvent) {
        switch(event.type) {
            case "join":
                this.handlePlayerJoin(event.name);
                break;
            case "leave":
                this.handlePlayerLeave(event.name);
                break;
        }
    }

    async handlePlayerJoin(playerName: string) {
        await this.subscribePlayerAssignment(playerName);
        await this.requestPlayerAssignment(playerName);
    }

    async handlePlayerLeave(playerName: string) {
        await this.unsubscribePlayerAssignment(playerName);
    }

    async handleGroupUpdatedEvent(event: messages.GroupUpdatedEvent) {
        for (const group of event.updates) {
            await this.luaSendGroupUpdate(group);
        }
    }

    async handleAssignmentUpdatedEvent(event: messages.AssignmentUpdatedEvent) {
        for (const assignment of event.updates) {
            await this.luaSendAssignmentUpdate(assignment);
        }
    }

    async handleGroupUpdatedIPC(event: IpcGroupUpdated) {
        const permissions = new messages.GroupPermissions(
            event.permissions.is_blacklist,
            event.permissions.permissions,
        );

        if (event.group_id === undefined) {
            await this.instance.sendTo("controller",
                new messages.GroupCreateRequest(event.group_name, permissions),
            );
        } else {
            await this.instance.sendTo("controller", new messages.GroupUpdateRequest(
                new messages.GroupRecord(event.group_id, event.group_name, permissions),
            ));
        }
    }

    async handleGroupDeletedIPC(event: IpcGroupDeleted) {
        if (event.group_id === undefined) {
            return;
        }
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
            `exp_groups:${messages.AssignmentUpdatedEvent.name}`, true, 0, playerName
        ));
    }

    async unsubscribePlayerAssignment(playerName: string) {
        await this.instance.sendTo("controller", new lib.SubscriptionRequest(
            `exp_groups:${messages.AssignmentUpdatedEvent.name}`, false, 0, playerName
        ));
    }

    async requestPlayerAssignment(playerName: string) {
        const assignment = await this.instance.sendTo("controller", new messages.AssignmentGetRequest(playerName));
        await this.luaSendAssignmentUpdate(assignment);
    }

    async luaSendInitialGroups(groups: messages.GroupRecord[]) {
        if (this.instance.config.get("exp_groups.sync_mode") == "disabled") {
            return;
        }
        await this.instance.sendRcon(`/sc exp_groups.initialise_groups(helpers.json_to_table${JSON.stringify(groups)})`)
    }

    async luaSendGroupUpdate(group: messages.GroupRecord) {
        if (this.instance.config.get("exp_groups.sync_mode") == "disabled") {
            return;
        }
        await this.instance.sendRcon(`/sc exp_groups.receive_group_update(helpers.json_to_table${JSON.stringify(group)})`)
    }

    async luaSendAssignmentUpdate(assignment: messages.AssignmentRecord) {
        if (this.instance.config.get("exp_groups.sync_mode") == "disabled") {
            return;
        }
        await this.instance.sendRcon(`/sc exp_groups.initialise_groups(helpers.receive_assignment_update${JSON.stringify(assignment)})`)
    }

    async luaSetEmitEvents(emitEvents: boolean) {
        await this.instance.sendRcon(`/sc exp_groups.set_emit_events(${emitEvents})`)
    }
}
