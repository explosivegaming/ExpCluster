import { BaseInstancePlugin } from "@clusterio/host";
import * as lib from "@clusterio/lib";
import * as messages from "./messages.js";

/** Sent by the lua side when roles are changed in game. */
export type IpcAssignmentUpdate = {
	name: string,
	assign: number[] | undefined,
	unassign: number[] | undefined,
};

export class InstancePlugin extends BaseInstancePlugin {
	async init() {
		this.instance.handle(messages.RoleUpdatedEvent, this.handleRoleUpdatedEvent.bind(this));
		this.instance.handle(messages.AssignmentUpdatedEvent, this.handleAssignmentUpdatedEvent.bind(this));
		this.instance.server.handle("exp_roles:assignment_update", this.handleAssignmentUpdateIPC.bind(this));
	}

	get syncMode() {
		return this.instance.config.get("exp_roles.sync_mode");
	}

	async onInstanceConfigFieldChanged(field: string, curr: unknown, prev: unknown) {
		switch (field) {
			case "exp_roles.sync_mode":
				await this.luaSetEmitEvents(curr === "bidirectional");
				break;
		}
	}

	async onStart() {
		if (this.syncMode === "disabled") {
			return;
		}

		// Date.now() is used because the lua state is initialised from the full
		// list below, so only updates made after this point are of interest
		const subscribedAtMs = Date.now();
		await this.instance.sendTo("controller", new lib.SubscriptionRequest(
			`exp_roles:${messages.RoleUpdatedEvent.name}`, true, subscribedAtMs
		));
		await this.instance.sendTo("controller", new lib.SubscriptionRequest(
			`exp_roles:${messages.AssignmentUpdatedEvent.name}`, true, subscribedAtMs
		));

		const [roles, assignments] = await Promise.all([
			this.instance.sendTo("controller", new messages.RoleListRequest()),
			this.instance.sendTo("controller", new messages.AssignmentListRequest()),
		]);

		if (!roles.some(role => role.isDefault)) {
			this.logger.warn("No default role is set on the controller, players will hold no roles in game");
		}

		await this.luaSend("initialise", {
			...messages.encodeRolesForLua(roles),
			assignments: assignments.map(assignment => assignment.toJSON()),
		});
		await this.luaSetEmitEvents(this.syncMode === "bidirectional");
	}

	async handleRoleUpdatedEvent(event: messages.RoleUpdatedEvent) {
		if (this.syncMode === "disabled") {
			return;
		}

		await this.luaSend("receive_role_updates", event.updates.map(role => role.toJSON()));
	}

	async handleAssignmentUpdatedEvent(event: messages.AssignmentUpdatedEvent) {
		if (this.syncMode === "disabled") {
			return;
		}

		await this.luaSend("receive_assignment_updates", event.updates.map(a => a.toJSON()));
	}

	async handleAssignmentUpdateIPC(event: IpcAssignmentUpdate) {
		if (this.syncMode !== "bidirectional") {
			return;
		}

		const assign = event.assign ?? [];
		try {
			await this.instance.sendTo("controller", new messages.AssignmentUpdateRequest(
				event.name, assign, event.unassign ?? [],
			));
		} catch (err: any) {
			// The roles were already applied in game, so they have to be taken
			// back off again now that the controller has refused them
			this.logger.warn(`Role change for ${event.name} was rejected: ${err.message}`);
			if (assign.length) {
				await this.luaSend("reject_assignment", { name: event.name, role_ids: assign });
			}
			return;
		}
	}

	async luaSetEmitEvents(emitEvents: boolean) {
		await this.luaSend("set_emit_events", emitEvents);
	}

	async luaSend(receiver: string, json: any) {
		await this.instance.sendRcon(
			`/sc exp_roles.${receiver}(helpers.json_to_table[=[${JSON.stringify(json)}]=])`, true
		);
	}
}
