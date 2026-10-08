import type { InstancePluginContext } from "@clusterio/host";
import * as lib from "@clusterio/lib";
import * as messages from "./messages.js";
import { features, FeatureValue } from "./features.js";

/** Sends feature config to the lua side, see module/features.lua. */
export default async function (context: InstancePluginContext) {
	const { instance, plugin } = context;
	/** Rcon is up and the lua side can take updates */
	let started = false;

	/** Subscribe, then send every feature */
	async function syncFeatures() {
		await instance.sendTo("controller", new lib.SubscriptionRequest(
			`exp_scenario:${messages.FeatureUpdatedEvent.name}`, "subscribe", Date.now(),
		));
		const records = await instance.sendTo("controller", new messages.FeatureListRequest());
		await luaSendFeatures(records);
	}

	/** Every value of each feature is sent, so the lua side sets them all */
	async function luaSendFeatures(records: messages.FeatureRecord[]) {
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
		await instance.sendRcon(
			`/sc exp_scenario.features.receive_update(helpers.json_to_table[${level}[${json}]${level}])`, true,
		);
	}

	instance.handle(messages.FeatureUpdatedEvent, async event => {
		if (started) {
			await luaSendFeatures(event.updates.filter(feature => !feature.isDeleted));
		}
	});

	instance.hooks.start.attach(plugin.name, async () => {
		started = true;
		await syncFeatures();
	});

	instance.hooks.exit.attach(plugin.name, async () => {
		started = false;
	});

	// A new session means the controller restarted and forgot the subscription
	instance.hooks.controllerConnectionEvent.attach(plugin.name, async event => {
		if (event === "connect" && started) {
			await syncFeatures();
		}
	});
}
