import React, { useState, useCallback, useSyncExternalStore } from "react";
import { BaseWebPlugin, PageLayout, PageHeader, useAccount, SectionHeader } from "@clusterio/web_ui";
import { Button } from "antd";

import * as messages from "../messages";
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

export class WebPlugin extends BaseWebPlugin {
	groups = new lib.MapSubscriber(messages.GroupUpdatedEvent, this.control);
	assignments = new lib.MapSubscriber(messages.ManualAssignmentUpdatedEvent, this.control);
	roleMappings = new lib.MapSubscriber(messages.RoleMappingUpdatedEvent, this.control);

	async init() {
		this.pages = [
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
		];
	}

	useGroups() {
		const subscribe = useCallback((cb: () => void) => this.groups.subscribe(cb), []);
		return useSyncExternalStore(subscribe, () => this.groups.getSnapshot());
	}

	useAssignments() {
		const subscribe = useCallback((cb: () => void) => this.assignments.subscribe(cb), []);
		return useSyncExternalStore(subscribe, () => this.assignments.getSnapshot());
	}

	useRoleMappings() {
		const subscribe = useCallback((cb: () => void) => this.roleMappings.subscribe(cb), []);
		return useSyncExternalStore(subscribe, () => this.roleMappings.getSnapshot());
	}
}
