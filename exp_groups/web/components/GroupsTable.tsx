import React, { useContext, useState } from "react";
import { Table } from "antd";
import { useNavigate } from "react-router-dom";

import { ControlContext, useAccount } from "@clusterio/web_ui";

import GroupForm from "./GroupForm";

const strcmp = new Intl.Collator(undefined, { numeric: true, sensitivity: "base" }).compare;

export default function GroupsTable() {
	const control = useContext(ControlContext);
	const plugin = control.plugins.get("exp_groups") as any;
	const navigate = useNavigate();

	const [groups, synced] = plugin.useGroups();

	const [open, setOpen] = useState(false);

	return <>
		<Table
			columns={[
				{
					title: "Name",
					dataIndex: "name",
					sorter: (a: any, b: any) => strcmp(a.name, b.name),
				},
				{
					title: "Type",
					render: (_: any, g: any) => g.permissions.isBlacklist ? "Blacklist" : "Whitelist",
				},
				{
					title: "Permissions",
					render: (_: any, g: any) => g.permissions.permissions.length,
				},
			]}
			dataSource={[...groups.values()]}
			loading={!synced}
			pagination={false}
			rowKey={(g) => g.id}
			onRow={(g) => ({
				onClick: () => navigate(`/exp_groups/${g.id}/view`),
			})}
		/>

		<GroupForm open={open} setOpen={setOpen} />
	</>;
}