import * as lib from "@clusterio/lib";
import { EventEmitter } from "node:events";
import { setTimeout as sleep } from "node:timers/promises";

export const discordApi = "https://discord.com/api/v10";
export const discordGateway = "wss://gateway.discord.gg/?v=10&encoding=json";
const userAgent = "DiscordBot (https://github.com/explosivegaming/ExpCluster, 7)";
const maxRetries = 5;

export type GuildRole = { id: string, name: string, color: number, position: number, managed: boolean };
export type GuildMember = { user: { id: string }, roles: string[] };

export class DiscordApiError extends Error {
	constructor(
		public status: number,
		message: string,
	) {
		super(message);
	}
}

/** Bot requests to the Discord REST API, sent one at a time and waiting out rate limits. */
export class DiscordRest {
	/** Requests wait until this time when Discord says a rate limit is used up */
	waitUntilMs = 0;
	private _queue: Promise<unknown> = Promise.resolve();

	constructor(
		/** Read on every request so a new token applies right away */
		private _token: () => string,
		public baseUrl = discordApi,
	) {}

	request(method: string, route: string): Promise<unknown> {
		const result = this._queue.then(() => this._send(method, route));
		this._queue = result.catch(() => {});
		return result;
	}

	private async _send(method: string, route: string) {
		for (let attempt = 0; ; attempt++) {
			const waitMs = this.waitUntilMs - Date.now();
			if (waitMs > 0) {
				await sleep(waitMs);
			}

			const response = await fetch(`${this.baseUrl}${route}`, {
				method,
				headers: { "Authorization": `Bot ${this._token()}`, "User-Agent": userAgent },
			});
			if (response.headers.get("x-ratelimit-remaining") === "0") {
				const resetAfter = Number(response.headers.get("x-ratelimit-reset-after")) || 0;
				this.waitUntilMs = Date.now() + resetAfter * 1e3;
			}
			if (response.status === 429 && attempt < maxRetries) {
				const body = await response.json().catch(() => ({})) as { retry_after?: number };
				const retryAfter = body.retry_after ?? (Number(response.headers.get("retry-after")) || 1);
				this.waitUntilMs = Date.now() + retryAfter * 1e3;
				continue;
			}
			if (!response.ok) {
				throw new DiscordApiError(
					response.status, `${method} ${route} responded with ${response.status}: ${await response.text()}`
				);
			}
			return response.status === 204 ? undefined : response.json();
		}
	}

	async getGuildRoles(guildId: string) {
		return await this.request("GET", `/guilds/${guildId}/roles`) as GuildRole[];
	}

	/** Undefined when the user is not in the guild. */
	async getGuildMember(guildId: string, userId: string) {
		try {
			return await this.request("GET", `/guilds/${guildId}/members/${userId}`) as GuildMember;
		} catch (err) {
			if (err instanceof DiscordApiError && err.status === 404) {
				return undefined;
			}
			throw err;
		}
	}

	async addMemberRole(guildId: string, userId: string, roleId: string) {
		await this.request("PUT", `/guilds/${guildId}/members/${userId}/roles/${roleId}`);
	}

	async removeMemberRole(guildId: string, userId: string, roleId: string) {
		await this.request("DELETE", `/guilds/${guildId}/members/${userId}/roles/${roleId}`);
	}
}

export const gatewayIntents = { GUILD_MEMBERS: 1 << 1 };

/** Close codes after which reconnecting would fail the same way, such as a bad token or missing intent. */
export const fatalCloseCodes = new Set([4004, 4010, 4011, 4012, 4013, 4014]);

type GatewayPayload = { op: number, d: any, s: number | null, t: string | null };

/**
 * stopped: not started, stopped, or closed with a fatal code.
 * connecting: socket open, waiting for Hello.
 * identifying: identify sent, waiting for READY.
 * ready: receiving dispatches.
 * waiting: closed, reconnecting after a backoff.
 */
export type GatewayState = "stopped" | "connecting" | "identifying" | "ready" | "waiting";

const gatewayTransitions: Record<GatewayState, GatewayState[]> = {
	stopped: ["connecting"],
	connecting: ["identifying", "waiting", "stopped"],
	identifying: ["ready", "waiting", "stopped"],
	ready: ["waiting", "stopped"],
	waiting: ["connecting", "stopped"],
};

export type GatewayEvents = {
	ready: [],
	dispatch: [type: string, data: any],
	fatalClose: [code: number, reason: string],
};

/**
 * Minimal Discord gateway connection which only receives dispatch events.
 *
 * It identifies again on every reconnect instead of resuming, so events sent
 * while disconnected are missed. The ready event is the place to catch up on them.
 */
export class DiscordGateway extends EventEmitter<GatewayEvents> {
	state: GatewayState = "stopped";
	backoff = new lib.ExponentialBackoff({ base: 2, max: 60 });
	private _ws?: WebSocket;
	private _heartbeatTimer?: ReturnType<typeof setTimeout>;
	private _reconnectTimer?: ReturnType<typeof setTimeout>;
	private _sequence: number | null = null;
	private _acked = true;

	constructor(
		/** Read on every identify so a new token applies on the next start */
		private _token: () => string,
		private _intents: number,
		private _logger: lib.Logger,
		public url = discordGateway,
	) {
		super();
	}

	start() {
		this._connect();
	}

	stop() {
		if (this.state === "stopped") {
			return;
		}
		this._setState("stopped");
		clearTimeout(this._reconnectTimer);
		this._close(1000);
	}

	private _setState(next: GatewayState) {
		if (!gatewayTransitions[this.state].includes(next)) {
			throw new Error(`Invalid Discord gateway transition from ${this.state} to ${next}`);
		}
		this.state = next;
	}

	private _connect() {
		this._setState("connecting");
		const ws = new WebSocket(this.url);
		this._ws = ws;
		this._acked = true;
		ws.addEventListener("message", event => {
			try {
				this._receive(JSON.parse(String(event.data)));
			} catch (err: any) {
				this._logger.error(`Discord gateway failed to handle a message:\n${err.stack}`);
			}
		});
		ws.addEventListener("close", event => this._closed(ws, event.code, event.reason));
		ws.addEventListener("error", () => {});
	}

	private _close(code: number) {
		clearTimeout(this._heartbeatTimer);
		if (this._ws && this._ws.readyState <= WebSocket.OPEN) {
			this._ws.close(code);
		}
	}

	private _send(op: number, d: unknown) {
		this._ws?.send(JSON.stringify({ op, d }));
	}

	private _heartbeat(intervalMs: number) {
		if (!this._acked) {
			this._logger.warn("Discord gateway stopped answering heartbeats, reconnecting");
			this._close(4000);
			return;
		}
		this._acked = false;
		this._send(1, this._sequence);
		this._heartbeatTimer = setTimeout(() => this._heartbeat(intervalMs), intervalMs);
	}

	private _receive(payload: GatewayPayload) {
		if (payload.s !== null && payload.s !== undefined) {
			this._sequence = payload.s;
		}
		switch (payload.op) {
			case 10: { // Hello
				this._setState("identifying");
				const intervalMs = payload.d.heartbeat_interval;
				this._heartbeatTimer = setTimeout(() => this._heartbeat(intervalMs), intervalMs * Math.random());
				this._send(2, {
					token: this._token(),
					intents: this._intents,
					properties: { os: process.platform, browser: "exp_discord_sync", device: "exp_discord_sync" },
				});
				break;
			}
			case 11: // Heartbeat ACK
				this._acked = true;
				break;
			case 1: // Heartbeat request
				this._send(1, this._sequence);
				break;
			case 7: // Reconnect
			case 9: // Invalid session
				this._close(4000);
				break;
			case 0: // Dispatch
				if (payload.t === "READY") {
					this._setState("ready");
					this.emit("ready");
				} else {
					this.emit("dispatch", payload.t!, payload.d);
				}
				break;
			default:
		}
	}

	private _closed(ws: WebSocket, code: number, reason: string) {
		if (ws !== this._ws) {
			return;
		}
		clearTimeout(this._heartbeatTimer);
		this._sequence = null;
		if (this.state === "stopped") {
			return;
		}
		if (fatalCloseCodes.has(code)) {
			this._setState("stopped");
			this.emit("fatalClose", code, reason);
			return;
		}
		this._setState("waiting");
		const delayMs = this.backoff.delay();
		this._logger.verbose(`Discord gateway closed with ${code}, reconnecting in ${Math.round(delayMs / 1e3)}s`);
		this._reconnectTimer = setTimeout(() => this._connect(), delayMs);
	}
}
