import React, { useCallback, useSyncExternalStore } from "react";
import { WebPluginContext } from "@clusterio/web_ui";

import * as lib from "@clusterio/lib";
import * as messages from "../messages.js";

import ReportsPage from "./components/ReportsPage";

let reports: lib.MapSubscriber<messages.ReportUpdatedEvent> | undefined;

export function useReports() {
	const subscribe = useCallback((cb: () => void) => reports!.subscribe(cb), []);
	return useSyncExternalStore(subscribe, () => reports!.getSnapshot());
}

export default function registerPlugin(context: WebPluginContext) {
	context.control.hooks.pages.attach("exp_reports", () => [
		{
			path: "/reports",
			sidebarName: "Reports",
			permission: "exp_reports.report.list",
			content: <ReportsPage />,
		},
	]);

	reports = new lib.MapSubscriber(messages.ReportUpdatedEvent, context.control);
}
