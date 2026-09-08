import React, { useContext, useState } from "react";
import { Button, Form, Input, Modal, Popconfirm, Table } from "antd";

import {
	ControlContext, PageHeader, PageLayout, notifyErrorHandler, useAccount,
	useColumnSearch, useTableQueryState,
} from "@clusterio/web_ui";

import { ReportCreateRequest, ReportDeleteRequest, ReportRecord } from "../../messages";
import type { WebPlugin } from "..";

const strcmp = new Intl.Collator(undefined, { numeric: true, sensitivity: "base" }).compare;

/** Modal which reports a player in the name of the web user. */
function CreateReportButton() {
	const control = useContext(ControlContext);
	const [open, setOpen] = useState(false);
	const [form] = Form.useForm<{ playerName: string, reason: string }>();

	async function createReport() {
		const values = await form.validateFields();
		await control.send(new ReportCreateRequest(values.playerName, values.reason));
		form.resetFields();
		setOpen(false);
	}

	return <>
		<Button type="primary" onClick={() => setOpen(true)}>Create</Button>
		<Modal
			title="Report Player"
			okText="Report"
			open={open}
			onOk={() => { createReport().catch(notifyErrorHandler("Error creating report")); }}
			onCancel={() => setOpen(false)}
			destroyOnHidden
		>
			<Form form={form} layout="vertical">
				<Form.Item name="playerName" label="Player" rules={[{ required: true }]}>
					<Input />
				</Form.Item>
				<Form.Item name="reason" label="Reason" rules={[{ required: true }]}>
					<Input.TextArea rows={3} />
				</Form.Item>
			</Form>
		</Modal>
	</>;
}

/** Table of every report with search on the player, reporter and reason, and a filter on the instance. */
function ReportsTable() {
	const control = useContext(ControlContext);
	const account = useAccount();
	const plugin = control.plugins.get("exp_reports") as WebPlugin;
	const [reports, synced] = plugin.useReports();

	const tableState = useTableQueryState<ReportRecord>({
		namespace: "report",
		defaultSortKey: "time",
		pagination: { defaultPageSize: 50 },
	});
	const playerSearch = useColumnSearch<ReportRecord>(tableState, "player", report => report.playerName, "Search players");
	const bySearch = useColumnSearch<ReportRecord>(tableState, "by", report => report.byPlayerName, "Search reporters");
	const reasonSearch = useColumnSearch<ReportRecord>(tableState, "reason", report => report.reason, "Search reasons");

	const data = [...reports.values()];
	const instanceNames = [...new Set(data.map(report => report.instanceName))].sort(strcmp);
	const instanceFilters = instanceNames.map(name => ({ text: name || "Web UI", value: name }));
	const canDelete = account.hasPermission("exp_reports.report.delete");

	return <Table
		size="small"
		columns={[
			{
				title: "Player",
				key: "player",
				render: (_, report) => report.playerName,
				sorter: (a, b) => strcmp(a.playerName, b.playerName),
				sortOrder: tableState.sortOrder("player"),
				filteredValue: tableState.filteredValue("player"),
				...playerSearch,
			},
			{
				title: "Reported by",
				key: "by",
				render: (_, report) => report.byPlayerName,
				sorter: (a, b) => strcmp(a.byPlayerName, b.byPlayerName),
				sortOrder: tableState.sortOrder("by"),
				filteredValue: tableState.filteredValue("by"),
				...bySearch,
			},
			{
				title: "Reason",
				key: "reason",
				render: (_, report) => report.reason,
				filteredValue: tableState.filteredValue("reason"),
				...reasonSearch,
			},
			{
				title: "Instance",
				key: "instance",
				render: (_, report) => report.instanceName || "Web UI",
				filters: instanceFilters,
				filteredValue: tableState.filteredValue("instance"),
				onFilter: (value, report) => report.instanceName === value,
				sorter: (a, b) => strcmp(a.instanceName, b.instanceName),
				sortOrder: tableState.sortOrder("instance"),
			},
			{
				title: "Time",
				key: "time",
				render: (_, report) => new Date(report.updatedAtMs).toLocaleString(),
				sorter: (a, b) => a.updatedAtMs - b.updatedAtMs,
				sortOrder: tableState.sortOrder("time"),
				defaultSortOrder: "descend",
			},
			...canDelete ? [{
				key: "actions",
				render: (_: unknown, report: ReportRecord) => <Popconfirm
					title="Delete this report?"
					onConfirm={() => {
						control.send(new ReportDeleteRequest(report.id)).catch(notifyErrorHandler("Error deleting report"));
					}}
				>
					<Button size="small" danger onClick={event => event.stopPropagation()}>Delete</Button>
				</Popconfirm>,
			}] : [],
		]}
		dataSource={data}
		loading={!synced}
		rowKey={report => report.id}
		pagination={tableState.pagination}
		onChange={tableState.onChange}
	/>;
}

export default function ReportsPage() {
	const account = useAccount();
	return <PageLayout nav={[{ name: "Reports" }]}>
		<PageHeader
			title="Reports"
			extra={account.hasPermission("exp_reports.report.create") ? <CreateReportButton /> : undefined}
		/>
		<ReportsTable />
	</PageLayout>;
}
