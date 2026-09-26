import React, { useCallback, useSyncExternalStore } from "react";
import { WebPluginContext } from "@clusterio/web_ui";

import * as lib from "@clusterio/lib";
import * as messages from "../messages.js";

import RoleProperties from "./components/RoleProperties";

let roles: lib.MapSubscriber<messages.RoleUpdatedEvent> | undefined;

export function useRoles() {
	const subscribe = useCallback((cb: () => void) => roles!.subscribe(cb), []);
	return useSyncExternalStore(subscribe, () => roles!.getSnapshot());
}

export default function registerPlugin(context: WebPluginContext) {
	context.control.hooks.extensionComponents.attach("exp_roles", () => ({
		RoleViewPage: RoleProperties,
	}));

	roles = new lib.MapSubscriber(messages.RoleUpdatedEvent, context.control);
}
