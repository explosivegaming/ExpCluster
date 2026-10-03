import React, { useCallback, useSyncExternalStore } from "react";
import { WebPluginContext } from "@clusterio/web_ui";

import * as lib from "@clusterio/lib";
import * as messages from "../messages.js";

import FeaturesPage from "./components/FeaturesPage";
import Seed from "./components/Seed";

let features: lib.MapSubscriber<messages.FeatureUpdatedEvent> | undefined;

export function useFeatures() {
	const subscribe = useCallback((cb: () => void) => features!.subscribe(cb), []);
	return useSyncExternalStore(subscribe, () => features!.getSnapshot());
}

export default function registerPlugin(context: WebPluginContext) {
	context.control.hooks.extensionComponents.attach("exp_scenario", () => ({
		RolesPage: Seed,
	}));

	context.control.hooks.pages.attach("exp_scenario", () => [
		{
			path: "/scenario_features",
			sidebarName: "Scenario Features",
			permission: "exp_scenario.config.view",
			content: <FeaturesPage />,
		},
	]);

	features = new lib.MapSubscriber(messages.FeatureUpdatedEvent, context.control);
}
