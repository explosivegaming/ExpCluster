import { BaseWebPlugin } from "@clusterio/web_ui";

import Seed from "./components/Seed";

export class WebPlugin extends BaseWebPlugin {
	async init() {
		this.componentExtra = {
			RolesPage: Seed,
		};
	}
}
