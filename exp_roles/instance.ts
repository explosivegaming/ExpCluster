import type { InstancePluginContext } from "@clusterio/host";
import * as lib from "@clusterio/lib";
import * as messages from "./messages.js";

/** Sent by the lua side when roles are changed in game. */
export type IpcAssignmentUpdate = {
	name: string,
	assign: number[] | undefined,
	unassign: number[] | undefined,
};

export default async function (context: InstancePluginContext) {
	const { instance, logger, plugin } = context;
	const syncMode = () => instance.config.get("exp_roles.sync_mode");

	async function luaSend(receiver: string, json: any) {
		await instance.sendRcon(
			`/sc exp_roles.${receiver}(helpers.json_to_table[=[${JSON.stringify(json)}]=])`, true
		);
	}

	instance.handle(messages.RoleUpdatedEvent, async event => {
		if (syncMode() !== "disabled") {
			await luaSend("receive_role_updates", event.updates.map(role => role.toJSON()));
		}
	});

	instance.handle(messages.AssignmentUpdatedEvent, async event => {
		if (syncMode() !== "disabled") {
			await luaSend("receive_assignment_updates", event.updates.map(a => a.toJSON()));
		}
	});

	instance.server.handle("exp_roles:assignment_update", async (event: IpcAssignmentUpdate) => {
		if (syncMode() !== "bidirectional") {
			return;
		}

		const assign = event.assign ?? [];
		try {
			await instance.sendTo("controller", new messages.AssignmentUpdateRequest(
				event.name, assign, event.unassign ?? [],
			));
		} catch (err: any) {
			// The roles were already applied in game, so they have to be taken
			// back off again now that the controller has refused them
			logger.warn(`Role change for ${event.name} was rejected: ${err.message}`);
			if (assign.length) {
				await luaSend("reject_assignment", { name: event.name, role_ids: assign });
			}
		}
	});

	instance.hooks.instanceConfigFieldChanged.attach(plugin.name, async (field, curr) => {
		if (field === "exp_roles.sync_mode") {
			await luaSend("set_emit_events", curr === "bidirectional");
		}
	});

	instance.hooks.start.attach(plugin.name, async () => {
		if (syncMode() === "disabled") {
			return;
		}

		// Date.now() is used because the lua state is initialised from the full
		// list below, so only updates made after this point are of interest
		const subscribedAtMs = Date.now();
		await instance.sendTo("controller", new lib.SubscriptionRequest(
			`exp_roles:${messages.RoleUpdatedEvent.name}`, true, subscribedAtMs
		));
		await instance.sendTo("controller", new lib.SubscriptionRequest(
			`exp_roles:${messages.AssignmentUpdatedEvent.name}`, true, subscribedAtMs
		));

		const [roles, assignments] = await Promise.all([
			instance.sendTo("controller", new messages.RoleListRequest()),
			instance.sendTo("controller", new messages.AssignmentListRequest()),
		]);

		if (!roles.some(role => role.isDefault)) {
			logger.warn("No default role is set on the controller, players will hold no roles in game");
		}

		await luaSend("initialise", {
			...messages.encodeRolesForLua(roles),
			assignments: assignments.map(assignment => assignment.toJSON()),
		});
		await luaSend("set_emit_events", syncMode() === "bidirectional");
	});
}
