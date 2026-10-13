import type { InstancePluginContext } from "@clusterio/host";
import * as lib from "@clusterio/lib";
import * as messages from "./messages.js";

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

export default async function (context: InstancePluginContext) {
    const { instance, plugin } = context;
    const syncMode = () => instance.config.get("exp_groups.sync_mode");
    // Once only, don't send permissions for these groups
    // This is used for groups created on this instance that only need the controller generated id
    const skipSendingPermissions = new Set<string>();
    // This is used for groups updated / deleted on this instance to stop cycles
    const skipSendingUpdate = new Set<number>();
    // Track known online players so that we only apply assignment updates for them
    const onlinePlayers = new Set<string>();

    async function luaSend(receiver: string, json: any) {
        await instance.sendRcon(`/sc exp_groups.${receiver}(helpers.json_to_table[=[${JSON.stringify(json)}]=])`, true)
    }

    async function updatePlayerAssignmentSubscription(playerName: string, action: "subscribe" | "unsubscribe") {
        await instance.sendTo("controller", new lib.SubscriptionRequest(
            `exp_groups:${messages.ResolvedAssignmentUpdatedEvent.name}`, action, 0, lib.SubscriptionFilters.fromShorthand(playerName)
        ));
    }

    instance.handle(messages.GroupUpdatedEvent, async event => {
        if (syncMode() === "disabled") {
            return;
        }

        for (const group of event.updates) {
            if (skipSendingUpdate.has(group.id)) {
                skipSendingUpdate.delete(group.id);
                continue;
            }

            const json = group.toJSON();
            if (skipSendingPermissions.has(group.name)) {
                skipSendingPermissions.delete(group.name);
                delete (json as any).permissions;
            }

            await luaSend("receive_group_update", json);
        }
    });

    instance.handle(messages.ResolvedAssignmentUpdatedEvent, async event => {
        if (syncMode() === "disabled") {
            return;
        }

        for (const assignment of event.updates) {
            if (onlinePlayers.has(assignment.name)) {
                await luaSend("receive_assignment_update", assignment);
            }
        }
    });

    instance.server.handle("exp_group:group_updated", async (event: IpcGroupUpdated) => {
        const permissions = new messages.GroupPermissions(
            event.permissions.is_blacklist,
            event.permissions.permissions ?? [],
        )

        if (event.group_id === undefined) {
            skipSendingPermissions.add(event.group_name);
            await instance.sendTo("controller",
                new messages.GroupCreateRequest(event.group_name, permissions),
            );
        } else {
            skipSendingUpdate.add(event.group_id);
            await instance.sendTo("controller", new messages.GroupUpdateRequest(
                new messages.GroupRecord(event.group_id, event.group_name, permissions),
            ));
        }
    });

    instance.server.handle("exp_group:group_deleted", async (event: IpcGroupDeleted) => {
        if (event.group_id === undefined) {
            return;
        }
        skipSendingUpdate.add(event.group_id);
        await instance.sendTo("controller", new messages.GroupDeleteRequest(event.group_id));
    });

    instance.server.handle("exp_group:player_assignments", async (event: IpcPlayerAssignments) => {
        await Promise.all(
            Object.entries(event.assignments).map(([playerName, groupId]) =>
                instance.sendTo("controller",
                    new messages.AssignmentUpdateRequest(new messages.AssignmentRecord(playerName, groupId)),
                )
            )
        );
    });

    const hooks = instance.hooks;
    hooks.instanceConfigFieldChanged.attach(plugin.name, async (field, curr) => {
        if (field === "exp_groups.sync_mode") {
            await luaSend("set_emit_events", curr == "bidirectional")
        }
    });

    hooks.start.attach(plugin.name, async () => {
        // We use Date.now() because we need to manually initialise the groups on the lua side
        await instance.sendTo("controller", new lib.SubscriptionRequest(
            `exp_groups:${messages.GroupUpdatedEvent.name}`, "subscribe", Date.now()
        ));
        const groups = await instance.sendTo("controller", new messages.GroupListRequest())
        if (syncMode() !== "disabled") {
            await luaSend("initialise_groups", groups);
        }
        await luaSend("set_emit_events", syncMode() == "bidirectional")
    });

    hooks.playerEvent.attach(plugin.name, async (event: lib.PlayerEvent) => {
        switch(event.type) {
            case "join":
                onlinePlayers.add(event.name);
                await updatePlayerAssignmentSubscription(event.name, "subscribe");
                break;
            case "leave":
                onlinePlayers.delete(event.name);
                await updatePlayerAssignmentSubscription(event.name, "unsubscribe");
                break;
        }
    });
}
