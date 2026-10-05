import type { Instance, InstancePluginContext } from "@clusterio/host";
import * as lib from "@clusterio/lib";
import * as messages from "./messages.js";
import { features, FeatureValue } from "./features.js";

/** Sends feature config to the lua side, see module/features.lua. */
export class InstancePlugin {
	/** Rcon is up and the lua side can take updates */
	started = false;

	private constructor(
		public instance: Instance,
		public logger: lib.Logger,
		public name: string,
	) {}

	static async fromContext(context: InstancePluginContext) {
		const instance = context.instance;
		const plugin = new InstancePlugin(instance, context.logger, context.plugin.name);

		instance.handle(messages.FeatureUpdatedEvent, plugin.handleFeatureUpdatedEvent.bind(plugin));
		instance.hooks.start.attach(plugin.name, plugin.onStart.bind(plugin));
		instance.hooks.exit.attach(plugin.name, plugin.onExit.bind(plugin));
		instance.hooks.controllerConnectionEvent.attach(plugin.name, plugin.onControllerConnectionEvent.bind(plugin));
		return plugin;
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

	/** Subscribe, then send every feature */
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

	/** Every value of each feature is sent, so the lua side sets them all */
	async luaSendFeatures(records: messages.FeatureRecord[]) {
		if (!records.length) {
			return;
		}

		const updates = records.map(record => {
			const values: Record<string, FeatureValue> = { enabled: record.enabled };
			for (const field of features.find(feature => feature.name === record.id)?.fields ?? []) {
				values[field.name] = field.name in record.values ? record.values[field.name] : field.default;
			}
			return { name: record.id, values };
		});
		const json = JSON.stringify(updates);
		// Pick a long bracket the json does not contain
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
	await InstancePlugin.fromContext(context);
}
