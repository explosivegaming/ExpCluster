import type { Instance, InstancePluginContext } from "@clusterio/host";
import * as lib from "@clusterio/lib";
import * as messages from "./messages.js";

/** Sends the feature config from the controller to the lua side, see module/features.lua. */
export class InstancePlugin {
	instance: Instance;
	logger: lib.Logger;
	name: string;
	/** Rcon is up and the lua side can take updates */
	started = false;

	constructor(context: InstancePluginContext) {
		this.instance = context.instance;
		this.logger = context.logger;
		this.name = context.plugin.name;
	}

	async init() {
		this.instance.handle(messages.FeatureUpdatedEvent, this.handleFeatureUpdatedEvent.bind(this));
		this.instance.hooks.start.attach(this.name, this.onStart.bind(this));
		this.instance.hooks.exit.attach(this.name, this.onExit.bind(this));
		this.instance.hooks.controllerConnectionEvent.attach(this.name, this.onControllerConnectionEvent.bind(this));
	}

	async onStart() {
		this.started = true;
		await this.syncFeatures();
	}

	async onExit() {
		this.started = false;
	}

	/** A new session means the controller restarted and forgot the subscription. */
	async onControllerConnectionEvent(event: "connect" | "drop" | "resume" | "close") {
		if (event === "connect" && this.started) {
			await this.syncFeatures();
		}
	}

	/** Subscribe to updates and send every feature, updates arriving while listing are covered by the list. */
	async syncFeatures() {
		await this.instance.sendTo("controller", new lib.SubscriptionRequest(
			`exp_scenario:${messages.FeatureUpdatedEvent.name}`, "subscribe", Date.now(),
		));
		const features = await this.instance.sendTo("controller", new messages.FeatureListRequest());
		await this.luaSendFeatures(features);
	}

	async handleFeatureUpdatedEvent(event: messages.FeatureUpdatedEvent) {
		if (this.started) {
			await this.luaSendFeatures(event.updates.filter(feature => !feature.isDeleted));
		}
	}

	async luaSendFeatures(features: messages.FeatureRecord[]) {
		if (!features.length) {
			return;
		}

		const updates = features.map(feature => ({ name: feature.id, enabled: feature.enabled, values: feature.values }));
		const json = JSON.stringify(updates);
		// A long bracket level which the json does not close, string values are user input
		let level = "=";
		while (json.includes(`]${level}]`)) {
			level += "=";
		}
		await this.instance.sendRcon(
			`/sc exp_scenario.features.receive_update(helpers.json_to_table[${level}[${json}]${level}])`, true,
		);
	}
}

export default async function (context: InstancePluginContext) {
	await new InstancePlugin(context).init();
}
