import React, { useMemo, useState } from "react";
import { Button, Checkbox, Divider, Select, Space, Table } from "antd";
import type { ColumnsType } from "antd/es/table";

import { PageHeader, PageLayout, useColumnSearch, useTableQueryState, useUsers } from "@clusterio/web_ui";

import { PlayerStatistics, userStatistics } from "../../messages.js";
import { usePlayerStatistics } from "..";
import { formatValue, statistics } from "../statistics";

const strcmp = new Intl.Collator(undefined, { numeric: true, sensitivity: "base" }).compare;

const storageKey = "exp_player_statistics.columns";
const defaultColumns = [
	"Playtime", "AfkTime", "MapsPlayed", "JoinCount", "ChatMessages",
	"RocketsLaunched", "ResearchCompleted", "MachinesBuilt", "Kills", "Deaths",
];

function loadColumns() {
	try {
		const stored = JSON.parse(localStorage.getItem(storageKey) ?? "null");
		if (Array.isArray(stored)) {
			return stored.filter(name => statistics.some(([statistic]) => statistic === name));
		}
	} catch { /* fall back to the defaults */ }
	return defaultColumns;
}

export default function StatisticsPage() {
	const [players, synced] = usePlayerStatistics();
	const [users] = useUsers();
	const [columns, setColumnsState] = useState<string[]>(loadColumns);
	const tableState = useTableQueryState<PlayerStatistics>({
		namespace: "statistics",
		defaultSortKey: "Playtime",
		defaultSortOrder: "descend",
		pagination: { defaultPageSize: 50 },
	});
	const playerSearch = useColumnSearch<PlayerStatistics>(tableState, "player", player => player.id, "Search players");

	function setColumns(names: string[]) {
		// Keep the display order whatever order they were picked in
		const ordered = statistics.map(([name]) => name).filter(name => names.includes(name));
		setColumnsState(ordered);
		localStorage.setItem(storageKey, JSON.stringify(ordered));
	}

	const rows = useMemo(() => [...players.values()].map(player => new PlayerStatistics(
		player.id,
		{ ...player.stats, ...userStatistics(users.get(player.id.toLowerCase()), player.stats) },
		player.updatedAtMs,
	)), [players, users]);

	const tableColumns: ColumnsType<PlayerStatistics> = [
		{
			title: "Player",
			key: "player",
			fixed: "left",
			render: (_, player) => player.id,
			sorter: (a, b) => strcmp(a.id, b.id),
			sortOrder: tableState.sortOrder("player"),
			filteredValue: tableState.filteredValue("player"),
			...playerSearch,
		},
		...statistics.filter(([name]) => columns.includes(name)).map(
			([name, title]): ColumnsType<PlayerStatistics>[number] => ({
				title,
				key: name,
				align: "right",
				render: (_, player) => formatValue(name, player.stats[name] ?? 0),
				sorter: (a, b) => (a.stats[name] ?? 0) - (b.stats[name] ?? 0),
				sortDirections: ["descend", "ascend"],
				sortOrder: tableState.sortOrder(name),
			})
		),
	];

	const columnSelect = <Select
		mode="multiple"
		style={{ minWidth: 220 }}
		value={columns}
		onChange={setColumns}
		options={statistics.map(([value, label]) => ({ value, label }))}
		maxTagCount={0}
		maxTagPlaceholder={() => `${columns.length} statistics selected`}
		placeholder="No statistics selected"
		menuItemSelectedIcon={null}
		optionRender={option => <Checkbox checked={columns.includes(option.value as string)}>
			{option.label}
		</Checkbox>}
		popupRender={menu => <>
			{menu}
			<Divider style={{ margin: "4px 0" }} />
			<Space style={{ padding: "0 8px 4px" }}>
				<Button size="small" onClick={() => setColumns(statistics.map(([name]) => name))}>Select all</Button>
				<Button size="small" onClick={() => setColumns(defaultColumns)}>Reset</Button>
			</Space>
		</>}
	/>;

	return <PageLayout nav={[{ name: "Statistics" }]}>
		<PageHeader title="Statistics" extra={columnSelect} />
		<Table
			size="small"
			columns={tableColumns}
			dataSource={rows}
			loading={!synced}
			rowKey={player => player.id}
			pagination={tableState.pagination}
			onChange={tableState.onChange}
			scroll={{ x: "max-content" }}
		/>
	</PageLayout>;
}
