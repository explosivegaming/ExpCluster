import * as lib from "@clusterio/lib";
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
	private queue: Promise<unknown> = Promise.resolve();

	constructor(
		private token: string,
		public baseUrl = discordApi,
	) {}

	request(method: string, route: string): Promise<unknown> {
		const result = this.queue.then(() => this.send(method, route));
		this.queue = result.catch(() => {});
		return result;
	}

	private async send(method: string, route: string) {
		for (let attempt = 0; ; attempt++) {
			const waitMs = this.waitUntilMs - Date.now();
			if (waitMs > 0) {
				await sleep(waitMs);
			}

			const response = await fetch(`${this.baseUrl}${route}`, {
				method,
				headers: { "Authorization": `Bot ${this.token}`, "User-Agent": userAgent },
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
 * Minimal Discord gateway connection which only receives dispatch events.
 *
 * It identifies again on every reconnect instead of resuming, so events sent
 * while disconnected are missed. onReady is the place to catch up on them.
 */
export class DiscordGateway {
	ws?: WebSocket;
	private heartbeatTimer?: ReturnType<typeof setTimeout>;
	private reconnectTimer?: ReturnType<typeof setTimeout>;
	private sequence: number | null = null;
	private acked = true;
	private stopped = false;
	backoff = new lib.ExponentialBackoff({ base: 2, max: 60 });

	constructor(
		private token: string,
		private intents: number,
		private logger: lib.Logger,
		public handlers: {
			onReady?: () => void,
			onDispatch?: (type: string, data: any) => void,
			onFatalClose?: (code: number, reason: string) => void,
		},
		public url = discordGateway,
	) {}

	start() {
		this.stopped = false;
		this.connect();
	}

	stop() {
		this.stopped = true;
		clearTimeout(this.reconnectTimer);
		this.close(1000);
	}

	private connect() {
		const ws = new WebSocket(this.url);
		this.ws = ws;
		this.acked = true;
		ws.addEventListener("message", event => this.receive(JSON.parse(String(event.data))));
		ws.addEventListener("close", event => this.closed(ws, event.code, event.reason));
		ws.addEventListener("error", () => {});
	}

	private close(code: number) {
		clearTimeout(this.heartbeatTimer);
		if (this.ws && this.ws.readyState <= WebSocket.OPEN) {
			this.ws.close(code);
		}
	}

	private send(op: number, d: unknown) {
		this.ws?.send(JSON.stringify({ op, d }));
	}

	private heartbeat(intervalMs: number) {
		if (!this.acked) {
			this.logger.warn("Discord gateway stopped answering heartbeats, reconnecting");
			this.close(4000);
			return;
		}
		this.acked = false;
		this.send(1, this.sequence);
		this.heartbeatTimer = setTimeout(() => this.heartbeat(intervalMs), intervalMs);
	}

	private receive(payload: GatewayPayload) {
		if (payload.s !== null && payload.s !== undefined) {
			this.sequence = payload.s;
		}
		switch (payload.op) {
			case 10: { // Hello
				const intervalMs = payload.d.heartbeat_interval;
				this.heartbeatTimer = setTimeout(() => this.heartbeat(intervalMs), intervalMs * Math.random());
				this.send(2, {
					token: this.token,
					intents: this.intents,
					properties: { os: process.platform, browser: "exp_discord_sync", device: "exp_discord_sync" },
				});
				break;
			}
			case 11: // Heartbeat ACK
				this.acked = true;
				break;
			case 1: // Heartbeat request
				this.send(1, this.sequence);
				break;
			case 7: // Reconnect
			case 9: // Invalid session
				this.close(4000);
				break;
			case 0: // Dispatch
				if (payload.t === "READY") {
					this.handlers.onReady?.();
				} else {
					this.handlers.onDispatch?.(payload.t!, payload.d);
				}
				break;
			default:
		}
	}

	private closed(ws: WebSocket, code: number, reason: string) {
		if (ws !== this.ws) {
			return;
		}
		clearTimeout(this.heartbeatTimer);
		this.sequence = null;
		if (this.stopped) {
			return;
		}
		if (fatalCloseCodes.has(code)) {
			this.stopped = true;
			this.handlers.onFatalClose?.(code, reason);
			return;
		}
		const delayMs = this.backoff.delay();
		this.logger.verbose(`Discord gateway closed with ${code}, reconnecting in ${Math.round(delayMs / 1e3)}s`);
		this.reconnectTimer = setTimeout(() => this.connect(), delayMs);
	}
}
