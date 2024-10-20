import * as lib from "@clusterio/lib";
import { BaseInstancePlugin } from "@clusterio/host";
import {
	PermissionGroup, PermissionGroupEditEvent, PermissionGroupEditType,
	PermissionGroupUpdate, PermissionInstanceId, PermissionStrings, PermissionStringsUpdate
} from "./messages";

const rconBase = "/sc local Groups = package.loaded['modules/exp_groups/module_exports'];"

type EditIPC = {
	type: PermissionGroupEditType,
	changes: string[],
	group: string,
};

type CreateIPC = {
	group: string,
	defiantion: [boolean, string[] | {}]
}

type DeleteIPC = {
	group: string,
}

export class InstancePlugin extends BaseInstancePlugin {
	permissions: Set<string> = new Set();
	permissionGroups = new lib.EventSubscriber(PermissionGroupUpdate, this.instance);
	permissionGroupUpdates = new lib.EventSubscriber(PermissionGroupEditEvent, this.instance);
	syncId: PermissionInstanceId = this.instance.config.get("exp_groups.sync_permission_groups") ? "Global" : this.instance.id;

	async init() {
		this.instance.server.handle("exp_groups-permission_group_edit", this.handleEditIPC.bind(this));
		this.instance.server.handle("exp_groups-permission_group_create", this.handleCreateIPC.bind(this));
		this.instance.server.handle("exp_groups-permission_group_delete", this.handleDeleteIPC.bind(this));
	}

	async onStart() {
		// Send the most recent version of the permission string
		const permissionsString = await this.sendRcon(rconBase + "rcon.print(Groups.get_actions_json())");
		this.permissions = new Set(JSON.parse(permissionsString));
		this.instance.sendTo("controller", new PermissionStringsUpdate([
			new PermissionStrings(this.instance.id, this.permissions, Date.now())
		]));

		// Subscribe to get updates for permission groups
		this.permissionGroups.subscribe(this.onPermissionGroupsUpdate.bind(this));
		this.permissionGroupUpdates.subscribe(this.onPermissionGroupUpdate.bind(this));
	}

	async onControllerConnectionEvent(event: any) {
		this.permissionGroups.handleConnectionEvent(event);
	}

	async onInstanceConfigFieldChanged(field: string, curr: unknown, prev: unknown) {
		if (field === "exp_groups.sync_permission_groups") {
			this.syncId = curr ? "Global" : this.instance.id;
			const [snapshot, synced] = this.permissionGroups.getSnapshot();
			if (synced && this.instance.status !== "running") await this.syncPermissionGroups(snapshot.values());
		}
	}

	async onPermissionGroupsUpdate(event: PermissionGroupUpdate | null, synced: boolean) {
		if (!synced || this.instance.status !== "running" || !event?.updates.length) return;
		await this.syncPermissionGroups(event.updates);
	}

	async syncPermissionGroups(groups: Iterable<PermissionGroup>) {
		const updateCommands = [rconBase];
		for (const group of groups) {
			if (group.instanceId === this.syncId && group.updatedAtMs > (this.permissionGroups.values.get(group.id)?.updatedAtMs ?? 0)) {
				if (group.isDeleted) {
					updateCommands.push(`Groups.destroy_group('${group.name}')`);
				} else if (group.permissions.size < this.permissions.size / 2) {
					updateCommands.push(`Groups.get_or_create('${group.name}'):from_json('${JSON.stringify([false, [...this.permissions.values()]])}')`);
				} else {
					const inverted = [...this.permissions.values()].filter(permission => !group.permissions.has(permission));
					updateCommands.push(`Groups.get_or_create('${group.name}'):from_json('${JSON.stringify([true, inverted])}')`);
				}
			}
		}
		await this.sendRcon(updateCommands.join(";"), true);
	}

	async onPermissionGroupUpdate(event: PermissionGroupEditEvent | null, synced: boolean) {
		if (!synced || this.instance.status !== "running" || !event) return;
		if (event.src.equals(lib.Address.fromShorthand({ instanceId: this.instance.id }))) return;
		const getCmd = `Groups.get_or_create('${event.group}')`;
		if (event.type === "add_permissions") {
			await this.sendRcon(rconBase + getCmd + `:allow_actions(Groups.json_to_actions('${JSON.stringify(event.changes)}'))`);
		} else if (event.type === "remove_permissions") {
			await this.sendRcon(rconBase + getCmd + `:disallow_actions(Groups.json_to_actions('${JSON.stringify(event.changes)}'))`);
		} else if (event.type === "assign_players") {
			await this.sendRcon(rconBase + getCmd + `:add_players(game.json_to_table('${JSON.stringify(event.changes)}'))`);
		}
	}

	async handleEditIPC(event: EditIPC) {
		this.logger.info(JSON.stringify(event))
		this.instance.sendTo("controller", new PermissionGroupEditEvent(
			lib.Address.fromShorthand({ instanceId: this.instance.id }),
			event.type, event.group, event.changes
		))
	}

	async handleCreateIPC(event: CreateIPC) {
		this.logger.info(JSON.stringify(event))
		if (!this.permissionGroups.synced) return;
		let [defaultAllow, permissionsRaw] = event.defiantion;
		if (!Array.isArray(permissionsRaw)) {
			permissionsRaw = [] // lua outputs {} for empty arrays
		}
		const permissions = [...this.permissions.values()]
			.filter(permission => defaultAllow !== (permissionsRaw as String[]).includes(permission));
		this.instance.sendTo("controller", new PermissionGroupUpdate([ new PermissionGroup(
			this.syncId, event.group, 0, new Set(), new Set(permissions)
		) ]));
	}

	async handleDeleteIPC(event: DeleteIPC) {
		if (!this.permissionGroups.synced) return;
		const group = [...this.permissionGroups.values.values()]
			.find(group => group.instanceId === this.syncId && group.name === event.group);
		if (group) {
			group.updatedAtMs = Date.now();
			group.isDeleted = true;
			this.instance.sendTo("controller", new PermissionGroupUpdate([ group ]));
		}
	}
}
