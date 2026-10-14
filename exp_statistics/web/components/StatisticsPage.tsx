import React from "react";
import { Table } from "antd";
import type { ColumnsType } from "antd/es/table";

import { PageHeader, PageLayout, useColumnSearch, useTableQueryState } from "@clusterio/web_ui";

import { PlayerStatistics } from "../../messages.js";
import { usePlayerStatistics } from "..";

const strcmp = new Intl.Collator(undefined, { numeric: true, sensitivity: "base" }).compare;

/** Same order and names as module/config.lua and module/locale/en.cfg */
const statistics: [name: string, title: string][] = [
	["Playtime", "Playtime"],
	["AfkTime", "AFK Time"],
	["MapsPlayed", "Maps Played"],
	["JoinCount", "Join Count"],
	["ChatMessages", "Messages"],
	["CommandsUsed", "Commands"],
	["RocketsLaunched", "Rockets Launched"],
	["ResearchCompleted", "Research Completed"],
	["MachinesBuilt", "Machines Built"],
	["MachinesRemoved", "Machines Removed"],
	["TilesBuilt", "Tiles Placed"],
	["TilesRemoved", "Tiles Removed"],
	["TreesDestroyed", "Trees Destroyed"],
	["OreMined", "Ore Mined"],
	["ItemsCrafted", "Items Crafted"],
	["ItemsPickedUp", "Items Picked Up"],
	["Kills", "Kills"],
	["Deaths", "Deaths"],
	["DamageDealt", "Damage Dealt"],
	["DistanceTravelled", "Distance Travelled"],
	["CapsulesUsed", "Capsules Used"],
	["EntityRepaired", "Machines Repaired"],
	["DeconstructionPlannerUsed", "Decon Planner Used"],
	["MapTagsMade", "Map Tags Created"],
];

/** Measured in minutes */
const timeStatistics = new Set(["Playtime", "AfkTime"]);

function formatValue(name: string, value: number) {
	if (timeStatistics.has(name)) {
		return `${Math.floor(value / 60)}h ${value % 60}m`;
	}
	return value.toLocaleString();
}

export default function StatisticsPage() {
	const [players, synced] = usePlayerStatistics();
	const tableState = useTableQueryState<PlayerStatistics>({
		namespace: "statistics",
		defaultSortKey: "Playtime",
		defaultSortOrder: "descend",
		pagination: { defaultPageSize: 50 },
	});
	const playerSearch = useColumnSearch<PlayerStatistics>(tableState, "player", player => player.id, "Search players");

	const columns: ColumnsType<PlayerStatistics> = [
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
		...statistics.map(([name, title]): ColumnsType<PlayerStatistics>[number] => ({
			title,
			key: name,
			align: "right",
			render: (_, player) => formatValue(name, player.stats[name] ?? 0),
			sorter: (a, b) => (a.stats[name] ?? 0) - (b.stats[name] ?? 0),
			sortDirections: ["descend", "ascend"],
			sortOrder: tableState.sortOrder(name),
		})),
	];

	return <PageLayout nav={[{ name: "Statistics" }]}>
		<PageHeader title="Statistics" />
		<Table
			size="small"
			columns={columns}
			dataSource={[...players.values()]}
			loading={!synced}
			rowKey={player => player.id}
			pagination={tableState.pagination}
			onChange={tableState.onChange}
			scroll={{ x: "max-content" }}
		/>
	</PageLayout>;
}
