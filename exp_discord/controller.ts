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
type WebLink = { playerName: string, expiresMs: number };

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
	/** Links started from the user page, by ticket until authorize turns them into a state */
	linkTickets = new Map<string, WebLink>();
	/** Links waiting for the Discord callback, by OAuth state */
	pendingLinks = new Map<string, WebLink>();
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
		controller.handle(messages.DiscordLinkStartRequest, plugin.handleLinkStartRequest.bind(plugin));

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
		for (const map of [this.codes, this.linkTickets, this.pendingLinks]) {
			for (const [key, entry] of map) {
				if (entry.expiresMs < now) {
					map.delete(key);
				}
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

		app.get("/api/exp_discord/authorize", route(async req => this.authorize(req.query.link)));
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
	webRedirect(key: "session" | "error", value: string, page = ""): RouteResult {
		const url = new URL(page, this.controller.getControllerUrl());
		url.hash = `exp_discord_${key}=${encodeURIComponent(value)}`;
		return { redirect: url.href };
	}

	userPage(playerName: string) {
		return `users/${encodeURIComponent(playerName)}/view`;
	}

	async authorize(linkTicket?: unknown): Promise<RouteResult> {
		let link: WebLink | undefined;
		if (linkTicket !== undefined) {
			link = typeof linkTicket === "string" ? this.linkTickets.get(linkTicket) : undefined;
			if (!link || link.expiresMs < Date.now()) {
				return this.webRedirect("error", "Discord link expired, please try again", "users");
			}
			this.linkTickets.delete(linkTicket as string);
		}
		const page = link ? this.userPage(link.playerName) : "";

		const clientId = this.controller.config.get("exp_discord.client_id");
		if (!clientId || !this.controller.config.get("exp_discord.client_secret")) {
			return this.webRedirect("error", "Discord login is not configured on this controller", page);
		}

		const state = crypto.randomBytes(16).toString("base64url");
		if (link) {
			this.pendingLinks.set(state, { playerName: link.playerName, expiresMs: Date.now() + stateTimeoutS * 1e3 });
		}
		const url = new URL("https://discord.com/oauth2/authorize");
		url.search = new URLSearchParams({
			response_type: "code",
			client_id: clientId,
			scope: "identify",
			state,
			redirect_uri: this.redirectUri(),
			// Linking always shows the Discord consent screen, so it can't happen without the user noticing
			...(link ? {} : { prompt: "none" }),
		}).toString();

		const callbackUrl = new URL(this.redirectUri());
		const secure = callbackUrl.protocol === "https:" ? "; Secure" : "";
		return {
			redirect: url.href,
			cookie: `exp_discord_state=${state}; Path=${callbackUrl.pathname}; Max-Age=${stateTimeoutS}; HttpOnly; SameSite=Lax${secure}`,
		};
	}

	async callback(query: Record<string, unknown>, cookieState: string | undefined): Promise<RouteResult> {
		const link = typeof query.state === "string" ? this.pendingLinks.get(query.state) : undefined;
		if (link) {
			this.pendingLinks.delete(query.state as string);
		}
		const page = link ? this.userPage(link.playerName) : "";

		if (typeof query.error === "string") {
			const message = query.error === "access_denied" ? "Discord login was cancelled" : query.error;
			return this.webRedirect("error", message, page);
		}
		if (
			typeof query.state !== "string" || !cookieState || query.state !== cookieState
			|| (link && link.expiresMs < Date.now())
		) {
			return this.webRedirect("error", "Discord login expired, please try again", page);
		}
		if (typeof query.code !== "string") {
			return this.webRedirect("error", "Discord did not return a login code", page);
		}

		let discordUser;
		try {
			discordUser = await this.fetchDiscordUser(query.code);
		} catch (err: any) {
			this.logger.warn(`Discord login failed: ${err.message}`);
			return this.webRedirect("error", "Discord login failed, please try again", page);
		}

		if (link) {
			try {
				this.linkAccount(discordUser, link.playerName);
			} catch (err: any) {
				return this.webRedirect("error", err.message, page);
			}
			return { redirect: new URL(page, this.controller.getControllerUrl()).href };
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

		const linked = this.linkAccount(session, request.playerName);
		this.codes.delete(code);
		delete session.code;
		return linked;
	}

	/** Link a player who proved they own the Factorio account, it moves over from any other Discord account. */
	linkAccount(discordUser: DiscordUser, playerName: string) {
		const name = playerName.toLowerCase();
		const existing = this.accounts.get(discordUser.id);
		const alreadyLinked = existing?.factorioNames.some(linked => linked.toLowerCase() === name);
		const maxAccounts = this.controller.config.get("exp_discord.max_accounts");
		if (!alreadyLinked && (existing?.factorioNames.length ?? 0) >= maxAccounts) {
			throw new lib.RequestError(
				`${discordUser.name} already has ${maxAccounts} Factorio accounts linked, unlink one first`
			);
		}

		if (!alreadyLinked) {
			this.removeLink(playerName);
			const account = this.accounts.getMutable(discordUser.id)
				?? new messages.DiscordAccountRecord(discordUser.id, discordUser.name, []);
			account.name = discordUser.name;
			account.factorioNames = [...account.factorioNames, playerName];
			this.accounts.set(account);
		}
		return { id: discordUser.id, name: discordUser.name };
	}

	async handleUnlinkRequest(request: messages.DiscordUnlinkRequest) {
		return this.removeLink(request.playerName);
	}

	/** A ticket for /api/exp_discord/authorize?link= which links the Discord account to the user. */
	async handleLinkStartRequest(request: messages.DiscordLinkStartRequest) {
		const ticket = crypto.randomBytes(16).toString("base64url");
		this.linkTickets.set(ticket, { playerName: request.playerName, expiresMs: Date.now() + 60e3 });
		return ticket;
	}

	async handleLinkGetRequest(request: messages.DiscordLinkGetRequest) {
		const account = this.findAccount(request.playerName);
		return account ? { id: account.id, name: account.name } : null;
	}
}

export default async function (context: ControllerPluginContext) {
	await ControllerPlugin.fromContext(context);
}
