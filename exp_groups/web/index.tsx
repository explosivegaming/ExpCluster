import React, { useState, useCallback, useSyncExternalStore } from "react";
import { WebPluginContext, PageLayout, PageHeader, useAccount, SectionHeader } from "@clusterio/web_ui";
import { Button } from "antd";

import * as messages from "../messages.js";
import * as lib from "@clusterio/lib";

import GroupsTable from "./components/GroupsTable";
import AssignmentsTable from "./components/AssignmentsTable";
import RoleMappingsTable from "./components/RoleMappingsTable";
import GroupViewPage from "./components/GroupViewPage";
import GroupForm from "./components/GroupForm";
import RoleMappingForm from "./components/RoleMappingForm";
import AssignmentForm from "./components/AssignmentForm";


function ExpGroupsPage() {
	const account = useAccount();

	const [groupOpen, setGroupOpen] = useState(false);
	const [assignmentOpen, setAssignmentOpen] = useState(false);
	const [roleMappingOpen, setRoleMappingOpen] = useState(false);

	return <PageLayout nav={[{ name: "Permission Groups" }]}>
		<PageHeader title="Permission Groups" />

		{account.hasPermission("exp_groups.group.list") && <>
			<SectionHeader
				title="Groups"
				extra={
					account.hasPermission("exp_groups.group.create")
						? <Button type="primary" onClick={() => setGroupOpen(true)}>Create</Button>
						: undefined
				}
			/>
			<GroupsTable />
			<GroupForm open={groupOpen} setOpen={setGroupOpen} />
		</>}

		{account.hasPermission("exp_groups.role_mapping.list") && <>
			<SectionHeader
				title="Role Mappings"
				extra={
					account.hasPermission("exp_groups.role_mapping.create")
						? <Button type="primary" onClick={() => setRoleMappingOpen(true)}>Create</Button>
						: undefined
				}
			/>
			<RoleMappingsTable />
			<RoleMappingForm open={roleMappingOpen} setOpen={setRoleMappingOpen} />
		</>}

		{account.hasPermission("exp_groups.assignment.list") && <>
			<SectionHeader
				title="Assignments"
				extra={
					account.hasPermission("exp_groups.assignment.create")
						? <Button type="primary" onClick={() => setAssignmentOpen(true)}>Create</Button>
						: undefined
				}
			/>
			<AssignmentsTable />
			<AssignmentForm open={assignmentOpen} setOpen={setAssignmentOpen} />
		</>}
	</PageLayout>;
}

let groups: lib.MapSubscriber<messages.GroupUpdatedEvent> | undefined;
let assignments: lib.MapSubscriber<messages.ManualAssignmentUpdatedEvent> | undefined;
let roleMappings: lib.MapSubscriber<messages.RoleMappingUpdatedEvent> | undefined;

export function useGroups() {
	const subscribe = useCallback((cb: () => void) => groups!.subscribe(cb), []);
	return useSyncExternalStore(subscribe, () => groups!.getSnapshot());
}

export function useAssignments() {
	const subscribe = useCallback((cb: () => void) => assignments!.subscribe(cb), []);
	return useSyncExternalStore(subscribe, () => assignments!.getSnapshot());
}

export function useRoleMappings() {
	const subscribe = useCallback((cb: () => void) => roleMappings!.subscribe(cb), []);
	return useSyncExternalStore(subscribe, () => roleMappings!.getSnapshot());
}

export default function registerPlugin(context: WebPluginContext) {
	context.control.hooks.pages.attach("exp_groups", () => [
		{
			path: "/permission_groups",
			sidebarName: "Permission Groups",
			permission: (account => account.hasAnyPermission(
                "exp_groups.group.list",
                "exp_groups.assignment.list",
                "exp_groups.role_mapping.list",
            )),
			content: <ExpGroupsPage />,
		},
		{
			path: "/permission_groups/:id/view",
			sidebarPath: "/permission_groups",
			permission: "exp_groups.group.get",
			content: <GroupViewPage />,
		},
	]);

	groups = new lib.MapSubscriber(messages.GroupUpdatedEvent, context.control);
	assignments = new lib.MapSubscriber(messages.ManualAssignmentUpdatedEvent, context.control);
	roleMappings = new lib.MapSubscriber(messages.RoleMappingUpdatedEvent, context.control);
}
