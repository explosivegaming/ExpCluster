import { WebPluginContext } from "@clusterio/web_ui";

import Seed from "./components/Seed";

export default function registerPlugin(context: WebPluginContext) {
	context.control.hooks.extensionComponents.attach("exp_scenario", () => ({
		RolesPage: Seed,
	}));
}
