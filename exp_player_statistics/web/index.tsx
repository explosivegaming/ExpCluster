import React, { useCallback, useSyncExternalStore } from "react";
import { WebPluginContext } from "@clusterio/web_ui";

import * as lib from "@clusterio/lib";
import * as messages from "../messages.js";

import StatisticsPage from "./components/StatisticsPage";
import UserStatistics from "./components/UserStatistics";

let players: lib.MapSubscriber<messages.PlayerStatisticsUpdatedEvent> | undefined;

export function usePlayerStatistics() {
	const subscribe = useCallback((cb: () => void) => players!.subscribe(cb), []);
	return useSyncExternalStore(subscribe, () => players!.getSnapshot());
}

export default function registerPlugin(context: WebPluginContext) {
	context.control.hooks.extensionComponents.attach("exp_player_statistics", () => ({
		UserViewPage: UserStatistics,
	}));

	context.control.hooks.pages.attach("exp_player_statistics", () => [
		{
			path: "/exp_player_statistics",
			sidebarName: "Statistics",
			permission: "exp_player_statistics.view",
			content: <StatisticsPage />,
		},
	]);

	players = new lib.MapSubscriber(messages.PlayerStatisticsUpdatedEvent, context.control);
}
