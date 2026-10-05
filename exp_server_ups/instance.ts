import * as lib from "@clusterio/lib";
import type { Instance, InstancePluginContext } from "@clusterio/host";

export class InstancePlugin {
	private updateInterval?: ReturnType<typeof setInterval>;
	private gameTimes: number[] = [];

	private constructor(
		public instance: Instance,
		public logger: lib.Logger,
		public name: string,
	) {}

	static async fromContext(context: InstancePluginContext) {
		const instance = context.instance;
		const plugin = new InstancePlugin(instance, context.logger, context.plugin.name);

		const hooks = instance.hooks;
		hooks.start.attach(plugin.name, plugin.onStart.bind(plugin));
		hooks.exit.attach(plugin.name, plugin.onExit.bind(plugin));
		hooks.instanceConfigFieldChanged.attach(plugin.name, plugin.onInstanceConfigFieldChanged.bind(plugin));
		hooks.playerEvent.attach(plugin.name, plugin.onPlayerEvent.bind(plugin));
		return plugin;
	}

	async onStart() {
		if (!this.instance.config.get("factorio.settings")["auto_pause"]) {
			this.setInterval();
		}
	}

	onExit() {
		this.clearInterval();
	}

	async onInstanceConfigFieldChanged(field: string, curr: unknown): Promise<void> {
		if (field === "exp_server_ups.update_interval") {
			this.clearInterval();
			this.setInterval();
		} else if (field === "exp_server_ups.average_interval") {
			this.gameTimes.splice(curr as number);
		}
	}

	async onPlayerEvent(event: lib.PlayerEvent): Promise<void> {
		if (event.type === "join") {
			this.setInterval();
		} else if (event.type === "leave" && this.instance.playersOnline.size == 0 && this.instance.config.get("factorio.settings")["auto_pause"]) {
			this.clearInterval();
		}
	}

	setInterval() {
		if (!this.updateInterval) {
			this.updateInterval = setInterval(this.updateUps.bind(this), this.instance.config.get("exp_server_ups.update_interval"));
		}
	}

	clearInterval() {
		if (this.updateInterval) {
			clearInterval(this.updateInterval);
			this.updateInterval = undefined;
		}
	}

	async updateUps() {
		let ups = 0;
		const collected = this.gameTimes.length - 1;
		if (collected > 0) {
			const minTick = this.gameTimes[0];
			const maxTick = this.gameTimes[collected];
			const interval = this.instance.config.get("exp_server_ups.update_interval") / 1000;
			ups = (maxTick - minTick) / (collected * interval);
		}

		try {
			const newGameTime = await this.instance.sendRcon(`/_rcon return exp_server_ups.refresh(${ups})`, false, this.name);
			this.gameTimes.push(Number(newGameTime));
		} catch (error: any) {
			this.logger.error(`Failed to receive new game time: ${error}`);
		}

		if (collected > this.instance.config.get("exp_server_ups.average_interval")) {
			this.gameTimes.shift();
		}
	}
}

export default async function (context: InstancePluginContext) {
	await InstancePlugin.fromContext(context);
}
