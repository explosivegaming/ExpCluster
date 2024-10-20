import React, {
	useContext, useEffect, useState,
	useCallback, useSyncExternalStore,
} from "react";

// import {
//
// } from "antd";

import {
	BaseWebPlugin, PageLayout, PageHeader, Control, ControlContext, notifyErrorHandler,
	useInstances,
} from "@clusterio/web_ui";

import { PermissionGroupUpdate, PermissionInstanceId, PermissionStringsUpdate } from "../messages";

import * as lib from "@clusterio/lib";

import { GroupTree } from "./components/groupTree";

function MyTemplatePage() {
	const control = useContext(ControlContext);
	const plugin = control.plugins.get("exp_groups") as WebPlugin;
	const [permissionStrings, permissionStringsSynced] = plugin.usePermissionStrings();
	const [permissionGroups, permissionGroupsSynced] = plugin.usePermissionGroups();
	const [instances, instancesSync] = useInstances();
	
	let [roles, setRoles] = useState<lib.Role[]>([]);

	useEffect(() => {
		control.send(new lib.RoleListRequest()).then(newRoles => {
			setRoles(newRoles);
		}).catch(notifyErrorHandler("Error fetching role list"));
	}, []);

	return <PageLayout nav={[{ name: "exp_groups" }]}>
		<PageHeader title="exp_groups" />
		Permission Strings: {String(permissionStringsSynced)} {JSON.stringify([...permissionStrings.values()])} <br/>
		Permission Groups: {String(permissionGroupsSynced)} {JSON.stringify([...permissionGroups.values()])} <br/>
		Instances: {String(instancesSync)} {JSON.stringify([...instances.values()].map(instance => [instance.id, instance.name]))} <br/>
		Roles: {JSON.stringify([...roles.values()].map(role => [role.id, role.name]))} <br/>
		<GroupTree/>
	</PageLayout>;
}

export class WebPlugin extends BaseWebPlugin {
	permissionStrings = new lib.EventSubscriber(PermissionStringsUpdate, this.control);
	permissionGroups = new lib.EventSubscriber(PermissionGroupUpdate, this.control);

	async init() {
		this.pages = [
			{
				path: "/exp_groups",
				sidebarName: "exp_groups",
				permission: "exp_groups.list",
				content: <MyTemplatePage/>,
			},
		];
	}

	useInstancePermissionStrings(instanceId?: PermissionInstanceId) {
		const [permissionStrings, synced] = this.usePermissionStrings();
		return [instanceId !== undefined ? permissionStrings.get(instanceId) : undefined, synced] as const;
	}
	
	usePermissionStrings() {
		const control = useContext(ControlContext);
		const subscribe = useCallback((callback: () => void) => this.permissionStrings.subscribe(callback), [control]);
		return useSyncExternalStore(subscribe, () => this.permissionStrings.getSnapshot());
	}

	useInstancePermissionGroups(instanceId?: PermissionInstanceId) {
		const [permissionGroups, synced] = this.usePermissionGroups();
		return [instanceId !== undefined ? [...permissionGroups.values()].filter(group => group.instanceId === instanceId) : undefined, synced] as const;
	}
	
	usePermissionGroups() {
		const control = useContext(ControlContext);
		const subscribe = useCallback((callback: () => void) => this.permissionGroups.subscribe(callback), [control]);
		return useSyncExternalStore(subscribe, () => this.permissionGroups.getSnapshot());
	}
}
