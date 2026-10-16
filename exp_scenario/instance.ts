import type { InstancePluginContext } from "@clusterio/host";
import * as lib from "@clusterio/lib";
import * as messages from "./messages.js";
import { features, FeatureValue } from "./features.js";

/** Sent by the lua side when a player sets or removes their join message, see module/control/greetings.lua */
export type IpcJoinMessageSet = { player_name: string, message?: string };
/** Sent by the lua side when a player asks for their join message */
export type IpcJoinMessageGet = { player_name: string };
/** Sent by the lua side when a player leaves */
export type IpcToolbar = { player_name: string, toolbar: string };

/** Json as a lua expression for a table, inside a long bracket the json does not contain */
export function luaJson(value: unknown) {
	const json = JSON.stringify(value);
	let level = "=";
	while (json.includes(`]${level}]`)) {
		level += "=";
	}
	return `helpers.json_to_table[${level}[${json}]${level}]`;
}

/** Sends feature config and player settings to the lua side, see module/features.lua. */
export default async function (context: InstancePluginContext) {
	const { instance, logger, plugin } = context;
	/** Rcon is up and the lua side can take updates */
	let started = false;
	/** Enabled state of features which need it on this side, by name */
	const featureEnabled = new Map<string, boolean>();

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
			featureEnabled.set(record.id, record.enabled);
			const values: Record<string, FeatureValue> = { enabled: record.enabled };
			for (const field of features.find(feature => feature.name === record.id)?.fields ?? []) {
				values[field.name] = field.name in record.values ? record.values[field.name] : field.default;
			}
			return { name: record.id, values };
		});
		await instance.sendRcon(`/sc exp_scenario.features.receive_update(${luaJson(updates)})`, true);
	}

	/** Run lua with the player as `p` if they are still in the game, the data is available as `d` */
	async function luaWithPlayer(name: string, data: Record<string, unknown>, code: string) {
		if (instance.status !== "running") {
			return;
		}
		await instance.sendRcon(
			`/sc local d = ${luaJson({ ...data, name })} local p = game.get_player(d.name) if p then ${code} end`, true,
		);
	}

	async function onPlayerJoin(name: string) {
		const record = await instance.sendTo("controller", new messages.PlayerGetRequest(name));
		if (record.joinMessage && featureEnabled.get("greetings") !== false) {
			await luaWithPlayer(name, { message: record.joinMessage }, "game.print(d.message, { color = p.color })");
		}
		if (record.toolbar) {
			await luaWithPlayer(
				name, { toolbar: record.toolbar }, "exp_scenario.player_settings.receive_toolbar(d.name, d.toolbar)",
			);
		}
	}

	instance.handle(messages.FeatureUpdatedEvent, async event => {
		if (started) {
			await luaSendFeatures(event.updates.filter(feature => !feature.isDeleted));
		}
	});

	instance.server.handle("exp_scenario:join_message_set", async (event: IpcJoinMessageSet) => {
		const request = new messages.JoinMessageSetRequest(event.player_name, event.message ?? null);
		await instance.sendTo("controller", request);
	});

	instance.server.handle("exp_scenario:join_message_get", async (event: IpcJoinMessageGet) => {
		const record = await instance.sendTo("controller", new messages.PlayerGetRequest(event.player_name));
		await luaWithPlayer(
			event.player_name,
			record.joinMessage ? { message: record.joinMessage } : {},
			"p.print(d.message and { \"exp_greetings.message-get\", d.message } or { \"exp_greetings.message-none\" })",
		);
	});

	instance.server.handle("exp_scenario:toolbar", async (event: IpcToolbar) => {
		instance.sendTo("controller", new messages.PlayerToolbarEvent(event.player_name, event.toolbar));
	});

	instance.hooks.playerEvent.attach(plugin.name, async event => {
		if (event.type === "join") {
			await onPlayerJoin(event.name).catch(err => logger.error(
				`Error sending the settings of ${event.name}:\n${err.stack ?? err.message}`,
			));
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
