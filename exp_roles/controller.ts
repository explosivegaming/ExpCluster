import { BaseControllerPlugin, InstanceRecord } from "@clusterio/controller";
import * as lib from "@clusterio/lib";
import * as messages from "./messages";
import * as path from "node:path";

export class ControllerPlugin extends BaseControllerPlugin {
	roleMeta!: lib.SubscribableDatastore<messages.RoleMetaRecord>;

	async init() {
		const databaseDirectory = this.controller.config.get("controller.database_directory");

		this.roleMeta = new lib.SubscribableDatastore(
			...await new lib.JsonIdDatastoreProvider(
				path.join(databaseDirectory, "exp_roles", "role_meta.json"),
				messages.RoleMetaRecord.fromJSON.bind(messages.RoleMetaRecord),
			).bootstrap()
		);

		// The datastore can be out of step with the roles, either because the
		// plugin was installed after they were created or because it was
		// uninstalled while they were deleted
		this.ensureRoleMeta();
		this.sweepRoleMeta();
		this.applyAutoAssign();

		this.controller.subscriptions.handle(messages.RoleUpdatedEvent, this.handleRoleSubscription.bind(this));
		this.controller.subscriptions.handle(
			messages.AssignmentUpdatedEvent, this.handleAssignmentSubscription.bind(this)
		);

		this.roleMeta.on("update", this.roleMetaUpdated.bind(this));
		this.controller.roles.on("update", this.rolesUpdated.bind(this));
		this.controller.users.records.on("update", this.usersUpdated.bind(this));

		this.controller.handle(messages.RoleListRequest, this.handleRoleListRequest.bind(this));
		this.controller.handle(messages.RoleMetaUpdateRequest, this.handleRoleMetaUpdateRequest.bind(this));

		this.controller.handle(messages.AssignmentListRequest, this.handleAssignmentListRequest.bind(this));
		this.controller.handle(messages.AssignmentUpdateRequest, this.handleAssignmentUpdateRequest.bind(this));
	}

	async onShutdown() {
		await this.roleMeta.save();
	}

	/*
		Role properties
	*/

	/** Create properties for any role which does not have them yet, ordered after every existing role. */
	ensureRoleMeta() {
		const created = [];
		let nextOrder = 0;
		for (const meta of this.roleMeta.values()) {
			nextOrder = Math.max(nextOrder, meta.order);
		}

		for (const role of this.controller.roles.values()) {
			if (!this.roleMeta.has(role.id)) {
				nextOrder += 1;
				created.push(new messages.RoleMetaRecord(role.id, nextOrder));
			}
		}

		if (created.length) {
			this.roleMeta.setMany(created);
		}

		return created;
	}

	/**
	 * Delete properties left behind by roles which no longer exist.
	 *
	 * Without this they would be picked up by whichever role is next given the
	 * same id, which happens when a role is deleted while the plugin is not
	 * running.
	 */
	sweepRoleMeta() {
		const orphaned = [];
		for (const meta of this.roleMeta.valuesMutable()) {
			if (!this.controller.roles.has(meta.id)) {
				orphaned.push(meta);
			}
		}

		if (orphaned.length) {
			this.roleMeta.deleteMany(orphaned);
		}

		return orphaned;
	}

	/** Combine a clusterio role with its in game properties. */
	buildRoleRecord(role: Readonly<lib.Role>) {
		const meta = this.roleMeta.get(role.id) ?? new messages.RoleMetaRecord(role.id, role.id);
		return new messages.RoleRecord(
			role.id,
			role.name,
			[...role.permissions],
			meta,
			role.id === this.controller.config.get("controller.default_role_id"),
			Math.max(role.updatedAtMs, meta.updatedAtMs),
			role.isDeleted,
		);
	}

	async onControllerConfigFieldChanged(field: string, curr: unknown, prev: unknown) {
		switch (field) {
			// Which role is the default is carried on the role records themselves
			case "controller.default_role_id":
				this.controller.subscriptions.broadcast(new messages.RoleUpdatedEvent(this.listRoleRecords()));
				break;
		}
	}

	/** Every role which currently exists, in the form sent to instances. */
	listRoleRecords() {
		return [...this.controller.roles.values()].map(role => this.buildRoleRecord(role));
	}

	async handleRoleListRequest() {
		return this.listRoleRecords();
	}

	async handleRoleMetaUpdateRequest(request: messages.RoleMetaUpdateRequest) {
		const meta = request.meta;
		if (!this.controller.roles.has(meta.id)) {
			throw new lib.RequestError(`Role with ID ${meta.id} does not exist`);
		}

		this.roleMeta.set(meta);
	}

	/** A clusterio role was created, changed or deleted. */
	rolesUpdated(roles: lib.Role[]) {
		const created = this.ensureRoleMeta();
		this.sweepRoleMeta();

		// Newly created properties broadcast on their own through roleMetaUpdated
		const createdIds = new Set(created.map(meta => meta.id));
		const updates = roles.filter(role => !createdIds.has(role.id)).map(role => this.buildRoleRecord(role));
		if (updates.length) {
			this.controller.subscriptions.broadcast(new messages.RoleUpdatedEvent(updates));
		}

		this.applyAutoAssign();
	}

	/** The in game properties of a role changed. */
	roleMetaUpdated(metas: messages.RoleMetaRecord[]) {
		const updates = [];
		for (const meta of metas) {
			const role = this.controller.roles.get(meta.id);
			// A deleted role broadcasts through rolesUpdated instead
			if (role) {
				updates.push(this.buildRoleRecord(role));
			}
		}

		if (updates.length) {
			this.controller.subscriptions.broadcast(new messages.RoleUpdatedEvent(updates));
		}

		this.applyAutoAssign();
	}

	async handleRoleSubscription(request: lib.SubscriptionRequest) {
		const roles = this.listRoleRecords().filter(role => role.updatedAtMs > request.lastRequestTimeMs);
		return roles.length ? new messages.RoleUpdatedEvent(roles) : null;
	}

	/*
		Assignments
	*/

	/**
	 * The roles of a user as seen in game.
	 *
	 * The default role is left out because every player has it, which keeps the
	 * assignments to only those users who have been given a role.
	 */
	buildAssignmentRecord(user: Readonly<lib.UserDetails>) {
		const defaultRoleId = this.controller.config.get("controller.default_role_id");
		const roleIds = new Set(user.roleIds);
		if (defaultRoleId !== null) {
			roleIds.delete(defaultRoleId);
		}

		return new messages.AssignmentRecord(
			user.name,
			roleIds,
			user.updatedAtMs,
			user.isDeleted || roleIds.size === 0,
		);
	}

	listAssignmentRecords() {
		const assignments = [];
		for (const user of this.controller.users.records.values()) {
			const assignment = this.buildAssignmentRecord(user);
			if (!assignment.isDeleted) {
				assignments.push(assignment);
			}
		}
		return assignments;
	}

	async handleAssignmentListRequest() {
		return this.listAssignmentRecords();
	}

	usersUpdated(users: lib.UserDetails[]) {
		this.controller.subscriptions.broadcast(
			new messages.AssignmentUpdatedEvent(users.map(user => this.buildAssignmentRecord(user)))
		);

		this.applyAutoAssign(users.map(user => user.name));
	}

	async handleAssignmentSubscription(request: lib.SubscriptionRequest) {
		const assignments = this.listAssignmentRecords()
			.filter(assignment => assignment.updatedAtMs > request.lastRequestTimeMs);
		return assignments.length ? new messages.AssignmentUpdatedEvent(assignments) : null;
	}

	async handleAssignmentUpdateRequest(request: messages.AssignmentUpdateRequest) {
		const user = this.controller.users.getByNameMutable(request.name);
		if (!user) {
			throw new lib.RequestError(`User '${request.name}' does not exist`);
		}

		for (const roleId of [...request.assign, ...request.unassign]) {
			if (!this.controller.roles.has(roleId)) {
				throw new lib.RequestError(`Role with ID ${roleId} does not exist`);
			}
		}

		const roleIds = new Set(user.roleIds);
		for (const roleId of request.assign) {
			roleIds.add(roleId);
		}
		for (const roleId of request.unassign) {
			roleIds.delete(roleId);
		}

		user.set("roleIds", roleIds);
		this.controller.userPermissionsUpdated(user);
	}

	/*
		Automatic assignment
	*/

	/**
	 * Grant roles which are earned by online time across the cluster.
	 *
	 * Roles are only ever granted, never taken away, so a player who earns a
	 * role keeps it even if their statistics are later reduced.
	 *
	 * @param userNames - Users to consider, defaults to every user.
	 */
	applyAutoAssign(userNames?: string[]) {
		const autoAssigned = [...this.roleMeta.values()].filter(
			meta => meta.autoAssignOnlineTimeMs !== null && !meta.isDeleted
		);
		if (!autoAssigned.length) {
			return;
		}

		const blocking = new Set(
			[...this.roleMeta.values()].filter(meta => meta.blockAutoAssign).map(meta => meta.id)
		);

		const users = userNames
			? userNames.map(name => this.controller.users.getByNameMutable(name))
			: [...this.controller.users.valuesMutable()]
		;

		for (const user of users) {
			if (!user || user.isDeleted) {
				continue;
			}
			if ([...user.roleIds].some(roleId => blocking.has(roleId))) {
				continue;
			}

			const onlineTimeMs = user.playerStats.onlineTimeMs;
			const granted = [];
			for (const meta of autoAssigned) {
				if (!user.roleIds.has(meta.id) && onlineTimeMs >= meta.autoAssignOnlineTimeMs!) {
					granted.push(meta.id);
				}
			}

			if (granted.length) {
				// set rather than addRole so that a single update is emitted
				user.set("roleIds", new Set([...user.roleIds, ...granted]));
				this.controller.userPermissionsUpdated(user);
				this.logger.info(
					`Granted ${granted.length} role(s) to ${user.name} from their online time`
				);
			}
		}
	}

	async onPlayerEvent(instance: InstanceRecord, event: lib.PlayerEvent) {
		// Online time is committed to the user record when a player leaves
		if (event.type === "leave") {
			this.applyAutoAssign([event.name]);
		}
	}
}
