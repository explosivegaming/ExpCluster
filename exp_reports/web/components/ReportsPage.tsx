import React, { useContext, useState } from "react";
import { Button, Form, Input, Modal, Popconfirm, Space, Table, Tag } from "antd";

import {
	ControlContext, PageHeader, PageLayout, notifyErrorHandler, useAccount,
	useColumnSearch, useTableQueryState,
} from "@clusterio/web_ui";

import {
	ReportCreateRequest, ReportDeleteRequest, ReportRecord, ReportSetReadRequest,
	WatchListAddRequest, WatchListRecord, WatchListRemoveRequest,
} from "../../messages.js";
import { useReports, useWatchList } from "..";

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

type WatchListValues = { playerName: string, reason: string };

/**
 * Modal which adds a player to the watch list, filled in from a report or left empty.
 * Mounted only while open, the form keeps its initial values from the first mount.
 */
function WatchListAddModal(props: { values: WatchListValues, onClose: () => void }) {
	const control = useContext(ControlContext);
	const [form] = Form.useForm<WatchListValues>();

	async function addPlayer() {
		const values = await form.validateFields();
		await control.send(new WatchListAddRequest(values.playerName, values.reason));
		props.onClose();
	}

	return <Modal
		title="Add to Watch List"
		okText="Add"
		open
		onOk={() => { addPlayer().catch(notifyErrorHandler("Error adding to watch list")); }}
		onCancel={props.onClose}
	>
		<Form form={form} layout="vertical" initialValues={props.values}>
			<Form.Item name="playerName" label="Player" rules={[{ required: true }]}>
				<Input />
			</Form.Item>
			<Form.Item name="reason" label="Reason" rules={[{ required: true }]}>
				<Input.TextArea rows={3} />
			</Form.Item>
		</Form>
	</Modal>;
}

/**
 * Table of every report with search on the player, reporter and reason, and
 * filters on the instance and read state.
 */
function ReportsTable(props: { onWatch: (values: WatchListValues) => void }) {
	const control = useContext(ControlContext);
	const account = useAccount();
	const [reports, synced] = useReports();
	const [watchList] = useWatchList();

	const tableState = useTableQueryState<ReportRecord>({
		namespace: "report",
		defaultSortKey: "time",
		defaultSortOrder: "descend",
		pagination: { defaultPageSize: 50 },
	});
	const playerSearch = useColumnSearch<ReportRecord>(tableState, "player", report => report.playerName, "Search players");
	const bySearch = useColumnSearch<ReportRecord>(tableState, "by", report => report.byPlayerName, "Search reporters");
	const reasonSearch = useColumnSearch<ReportRecord>(tableState, "reason", report => report.reason, "Search reasons");

	const data = [...reports.values()];
	const instanceNames = [...new Set(data.map(report => report.instanceName))].sort(strcmp);
	const instanceFilters = instanceNames.map(name => ({ text: name || "Web UI", value: name }));
	const canMarkRead = account.hasPermission("exp_reports.report.mark_read");
	const canWatch = account.hasPermission("exp_reports.watch_list.add");
	const canDelete = account.hasPermission("exp_reports.report.delete");

	function setRead(report: ReportRecord, isRead: boolean) {
		control.send(new ReportSetReadRequest(report.id, isRead)).catch(notifyErrorHandler("Error updating report"));
	}

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
				render: (_, report) => new Date(report.createdAtMs).toLocaleString(),
				sorter: (a, b) => a.createdAtMs - b.createdAtMs,
				sortOrder: tableState.sortOrder("time"),
			},
			{
				title: "Status",
				key: "status",
				render: (_, report) => (report.isRead ? <Tag>Read</Tag> : <Tag color="gold">Unread</Tag>),
				filters: [{ text: "Read", value: "read" }, { text: "Unread", value: "unread" }],
				filteredValue: tableState.filteredValue("status"),
				onFilter: (value, report) => report.isRead === (value === "read"),
			},
			...canMarkRead || canWatch || canDelete ? [{
				key: "actions",
				render: (_: unknown, report: ReportRecord) => <Space size="small">
					{canMarkRead && <Button size="small" onClick={() => setRead(report, !report.isRead)}>
						{report.isRead ? "Mark unread" : "Mark read"}
					</Button>}
					{canWatch && <Button
						size="small"
						disabled={watchList.has(report.playerName.toLowerCase())}
						onClick={() => props.onWatch({ playerName: report.playerName, reason: report.reason })}
					>
						Add to watch list
					</Button>}
					{canDelete && <Popconfirm
						title="Delete this report?"
						onConfirm={() => {
							control.send(new ReportDeleteRequest(report.id))
								.catch(notifyErrorHandler("Error deleting report"));
						}}
					>
						<Button size="small" danger onClick={event => event.stopPropagation()}>Delete</Button>
					</Popconfirm>}
				</Space>,
			}] : [],
		]}
		dataSource={data}
		loading={!synced}
		rowKey={report => report.id}
		pagination={tableState.pagination}
		onChange={tableState.onChange}
	/>;
}

/** Table of the players whose joins are announced to admins. */
function WatchListTable() {
	const control = useContext(ControlContext);
	const account = useAccount();
	const [watchList, synced] = useWatchList();

	const tableState = useTableQueryState<WatchListRecord>({
		namespace: "watch",
		defaultSortKey: "time",
		defaultSortOrder: "descend",
		pagination: { defaultPageSize: 50 },
	});
	const playerSearch = useColumnSearch<WatchListRecord>(
		tableState, "player", entry => entry.playerName, "Search players",
	);
	const reasonSearch = useColumnSearch<WatchListRecord>(tableState, "reason", entry => entry.reason, "Search reasons");
	const canRemove = account.hasPermission("exp_reports.watch_list.remove");

	return <Table
		size="small"
		columns={[
			{
				title: "Player",
				key: "player",
				render: (_, entry) => entry.playerName,
				sorter: (a, b) => strcmp(a.playerName, b.playerName),
				sortOrder: tableState.sortOrder("player"),
				filteredValue: tableState.filteredValue("player"),
				...playerSearch,
			},
			{
				title: "Reason",
				key: "reason",
				render: (_, entry) => entry.reason,
				filteredValue: tableState.filteredValue("reason"),
				...reasonSearch,
			},
			{
				title: "Added by",
				key: "by",
				render: (_, entry) => entry.byPlayerName,
				sorter: (a, b) => strcmp(a.byPlayerName, b.byPlayerName),
				sortOrder: tableState.sortOrder("by"),
			},
			{
				title: "Time",
				key: "time",
				render: (_, entry) => new Date(entry.createdAtMs).toLocaleString(),
				sorter: (a, b) => a.createdAtMs - b.createdAtMs,
				sortOrder: tableState.sortOrder("time"),
			},
			...canRemove ? [{
				key: "actions",
				render: (_: unknown, entry: WatchListRecord) => <Popconfirm
					title={`Remove ${entry.playerName} from the watch list?`}
					onConfirm={() => {
						control.send(new WatchListRemoveRequest(entry.playerName))
							.catch(notifyErrorHandler("Error removing from watch list"));
					}}
				>
					<Button size="small" danger onClick={event => event.stopPropagation()}>Delete</Button>
				</Popconfirm>,
			}] : [],
		]}
		dataSource={[...watchList.values()]}
		loading={!synced}
		rowKey={entry => entry.playerName}
		pagination={tableState.pagination}
		onChange={tableState.onChange}
	/>;
}

export default function ReportsPage() {
	const account = useAccount();
	const [watchValues, setWatchValues] = useState<WatchListValues>();
	const canWatch = account.hasPermission("exp_reports.watch_list.add");

	return <PageLayout nav={[{ name: "Reports" }]}>
		<PageHeader
			title="Reports"
			extra={account.hasPermission("exp_reports.report.create") ? <CreateReportButton /> : undefined}
		/>
		<ReportsTable onWatch={setWatchValues} />
		{account.hasPermission("exp_reports.watch_list.subscribe") && <>
			<PageHeader
				title="Watch List"
				extra={canWatch
					? <Button type="primary" onClick={() => setWatchValues({ playerName: "", reason: "" })}>Add</Button>
					: undefined}
			/>
			<WatchListTable />
		</>}
		{watchValues && <WatchListAddModal values={watchValues} onClose={() => setWatchValues(undefined)} />}
	</PageLayout>;
}
