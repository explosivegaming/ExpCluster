import React, { useContext, useState } from "react";
import { Table } from "antd";
import { useNavigate } from "react-router-dom";

import { ControlContext } from "@clusterio/web_ui";
import { GroupRecord } from "../../messages";
import type { WebPlugin } from "..";

import GroupForm from "./GroupForm";

const strcmp = new Intl.Collator(undefined, { numeric: true, sensitivity: "base" }).compare;

export default function GroupsTable() {
	const control = useContext(ControlContext);
	const plugin = control.plugins.get("exp_groups") as WebPlugin;
	const navigate = useNavigate();

	const [groups, synced] = plugin.useGroups();

	const [open, setOpen] = useState(false);

	return <>
		<Table
			columns={[
				{
					title: "Name",
					dataIndex: "name",
					sorter: (a: any, b: GroupRecord) => strcmp(a.name, b.name),
				},
				{
					title: "Permissions",
					width: "50%",
					render: (_: any, g: GroupRecord) => (
						`${g.permissions.permissions.length} ${g.permissions.isBlacklist ? "Disallowed" : "Allowed"}`
					),
				},
			]}
			dataSource={[...groups.values()]}
			loading={!synced}
			rowKey={(g) => g.id}
			pagination={false}
			onRow={(g) => ({
				onClick: () => navigate(`/permission_groups/${g.id}/view`),
			})}
		/>

		<GroupForm open={open} setOpen={setOpen} />
	</>;
}