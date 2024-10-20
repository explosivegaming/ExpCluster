import React, {
	useContext, useEffect, useState,
	useCallback, useSyncExternalStore,
} from "react";

// import {
//
// } from "antd";

import {
	BaseWebPlugin, PageLayout, PageHeader, Control, ControlContext, notifyErrorHandler,
} from "@clusterio/web_ui";

import {
	PluginExampleEvent, PluginExampleRequest,
	ExampleSubscribableUpdate, ExampleSubscribableValue,
} from "../messages";

import * as lib from "@clusterio/lib";

function MyTemplatePage() {
	const control = useContext(ControlContext);
	const plugin = control.plugins.get("exp_scenario") as WebPlugin;
	const [subscribableData, synced] = plugin.useSubscribableData();

	return <PageLayout nav={[{ name: "exp_scenario" }]}>
		<PageHeader title="exp_scenario" />
		Synced: {String(synced)} Data: {JSON.stringify([...subscribableData.values()])}
	</PageLayout>;
}

export class WebPlugin extends BaseWebPlugin {
	subscribableData = new lib.EventSubscriber(ExampleSubscribableUpdate, this.control);

	async init() {
		this.pages = [
			{
				path: "/exp_scenario",
				sidebarName: "exp_scenario",
				// This permission is client side only, so it must match the permission string of a resource request to be secure
				// An undefined value means that the page will always be visible
				permission: "exp_scenario.example.permission.subscribe",
				content: <MyTemplatePage/>,
			},
		];

		this.control.handle(PluginExampleEvent, this.handlePluginExampleEvent.bind(this));
		this.control.handle(PluginExampleRequest, this.handlePluginExampleRequest.bind(this));
	}

	useSubscribableData() {
		const control = useContext(ControlContext);
		const subscribe = useCallback((callback: () => void) => this.subscribableData.subscribe(callback), [control]);
		return useSyncExternalStore(subscribe, () => this.subscribableData.getSnapshot());
	}

	async handlePluginExampleEvent(event: PluginExampleEvent) {
		this.logger.info(JSON.stringify(event));
	}

	async handlePluginExampleRequest(request: PluginExampleRequest) {
		this.logger.info(JSON.stringify(request));
		return {
			myResponseString: request.myString,
			myResponseNumbers: request.myNumberArray,
		};
	}
}
