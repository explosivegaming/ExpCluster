import * as lib from "@clusterio/lib";
import type { InstancePluginContext } from "@clusterio/host";

export default async function (context: InstancePluginContext) {
	const { instance, logger, plugin } = context;
	let updateInterval: ReturnType<typeof setInterval> | undefined;
	const gameTimes: number[] = [];

	function startUpdates() {
		if (!updateInterval) {
			updateInterval = setInterval(updateUps, instance.config.get("exp_server_ups.update_interval"));
		}
	}

	function stopUpdates() {
		if (updateInterval) {
			clearInterval(updateInterval);
			updateInterval = undefined;
		}
	}

	async function updateUps() {
		let ups = 0;
		const collected = gameTimes.length - 1;
		if (collected > 0) {
			const minTick = gameTimes[0];
			const maxTick = gameTimes[collected];
			const interval = instance.config.get("exp_server_ups.update_interval") / 1000;
			ups = (maxTick - minTick) / (collected * interval);
		}

		try {
			const newGameTime = await instance.sendRcon(`/_rcon return exp_server_ups.refresh(${ups})`, false, plugin.name);
			gameTimes.push(Number(newGameTime));
		} catch (error: any) {
			logger.error(`Failed to receive new game time: ${error}`);
		}

		if (collected > instance.config.get("exp_server_ups.average_interval")) {
			gameTimes.shift();
		}
	}

	const hooks = instance.hooks;
	hooks.start.attach(plugin.name, async () => {
		if (!instance.config.get("factorio.settings")["auto_pause"]) {
			startUpdates();
		}
	});

	hooks.exit.attach(plugin.name, stopUpdates);

	hooks.instanceConfigFieldChanged.attach(plugin.name, async (field, curr) => {
		if (field === "exp_server_ups.update_interval") {
			stopUpdates();
			startUpdates();
		} else if (field === "exp_server_ups.average_interval") {
			gameTimes.splice(curr as number);
		}
	});

	hooks.playerEvent.attach(plugin.name, async (event: lib.PlayerEvent) => {
		if (event.type === "join") {
			startUpdates();
		} else if (event.type === "leave" && instance.playersOnline.size == 0 && instance.config.get("factorio.settings")["auto_pause"]) {
			stopUpdates();
		}
	});
}
