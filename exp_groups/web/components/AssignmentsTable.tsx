import React, { useContext, useState } from "react";
import { Table, Button, Popconfirm, Space } from "antd";
import { EditOutlined, DeleteOutlined } from "@ant-design/icons";

import { ControlContext, useAccount } from "@clusterio/web_ui";
import * as messages from "../../messages";

import AssignmentForm from "./AssignmentForm";

const strcmp = new Intl.Collator(undefined, { numeric: true, sensitivity: "base" }).compare;

export default function AssignmentsTable() {
	const control = useContext(ControlContext);
	const plugin = control.plugins.get("exp_groups") as any;
	const account = useAccount();

	const [assignments, synced] = plugin.useAssignments();
	const [groups] = plugin.useGroups();

	const [editing, setEditing] = useState<any>(null);
	const [open, setOpen] = useState(false);

	return <>
		<Table
			columns={[
				{
					title: "Player",
					dataIndex: "name",
					sorter: (a: any, b: any) => strcmp(a.name, b.name),
				},
				{
					title: "Group",
					render: (_: any, a: any) => groups.get(a.groupId)?.name ?? a.groupId,
				},
				{
					title: "Actions",
					render: (_: any, record: any) => (
						<Space>
							{account.hasPermission("exp_groups.assignment.update") &&
								<Button icon={<EditOutlined />} onClick={() => {
									setEditing(record);
									setOpen(true);
								}} />
							}
							{account.hasPermission("exp_groups.assignment.delete") &&
								<Popconfirm
									title="Delete?"
									onConfirm={() => control.send(new messages.AssignmentDeleteRequest(record.name))}
								>
									<Button danger icon={<DeleteOutlined />} />
								</Popconfirm>
							}
						</Space>
					),
				},
			]}
			dataSource={[...assignments.values()]}
			loading={!synced}
			pagination={false}
			rowKey={(a) => a.name}
		/>

		<AssignmentForm open={open} setOpen={setOpen} initial={editing} />
	</>;
}
