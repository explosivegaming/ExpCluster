import { useCallback, useSyncExternalStore } from "react";
import { WebPluginContext } from "@clusterio/web_ui";

import * as lib from "@clusterio/lib";
import * as messages from "../messages.js";

import RoleDiscordRoles from "./components/RoleDiscordRoles";

let mappings: lib.MapSubscriber<messages.RoleMappingUpdatedEvent> | undefined;

export function useRoleMappings() {
	const subscribe = useCallback((cb: () => void) => mappings!.subscribe(cb), []);
	return useSyncExternalStore(subscribe, () => mappings!.getSnapshot());
}

export default function registerPlugin(context: WebPluginContext) {
	context.control.hooks.extensionComponents.attach("exp_discord_sync", () => ({
		RoleViewPageBeforePermissions: RoleDiscordRoles,
	}));

	mappings = new lib.MapSubscriber(messages.RoleMappingUpdatedEvent, context.control);
}
