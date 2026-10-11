import type { Controller, ControllerPluginContext } from "@clusterio/controller";
import * as lib from "@clusterio/lib";
import * as messages from "./messages.js";
import * as crypto from "node:crypto";
import * as path from "node:path";

const discordApi = "https://discord.com/api/v10";
const stateTimeoutS = 10 * 60;
const sessionTimeoutMs = 30 * 60e3;
const codeTimeoutMs = 10 * 60e3;
const codeLength = 6;
// 0, O, 1 and I are left out because they are easy to mix up when typing the code in game
const codeLetters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

type DiscordUser = { id: string, name: string };
type Session = DiscordUser & { expiresMs: number, code?: string };
type LinkCode = { sessionId: string, expiresMs: number };

/** What an http route answers with, kept apart from express so it can be tested. */
export type RouteResult =
	| { redirect: string, cookie?: string }
	| { status: number, json: unknown };

type HttpRequest = {
	query: Record<string, unknown>,
	headers: Record<string, string | string[] | undefined>,
};
type HttpResponse = {
	status(code: number): HttpResponse,
	json(body: unknown): unknown,
	redirect(url: string): void,
	setHeader(name: string, value: string): unknown,
};

function readCookie(header: string | string[] | undefined, name: string) {
	for (const part of String(header ?? "").split(";")) {
		const [key, ...value] = part.trim().split("=");
		if (key === name) {
			return value.join("=");
		}
	}
	return undefined;
}

function randomCode() {
	let code = "";
	for (let i = 0; i < codeLength; i++) {
		code += codeLetters[crypto.randomInt(codeLetters.length)];
	}
	return code;
}

export class ControllerPlugin {
	/** Logins which have been through Discord, by session id */
	sessions = new Map<string, Session>();
	/** Codes waiting to be used in game, by code */
	codes = new Map<string, LinkCode>();
	cleanupInterval?: ReturnType<typeof setInterval>;

	private constructor(
		public controller: Controller,
		public logger: lib.Logger,
		public name: string,
		public accounts: lib.SubscribableDatastore<messages.DiscordAccountRecord>,
	) {}

	static async fromContext(context: ControllerPluginContext) {
		const controller = context.controller;
		const databaseDirectory = controller.config.get("controller.database_directory");

		const accounts = new lib.SubscribableDatastore(
			...await new lib.JsonIdDatastoreProvider(
				path.join(databaseDirectory, "exp_discord", "accounts.json"),
				messages.DiscordAccountRecord.fromJSON.bind(messages.DiscordAccountRecord),
			).bootstrap()
		);

		const plugin = new ControllerPlugin(controller, context.logger, context.plugin.name, accounts);

		controller.handle(messages.DiscordLinkRequest, plugin.handleLinkRequest.bind(plugin));
		controller.handle(messages.DiscordUnlinkRequest, plugin.handleUnlinkRequest.bind(plugin));
		controller.handle(messages.DiscordLinkGetRequest, plugin.handleLinkGetRequest.bind(plugin));

		plugin.addRoutes();
		plugin.cleanupInterval = setInterval(() => plugin.removeExpired(), 60e3);
		plugin.cleanupInterval.unref();

		controller.hooks.save.attach(plugin.name, plugin.onSave.bind(plugin));
		controller.hooks.shutdown.attach(plugin.name, plugin.onShutdown.bind(plugin));
		return plugin;
	}

	async onSave() {
		await this.accounts.save();
	}

	async onShutdown() {
		clearInterval(this.cleanupInterval);
		await this.accounts.save();
	}

	removeExpired(now = Date.now()) {
		for (const [id, session] of this.sessions) {
			if (session.expiresMs < now) {
				this.sessions.delete(id);
			}
		}
		for (const [code, entry] of this.codes) {
			if (entry.expiresMs < now) {
				this.codes.delete(code);
			}
		}
	}

	/*
		Http routes
	*/

	addRoutes() {
		const app = this.controller.app;
		const route = (handler: (req: HttpRequest) => Promise<RouteResult>) => (
			(req: HttpRequest, res: HttpResponse, next: (err: unknown) => void) => {
				handler(req).then(result => {
					if ("redirect" in result) {
						if (result.cookie) {
							res.setHeader("Set-Cookie", result.cookie);
						}
						res.redirect(result.redirect);
					} else {
						res.status(result.status).json(result.json);
					}
				}).catch(next);
			}
		);

		app.get("/api/exp_discord/authorize", route(async () => this.authorize()));
		app.get("/api/exp_discord/callback", route(async req => this.callback(
			req.query, readCookie(req.headers.cookie, "exp_discord_state"),
		)));
		app.get("/api/exp_discord/accounts", route(async req => this.listAccounts(this.sessionId(req))));
		app.post("/api/exp_discord/login", route(async req => this.login(this.sessionId(req), req.query.name)));
		app.post("/api/exp_discord/link_code", route(async req => this.linkCode(this.sessionId(req))));
	}

	sessionId(req: HttpRequest) {
		const header = String(req.headers.authorization ?? "");
		return header.startsWith("Bearer ") ? header.slice(7) : "";
	}

	redirectUri() {
		return new URL("api/exp_discord/callback", this.controller.getControllerUrl()).href;
	}

	/** Back to the web ui, with the outcome in the fragment so it never reaches a server log. */
	webRedirect(key: "session" | "error", value: string): RouteResult {
		const url = new URL(this.controller.getControllerUrl());
		url.hash = `exp_discord_${key}=${encodeURIComponent(value)}`;
		return { redirect: url.href };
	}

	async authorize(): Promise<RouteResult> {
		const clientId = this.controller.config.get("exp_discord.client_id");
		if (!clientId || !this.controller.config.get("exp_discord.client_secret")) {
			return this.webRedirect("error", "Discord login is not configured on this controller");
		}

		const state = crypto.randomBytes(16).toString("base64url");
		const url = new URL("https://discord.com/oauth2/authorize");
		url.search = new URLSearchParams({
			response_type: "code",
			client_id: clientId,
			scope: "identify",
			state,
			redirect_uri: this.redirectUri(),
			prompt: "none",
		}).toString();

		const callbackUrl = new URL(this.redirectUri());
		const secure = callbackUrl.protocol === "https:" ? "; Secure" : "";
		return {
			redirect: url.href,
			cookie: `exp_discord_state=${state}; Path=${callbackUrl.pathname}; Max-Age=${stateTimeoutS}; HttpOnly; SameSite=Lax${secure}`,
		};
	}

	async callback(query: Record<string, unknown>, cookieState: string | undefined): Promise<RouteResult> {
		if (typeof query.error === "string") {
			return this.webRedirect("error", query.error === "access_denied" ? "Discord login was cancelled" : query.error);
		}
		if (typeof query.state !== "string" || !cookieState || query.state !== cookieState) {
			return this.webRedirect("error", "Discord login expired, please try again");
		}
		if (typeof query.code !== "string") {
			return this.webRedirect("error", "Discord did not return a login code");
		}

		let discordUser;
		try {
			discordUser = await this.fetchDiscordUser(query.code);
		} catch (err: any) {
			this.logger.warn(`Discord login failed: ${err.message}`);
			return this.webRedirect("error", "Discord login failed, please try again");
		}

		const account = this.accounts.getMutable(discordUser.id);
		if (account && account.name !== discordUser.name) {
			account.name = discordUser.name;
			this.accounts.set(account);
		}

		const sessionId = crypto.randomBytes(32).toString("base64url");
		this.sessions.set(sessionId, { ...discordUser, expiresMs: Date.now() + sessionTimeoutMs });
		return this.webRedirect("session", sessionId);
	}

	/** Exchange the code from the callback for the Discord user who logged in. */
	async fetchDiscordUser(code: string): Promise<DiscordUser> {
		const tokenResponse = await fetch(`${discordApi}/oauth2/token`, {
			method: "POST",
			headers: { "Content-Type": "application/x-www-form-urlencoded" },
			body: new URLSearchParams({
				client_id: this.controller.config.get("exp_discord.client_id") ?? "",
				client_secret: this.controller.config.get("exp_discord.client_secret") ?? "",
				grant_type: "authorization_code",
				code,
				redirect_uri: this.redirectUri(),
			}),
		});
		if (!tokenResponse.ok) {
			throw new Error(`token exchange responded with ${tokenResponse.status}: ${await tokenResponse.text()}`);
		}
		const token = await tokenResponse.json() as { access_token: string, token_type: string };

		const userResponse = await fetch(`${discordApi}/users/@me`, {
			headers: { Authorization: `${token.token_type} ${token.access_token}` },
		});
		if (!userResponse.ok) {
			throw new Error(`users/@me responded with ${userResponse.status}`);
		}
		const user = await userResponse.json() as { id: string, username: string, global_name?: string | null };
		return { id: user.id, name: user.global_name || user.username };
	}

	getSession(sessionId: string) {
		const session = this.sessions.get(sessionId);
		if (!session || session.expiresMs < Date.now()) {
			return undefined;
		}
		return session;
	}

	async listAccounts(sessionId: string): Promise<RouteResult> {
		const session = this.getSession(sessionId);
		if (!session) {
			return { status: 401, json: { error: "Discord login expired, please log in again" } };
		}
		return {
			status: 200,
			json: {
				discord: { id: session.id, name: session.name },
				accounts: this.accounts.get(session.id)?.factorioNames ?? [],
				max_accounts: this.controller.config.get("exp_discord.max_accounts"),
			},
		};
	}

	async login(sessionId: string, name: unknown): Promise<RouteResult> {
		const session = this.getSession(sessionId);
		if (!session) {
			return { status: 401, json: { error: "Discord login expired, please log in again" } };
		}

		const factorioNames = this.accounts.get(session.id)?.factorioNames ?? [];
		if (typeof name !== "string" || !factorioNames.some(linked => linked.toLowerCase() === name.toLowerCase())) {
			return { status: 403, json: { error: "That Factorio account is not linked to your Discord account" } };
		}

		const user = this.controller.users.getByName(name);
		if (!user) {
			return { status: 404, json: { error: `There is no user called ${name}` } };
		}
		if (user.isBanned) {
			return { status: 403, json: { error: `${user.name} is banned` } };
		}

		this.sessions.delete(sessionId);
		if (session.code) {
			this.codes.delete(session.code);
		}
		return { status: 200, json: { token: this.controller.users.signUserToken(user) } };
	}

	/** A code which links the player who types it in game to this Discord account. */
	async linkCode(sessionId: string): Promise<RouteResult> {
		const session = this.getSession(sessionId);
		if (!session) {
			return { status: 401, json: { error: "Discord login expired, please log in again" } };
		}

		const now = Date.now();
		let entry = session.code ? this.codes.get(session.code) : undefined;
		if (!entry || entry.expiresMs < now) {
			let code = randomCode();
			while (this.codes.has(code)) {
				code = randomCode();
			}
			entry = { sessionId, expiresMs: now + codeTimeoutMs };
			this.codes.set(code, entry);
			session.code = code;
		}
		return { status: 200, json: { code: session.code, expires_ms: entry.expiresMs } };
	}

	/*
		Links
	*/

	findAccount(playerName: string) {
		const name = playerName.toLowerCase();
		for (const account of this.accounts.values()) {
			if (account.factorioNames.some(linked => linked.toLowerCase() === name)) {
				return account;
			}
		}
		return undefined;
	}

	/** Remove a player from the account they are linked to, the account goes once nothing is left. */
	removeLink(playerName: string) {
		const found = this.findAccount(playerName);
		if (!found) {
			return null;
		}

		const account = this.accounts.getMutable(found.id)!;
		const name = playerName.toLowerCase();
		account.factorioNames = account.factorioNames.filter(linked => linked.toLowerCase() !== name);
		if (account.factorioNames.length) {
			this.accounts.set(account);
		} else {
			this.accounts.delete(account);
		}
		return { id: account.id, name: account.name };
	}

	async handleLinkRequest(request: messages.DiscordLinkRequest) {
		const code = request.code.trim().toUpperCase();
		const entry = this.codes.get(code);
		const session = entry ? this.sessions.get(entry.sessionId) : undefined;
		if (!entry || !session || entry.expiresMs < Date.now()) {
			throw new lib.RequestError("This code is invalid or has expired, get a new one from the website");
		}

		const name = request.playerName.toLowerCase();
		const existing = this.accounts.get(session.id);
		const alreadyLinked = existing?.factorioNames.some(linked => linked.toLowerCase() === name);
		const maxAccounts = this.controller.config.get("exp_discord.max_accounts");
		if (!alreadyLinked && (existing?.factorioNames.length ?? 0) >= maxAccounts) {
			throw new lib.RequestError(
				`${session.name} already has ${maxAccounts} Factorio accounts linked, unlink one first`
			);
		}

		this.codes.delete(code);
		delete session.code;
		if (!alreadyLinked) {
			// The player proved they own this Factorio account, so it moves over from any other Discord account
			this.removeLink(request.playerName);
			const account = this.accounts.getMutable(session.id)
				?? new messages.DiscordAccountRecord(session.id, session.name, []);
			account.name = session.name;
			account.factorioNames = [...account.factorioNames, request.playerName];
			this.accounts.set(account);
		}
		return { id: session.id, name: session.name };
	}

	async handleUnlinkRequest(request: messages.DiscordUnlinkRequest) {
		return this.removeLink(request.playerName);
	}

	async handleLinkGetRequest(request: messages.DiscordLinkGetRequest) {
		const account = this.findAccount(request.playerName);
		return account ? { id: account.id, name: account.name } : null;
	}
}

export default async function (context: ControllerPluginContext) {
	await ControllerPlugin.fromContext(context);
}
