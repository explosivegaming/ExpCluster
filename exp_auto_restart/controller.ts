import type {
	Controller, ControllerPluginContext, HostConnection, HostRecord, InstanceRecord,
} from "@clusterio/controller";
import * as lib from "@clusterio/lib";

/** How often hosts are checked for a pending restart */
export const CHECK_INTERVAL_MS = 10_000;
/** How long to wait for a restarted host to report its instances back before giving up on starting them */
export const PENDING_TIMEOUT_MS = 10 * 60_000;

/** A host that was told to restart and has not reported all of its instances back yet */
export interface PendingRestart {
	requestedAtMs: number;
	/** Instances that were running when the restart was requested */
	instanceIds: Set<number>;
}

export class AutoRestart {
	controller: Controller;
	logger: lib.Logger;
	name: string;

	/** When each host, and the cluster as a whole, last became empty of players. Absent while players are online. */
	idleSince = new Map<number | "cluster", number>();
	/** Hosts that were told to restart and are waiting for their instances to come back */
	pending = new Map<number, PendingRestart>();
	/** Process start time of each host last asked to restart, so the same process is not asked twice */
	requested = new Map<number, number>();
	/** Hosts already warned about not being restartable */
	warned = new Set<number | "controller">();
	controllerRestarting = false;
	private checkInterval?: ReturnType<typeof setInterval>;

	constructor(context: ControllerPluginContext) {
		this.controller = context.controller;
		this.logger = context.logger;
		this.name = context.plugin.name;
	}

	/** Attach to the controller hooks and start checking for restarts. */
	start() {
		const hooks = this.controller.hooks;
		hooks.shutdown.attach(this.name, () => this.stop());
		hooks.playerEvent.attach(this.name, (instance, event) => this.onPlayerEvent(instance, event));
		hooks.instanceStatusChanged.attach(this.name, (instance, prev) => this.onInstanceStatusChanged(instance, prev));
		hooks.hostConnectionEvent.attach(this.name, (connection, event) => this.onHostConnectionEvent(connection, event));

		if (this.controller.config.get("controller.system_metrics_interval") <= 0) {
			this.logger.warn(
				"controller.system_metrics_interval is 0, so the controller never learns which hosts need a restart"
			);
		}
		this.refreshIdle();
		this.checkInterval = setInterval(() => {
			this.check().catch((err: any) => {
				this.logger.error(`Unexpected error checking for restarts:\n${err.stack ?? err.message}`);
			});
		}, CHECK_INTERVAL_MS);
		this.checkInterval.unref();
	}

	stop() {
		clearInterval(this.checkInterval);
	}

	onPlayerEvent(instance: InstanceRecord, event: lib.PlayerEvent) {
		if (event.type === "join" || event.type === "leave") {
			this.refreshIdle();
		}
	}

	onInstanceStatusChanged(instance: InstanceRecord, prev?: lib.InstanceStatus) {
		this.refreshIdle();
		// A host reports every instance it has when it connects, which is how
		// a restarted host announces it is back
		if (prev === "unknown") {
			this.instanceReported(instance);
		}
	}

	onHostConnectionEvent(connection: HostConnection, event: "connect" | "drop" | "resume" | "close") {
		if (event === "connect" || event === "close") {
			this.refreshIdle();
		}
	}

	/** Players online per host, counted from the users online on running instances. */
	onlinePlayers() {
		const counts = new Map<number, number>();
		for (const user of this.controller.users.records.values()) {
			if (user.isDeleted) {
				continue;
			}
			for (const instanceId of user.instances) {
				const instance = this.controller.instances.get(instanceId);
				// Nobody is online on an instance that is not running, whatever
				// the user records say after a host crashed
				if (!instance || instance.status !== "running") {
					continue;
				}
				const hostId = instance.config.get("instance.assigned_host");
				if (hostId === null) {
					continue;
				}
				counts.set(hostId, (counts.get(hostId) ?? 0) + 1);
			}
		}
		return counts;
	}

	/** Record when connected hosts and the cluster became empty, from the players online now. */
	refreshIdle(nowMs = Date.now()) {
		const counts = this.onlinePlayers();
		for (const host of this.controller.hosts.values()) {
			if (host.isDeleted || !host.connected) {
				this.idleSince.delete(host.id);
				continue;
			}
			this.markIdle(host.id, !counts.get(host.id), nowMs);
		}

		let total = 0;
		for (const count of counts.values()) {
			total += count;
		}
		this.markIdle("cluster", total === 0, nowMs);
	}

	private markIdle(key: number | "cluster", idle: boolean, nowMs: number) {
		if (!idle) {
			this.idleSince.delete(key);
		} else if (!this.idleSince.has(key)) {
			this.idleSince.set(key, nowMs);
		}
	}

	/** How long a host has been without players, or undefined while it has some. Uses the whole cluster with scope cluster. */
	idleMs(hostId: number, nowMs: number) {
		const scope = this.controller.config.get("exp_auto_restart.scope");
		const since = this.idleSince.get(scope === "cluster" ? "cluster" : hostId);
		return since === undefined ? undefined : nowMs - since;
	}

	/** Restart every host, and the controller if enabled, that needs it and has been empty for long enough. */
	async check(nowMs = Date.now()) {
		this.refreshIdle(nowMs);
		this.expirePending(nowMs);
		const waitMs = this.controller.config.get("exp_auto_restart.idle_seconds") * 1000;

		for (const system of this.controller.systems.values()) {
			if (system.id === "controller" || system.isDeleted || !system.restartRequired) {
				continue;
			}
			const hostId = system.id;
			const host = this.controller.hosts.get(hostId);
			if (!host || host.isDeleted || !host.connected) {
				continue;
			}
			// Already asked, either waiting for it to come back or it refused
			if (this.pending.has(hostId) || this.requested.get(hostId) === system.processStartedAtMs) {
				continue;
			}
			if (!system.canRestart) {
				this.warnOnce(hostId, `Host ${host.name} needs a restart but is not run with --can-restart`);
				continue;
			}
			const idleMs = this.idleMs(hostId, nowMs);
			if (idleMs === undefined || idleMs < waitMs) {
				continue;
			}
			await this.restartHost(host, system, idleMs, nowMs);
		}

		if (this.controller.config.get("exp_auto_restart.restart_controller")) {
			await this.checkController(nowMs, waitMs);
		}
	}

	async restartHost(host: Readonly<HostRecord>, system: lib.SystemInfo, idleMs: number, nowMs: number) {
		const running = [...this.controller.instances.values()].filter(
			instance => instance.status === "running" && instance.config.get("instance.assigned_host") === host.id
		);
		this.requested.set(host.id, system.processStartedAtMs);
		if (running.length && this.controller.config.get("exp_auto_restart.start_instances")) {
			this.pending.set(host.id, {
				requestedAtMs: nowMs,
				instanceIds: new Set(running.map(instance => instance.id)),
			});
		}
		this.logger.info(
			`Restarting host ${host.name} after ${Math.round(idleMs / 1000)} s without players, ` +
			`${running.length} instance(s) running`
		);

		try {
			await this.controller.sendTo({ hostId: host.id }, new lib.HostRestartRequest());
		} catch (err: any) {
			this.pending.delete(host.id);
			// The host refusing is final for this process, anything else is retried
			if (!(err instanceof lib.RequestError)) {
				this.requested.delete(host.id);
			}
			this.logger.error(`Failed to restart host ${host.name}: ${err.message}`);
		}
	}

	/** An instance on a host that reconnected has reported its status. */
	instanceReported(instance: InstanceRecord) {
		const hostId = instance.config.get("instance.assigned_host");
		if (hostId === null) {
			return;
		}
		const pending = this.pending.get(hostId);
		if (!pending?.instanceIds.delete(instance.id)) {
			return;
		}
		if (!pending.instanceIds.size) {
			this.pending.delete(hostId);
		}

		// The host starts these itself right after reporting them
		if (instance.status !== "stopped" || instance.config.get("instance.auto_start")) {
			return;
		}
		this.startInstance(instance);
	}

	async startInstance(instance: InstanceRecord) {
		const name = instance.config.get("instance.name");
		this.logger.info(`Starting ${name} again after its host restarted`);
		try {
			await this.controller.sendTo({ instanceId: instance.id }, new lib.InstanceStartRequest());
		} catch (err: any) {
			this.logger.error(`Failed to start ${name} after its host restarted: ${err.message}`);
		}
	}

	/** Forget hosts that were restarted but never reported their instances back. */
	expirePending(nowMs: number) {
		for (const [hostId, pending] of this.pending) {
			if (nowMs - pending.requestedAtMs >= PENDING_TIMEOUT_MS) {
				this.pending.delete(hostId);
				this.logger.warn(
					`Host ${hostId} has not reported back since it was restarted, giving up on starting its instances`
				);
			}
		}
	}

	async checkController(nowMs: number, waitMs: number) {
		if (this.controllerRestarting) {
			return;
		}
		const system = this.controller.systems.get("controller");
		if (!system?.restartRequired) {
			return;
		}
		if (!system.canRestart) {
			this.warnOnce("controller", "The controller needs a restart but is not run with --can-restart");
			return;
		}
		const since = this.idleSince.get("cluster");
		if (since === undefined || nowMs - since < waitMs) {
			return;
		}
		const downgrade = await this.controller.checkRestartDowngrade();
		if (downgrade) {
			this.warnOnce(
				"controller",
				`Not restarting the controller because installed version ${downgrade.installedVersion} ` +
				`is older than running version ${downgrade.runningVersion}`
			);
			return;
		}

		this.controllerRestarting = true;
		this.logger.info(`Restarting controller after ${Math.round((nowMs - since) / 1000)} s without players`);
		this.controller.shouldRestart = true;
		this.controller.stop().catch((err: any) => {
			this.logger.error(`Failed to restart the controller: ${err.message}`);
		});
	}

	private warnOnce(key: number | "controller", message: string) {
		if (this.warned.has(key)) {
			return;
		}
		this.warned.add(key);
		this.logger.warn(message);
	}
}

export default async function (context: ControllerPluginContext) {
	new AutoRestart(context).start();
}
