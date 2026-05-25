import React, { useContext, useState, useRef } from "react";
import { Table, Button, Space, Input, InputRef } from "antd";
import { EditOutlined, SearchOutlined } from "@ant-design/icons";

import { ControlContext, useAccount } from "@clusterio/web_ui";
import { AssignmentDeleteRequest, AssignmentRecord } from "../../messages";
import type { WebPlugin } from "..";

import AssignmentForm from "./AssignmentForm";
import DeletedConfirm from "./DeleteConfirm";

const strcmp = new Intl.Collator(undefined, { numeric: true, sensitivity: "base" }).compare;

export default function AssignmentsTable() {
	const control = useContext(ControlContext);
	const plugin = control.plugins.get("exp_groups") as WebPlugin;
	const account = useAccount();

	const searchInput = useRef<InputRef>(null);

	const [assignments, assignmentsSynced] = plugin.useAssignments();
	const [groups, groupsSynced] = plugin.useGroups();

	const [editing, setEditing] = useState<AssignmentRecord | undefined>();
	const [open, setOpen] = useState(false);

	const assignmentsArray = [...assignments.values()];

	const groupFilters = [...groups.values()]
		.filter(group => assignmentsArray.some(assignment => assignment.groupId === group.id))
		.map(group => ({ text: group.name, value: group.id }))

	return <>
		<Table
			columns={[
				{
					title: "Player",
					dataIndex: "name",
					sorter: (a: AssignmentRecord, b: AssignmentRecord) => strcmp(a.name, b.name),
					filterIcon: (filtered: boolean) => (
						<SearchOutlined style={{ color: filtered ? "#1677ff" : undefined }} />
					),
					onFilter: (value, record: AssignmentRecord) => (
						record.name.toLowerCase().includes(String(value).toLowerCase())
					),
					filterDropdownProps: {
						onOpenChange: (open: boolean) => open && setTimeout(() => searchInput.current?.select(), 100),
					},
					filterDropdown: ({ selectedKeys, setSelectedKeys, confirm, clearFilters }) => (
						<div style={{ padding: 4 }} onKeyDown={(e) => e.stopPropagation()}>
							<Input.Search
								allowClear
								ref={searchInput}
								placeholder={"Search username"}
								value={selectedKeys[0]}
								onChange={(e) => setSelectedKeys([e.target.value])}
								onSearch={() => confirm({ closeDropdown: false })}
								onClear={() => {
									clearFilters?.({ closeDropdown: false });
									confirm({ closeDropdown: true });
								}}
							/>
						</div>
					),
				},
				{
					title: "Group",
					width: "40%",
					filters: groupFilters,
					onFilter: (value, record: AssignmentRecord) => (
						record.groupId === value
					),
					render: (_: any, a: any) => (
						groups.get(a.groupId)?.name ?? a.groupId
					),
				},
				...(account.hasAnyPermission(
					"exp_groups.assignment.update",
					"exp_groups.assignment.delete",
				) ? [{
					title: "Actions",
					width: "10%",
					render: (_: any, record: AssignmentRecord) => (
						<Space>
							{account.hasPermission("exp_groups.assignment.update") &&
								<Button icon={<EditOutlined />} onClick={() => {
									setEditing(record);
									setOpen(true);
								}} />
							}
							{account.hasPermission("exp_groups.assignment.delete") && <DeletedConfirm
								onConfirm={() => control.send(new AssignmentDeleteRequest(record.name))}
							/>}
						</Space>
					),
				}] : []),
			]}
			dataSource={assignmentsArray}
			loading={!assignmentsSynced || !groupsSynced}
			rowKey={(a) => a.name}
			pagination={{
				defaultPageSize: 50,
				showSizeChanger: true,
				pageSizeOptions: ["10", "20", "50", "100", "200"],
				showTotal: (total: number) => `${total} Assignments`,
			}}
		/>

		<AssignmentForm open={open} setOpen={setOpen} initial={editing} />
	</>;
}
