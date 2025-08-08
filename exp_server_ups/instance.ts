import * as lib from "@clusterio/lib";
import { BaseInstancePlugin } from "@clusterio/host";

export class InstancePlugin extends BaseInstancePlugin {
	private updateInterval?: ReturnType<typeof setInterval>;
	private gameTimes: number[] = [];

	async onStart() {
		this.updateInterval = setInterval(this.updateUps.bind(this), this.instance.config.get("exp_server_ups.update_interval"));
	}

	onExit() {
		if (this.updateInterval) {
			clearInterval(this.updateInterval);
		}
	}

	async onInstanceConfigFieldChanged(field: string, curr: unknown): Promise<void> {
		if (field === "exp_server_ups.update_interval") {
			this.onExit();
			await this.onStart();
		} else if (field === "exp_server_ups.average_interval") {
			this.gameTimes.splice(curr as number);
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
			const newGameTime = await this.sendRcon(`/_rcon return exp_server_ups.update(${ups})`);
			this.gameTimes.push(Number(newGameTime));
		} catch (error: any) {
			this.logger.error(`Failed to receive new game time: ${error}`);
		}

		if (collected > this.instance.config.get("exp_server_ups.average_interval")) {
			this.gameTimes.shift();
		}
	}
}
