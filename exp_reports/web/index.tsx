import React, { useCallback, useSyncExternalStore } from "react";
import { BaseWebPlugin } from "@clusterio/web_ui";

import * as lib from "@clusterio/lib";
import * as messages from "../messages";

import ReportsPage from "./components/ReportsPage";

export class WebPlugin extends BaseWebPlugin {
	reports = new lib.MapSubscriber(messages.ReportUpdatedEvent, this.control);

	async init() {
		this.pages = [
			{
				path: "/reports",
				sidebarName: "Reports",
				permission: "exp_reports.report.list",
				content: <ReportsPage />,
			},
		];
	}

	useReports() {
		const subscribe = useCallback((cb: () => void) => this.reports.subscribe(cb), []);
		return useSyncExternalStore(subscribe, () => this.reports.getSnapshot());
	}
}
