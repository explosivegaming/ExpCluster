import React, { useCallback, useSyncExternalStore } from "react";
import { BaseWebPlugin } from "@clusterio/web_ui";

import * as lib from "@clusterio/lib";
import * as messages from "../messages";

import RoleProperties from "./components/RoleProperties";

export class WebPlugin extends BaseWebPlugin {
	roles = new lib.MapSubscriber(messages.RoleUpdatedEvent, this.control);

	async init() {
		// The core components pass a role and the plugin, which componentExtra
		// does not carry in its type
		this.componentExtra = {
			RoleViewPage: RoleProperties as React.ComponentType,
		};
	}

	useRoles() {
		const subscribe = useCallback((cb: () => void) => this.roles.subscribe(cb), []);
		return useSyncExternalStore(subscribe, () => this.roles.getSnapshot());
	}
}
