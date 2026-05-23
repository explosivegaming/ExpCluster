import React, { useContext, useState } from "react";
import { Table, Button, Popconfirm, Space, Tag } from "antd";
import { EditOutlined, DeleteOutlined } from "@ant-design/icons";

import { ControlContext, useAccount, useRoles } from "@clusterio/web_ui";
import * as messages from "../../messages";

import RoleMappingForm from "./RoleMappingForm";

export default function RoleMappingsTable() {
	const control = useContext(ControlContext);
	const plugin = control.plugins.get("exp_groups") as any;
	const account = useAccount();

	const [roleMappings, synced] = plugin.useRoleMappings();
	const [groups] = plugin.useGroups();
	const [roles] = useRoles();

	const [editing, setEditing] = useState<any>(null);
	const [open, setOpen] = useState(false);

	return <>
		<Table
			columns={[
				{
					title: "Priority",
					dataIndex: "priority",
				},
				{
					title: "Roles",
					render: (_: any, m: any) => [...m.roleIds].map((id: number) => {
						const role = roles.get(id);
						return <Tag key={id}>{role?.name ?? id}</Tag>;
					}),
				},
				{
					title: "Group",
					render: (_: any, m: any) => groups.get(m.groupId)?.name ?? m.groupId,
				},
				{
					title: "Enabled",
					render: (_: any, m: any) => m.enabled ? "Yes" : "No",
				},
				{
					title: "Actions",
					render: (_: any, record: any) => (
						<Space>
							{account.hasPermission("exp_groups.role_mapping.update") &&
								<Button icon={<EditOutlined />} onClick={() => {
									setEditing(record);
									setOpen(true);
								}} />
							}
							{account.hasPermission("exp_groups.role_mapping.delete") &&
								<Popconfirm
									title="Delete?"
									onConfirm={() => control.send(new messages.RoleMappingDeleteRequest(record.id))}
								>
									<Button danger icon={<DeleteOutlined />} />
								</Popconfirm>
							}
						</Space>
					),
				},
			]}
			dataSource={[...roleMappings.values()].sort((a, b) => b.priority - a.priority)}
			loading={!synced}
			pagination={false}
			rowKey={(m) => m.id}
		/>

		<RoleMappingForm open={open} setOpen={setOpen} initial={editing} />
	</>;
}
