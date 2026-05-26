import React, { useContext, useState } from "react";
import { Table, Button, Space, Tag } from "antd";
import { EditOutlined } from "@ant-design/icons";

import { ControlContext, useAccount, useRoles } from "@clusterio/web_ui";
import { RoleMappingRecord, RoleMappingDeleteRequest } from "../../messages";
import type { WebPlugin } from "..";

import RoleMappingForm from "./RoleMappingForm";
import DeletedConfirm from "./DeleteConfirm";

export default function RoleMappingsTable() {
	const control = useContext(ControlContext);
	const plugin = control.plugins.get("exp_groups") as WebPlugin;
	const account = useAccount();

	const [roleMappings, roleMappingsSynced] = plugin.useRoleMappings();
	const [groups, groupsSynced] = plugin.useGroups();
	const [roles, rolesSynced] = useRoles();

	const [editing, setEditing] = useState<RoleMappingRecord | undefined>();
	const [open, setOpen] = useState(false);

	const roleMappingArray = [...roleMappings.values()];

	const roleFilters = [...roles.values()]
		.filter(role => roleMappingArray.some(mapping => mapping.roleIds.has(role.id)))
		.map(role => ({ text: role.name, value: role.id }));

	const groupFilters = [...groups.values()]
		.filter(group => roleMappingArray.some(mapping => mapping.groupId === group.id))
		.map(group => ({ text: group.name, value: group.id }))

	return <>
		<Table
			columns={[
				{
					title: "Priority",
					dataIndex: "priority",
					width: "10%",
				},
				{
					title: "Roles",
					filters: roleFilters,
					onFilter: (value, record: RoleMappingRecord) => (
						record.roleIds.has(value as number)
					),
					render: (_: any, record: RoleMappingRecord) => (
						[...record.roleIds].map(id => <Tag key={id}>{roles.get(id)?.name ?? id}</Tag>)
					),
				},
				{
					title: "Group",
					width: "30%",
					filters: groupFilters,
					onFilter: (value, record: RoleMappingRecord) => (
						record.groupId === value
					),
					render: (_: any, record: RoleMappingRecord) => (
						groups.get(record.groupId)?.name ?? record.groupId
					),
				},
				{
					title: "Enabled",
					width: "10%",
					filters: [
						{ text: "Enabled", value: true },
						{ text: "Disabled", value: false },
					],
					onFilter: (value, record: RoleMappingRecord) => (
						record.enabled === value
					),
					render: (_: any, record: RoleMappingRecord) => (
						record.enabled ? "Yes" : "No"
					),
				},
				...(account.hasAnyPermission(
					"exp_groups.role_mapping.update",
					"exp_groups.role_mapping.delete",
				) ? [{
					title: "Actions",
					width: "10%",
					render: (_: any, record: any) => (
						<Space>
							{account.hasPermission("exp_groups.role_mapping.update") && <Button
								icon={<EditOutlined />}
								onClick={() => {
									setEditing(record);
									setOpen(true);
								}}
							/>}
							{account.hasPermission("exp_groups.role_mapping.delete") && <DeletedConfirm
								onConfirm={() => control.send(new RoleMappingDeleteRequest(record.id))}
							/>}
						</Space>
					),
				}] : []),
			]}
			dataSource={roleMappingArray.sort((a, b) => b.priority - a.priority)}
			loading={!roleMappingsSynced || !groupsSynced || !rolesSynced}
			rowKey={(m) => m.id}
			pagination={false}
		/>

		<RoleMappingForm open={open} setOpen={setOpen} initial={editing} />
	</>;
}
