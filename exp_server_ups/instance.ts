import * as lib from "@clusterio/lib";
import { BaseInstancePlugin } from "@clusterio/host";

export class InstancePlugin extends BaseInstancePlugin {
	static updateIntervalMs = 1000; // 1 second
	static maxStoredGameTimes = 10; 

	private _updateInterval?: ReturnType<typeof setInterval>;
	private gameTimes: number[] = [];

	async onStart() {
		this._updateInterval = setInterval(this.updateUps.bind(this), InstancePlugin.updateIntervalMs);
	}

	async onStop() {
		if (this._updateInterval) {
			clearInterval(this._updateInterval);
		}
	}

	async updateUps() {
		let ups = 0;
		const collected = this.gameTimes.length - 1;
		if (collected > 0) {
			const minTick = this.gameTimes[0];
			const maxTick = this.gameTimes[collected];
			const duration = collected * InstancePlugin.updateIntervalMs / 1000;
			ups = (maxTick - minTick) / (duration);
		}

		try {
			const newGameTick = await this.sendRcon(`/_rcon return exp_server_ups.update(${ups})`);
			this.gameTimes.push(Number(newGameTick));
		} catch (error: any) {
			this.logger.error(`Failed to receive new game tick: ${error}`);
		}

		if (collected > InstancePlugin.maxStoredGameTimes) {
			this.gameTimes.shift();
		}
	}
}
