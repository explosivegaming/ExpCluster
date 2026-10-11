import t from "tap";
import * as lib from "@clusterio/lib";
import { Controller } from "@clusterio/controller";
import entrypoint, { ControllerPlugin } from "../dist/node/controller.js";
import * as messages from "../dist/node/messages.js";
import { plugin as pluginDeclaration } from "../dist/node/index.js";

for (const Message of pluginDeclaration.messages) {
	lib.Link.register(Message);
}
lib.addPluginConfigFields([pluginDeclaration]);

const logger = { child: () => logger, info: () => {}, warn: () => {}, error: () => {}, verbose: () => {} };

lib.logger.silent = true;
t.after(() => {
	lib.logger.silent = false;
});

const alice = { id: "100", name: "Alice" };
const bob = { id: "200", name: "Bob" };

/** Build the plugin around a real controller, which is side effect free while not started. */
async function startPlugin(t2, { config = {} } = {}) {
	const controllerConfig = new lib.ControllerConfig("controller", {
		// testdir() empties the folder, so a reload passes the directory in
		"controller.database_directory": config["controller.database_directory"] ?? t2.testdir(),
		"controller.public_url": "https://example.com/cluster/",
		"exp_discord.client_id": "123",
		"exp_discord.client_secret": "secret",
		"controller.auth_secret": Buffer.from("test secret").toString("base64"),
		...config,
	});
	const controller = new Controller(logger, [], controllerConfig);
	for (const name of ["Player1", "Player2", "Player3", "Player4"]) {
		controller.users.createUser(name);
	}

	const plugin = await ControllerPlugin.fromContext({ plugin: { name: "exp_discord" }, controller, logger });
	t2.teardown(() => clearInterval(plugin.cleanupInterval));
	return { plugin, controller };
}

/** Go through the Discord callback as the given Discord user, returning the session id. */
async function discordLogin(plugin, discordUser) {
	plugin.fetchDiscordUser = async () => discordUser;
	const result = await plugin.callback({ code: "c", state: "s" }, "s");
	return decodeURIComponent(new URL(result.redirect).hash.split("=")[1]);
}

/** Get a code on the web and use it in game as playerName. */
async function link(plugin, session, playerName) {
	const { json } = await plugin.linkCode(session);
	return plugin.handleLinkRequest(new messages.DiscordLinkRequest(playerName, json.code.toLowerCase()));
}

t.test("entrypoint", async t2 => {
	const controllerConfig = new lib.ControllerConfig("controller", { "controller.database_directory": t2.testdir() });
	const controller = new Controller(logger, [], controllerConfig);
	await entrypoint({ controller, logger, plugin: { name: "exp_discord" }, metrics: undefined });
	for (const hook of ["save", "shutdown"]) {
		t2.ok([...controller.hooks[hook].attached].includes("exp_discord"), `attached to ${hook}`);
	}
	await controller.hooks.shutdown.invoke();
});

t.test("oauth", t2 => {
	t2.test(".authorize() redirects to Discord with a state cookie scoped to the callback", async t3 => {
		const { plugin } = await startPlugin(t3);
		const result = await plugin.authorize();
		const url = new URL(result.redirect);
		t3.equal(url.origin + url.pathname, "https://discord.com/oauth2/authorize");
		t3.equal(url.searchParams.get("client_id"), "123");
		t3.equal(url.searchParams.get("redirect_uri"), "https://example.com/cluster/api/exp_discord/callback");
		const state = url.searchParams.get("state");
		t3.match(result.cookie, `exp_discord_state=${state}; Path=/cluster/api/exp_discord/callback`);
		t3.match(result.cookie, "Secure");
	});

	t2.test(".authorize() without credentials goes back with an error", async t3 => {
		const { plugin } = await startPlugin(t3, { config: { "exp_discord.client_secret": null } });
		const result = await plugin.authorize();
		t3.match(result.redirect, /^https:\/\/example\.com\/cluster\/#exp_discord_error=/);
	});

	t2.test(".callback() rejects a state which does not match the cookie", async t3 => {
		const { plugin } = await startPlugin(t3);
		plugin.fetchDiscordUser = async () => t3.fail("should not fetch");
		for (const cookie of [undefined, "other"]) {
			const result = await plugin.callback({ code: "c", state: "s" }, cookie);
			t3.match(result.redirect, "#exp_discord_error=");
		}
		t3.equal(plugin.sessions.size, 0);
	});

	t2.test(".callback() reports a failed token exchange as an error", async t3 => {
		const { plugin } = await startPlugin(t3);
		plugin.fetchDiscordUser = async () => { throw new Error("401"); };
		const result = await plugin.callback({ code: "c", state: "s" }, "s");
		t3.match(result.redirect, "#exp_discord_error=");
	});

	t2.test(".callback() starts a session", async t3 => {
		const { plugin } = await startPlugin(t3);
		const session = await discordLogin(plugin, alice);
		const result = await plugin.listAccounts(session);
		t3.same(result, { status: 200, json: { discord: alice, accounts: [], max_accounts: 3 } });
	});

	t2.test(".listAccounts() rejects unknown and expired sessions", async t3 => {
		const { plugin } = await startPlugin(t3);
		t3.equal((await plugin.listAccounts("nope")).status, 401);
		const session = await discordLogin(plugin, alice);
		plugin.sessions.get(session).expiresMs = Date.now() - 1;
		t3.equal((await plugin.listAccounts(session)).status, 401);
	});
	t2.end();
});

t.test("linking", t2 => {
	t2.test("a code links the player who uses it, and they can then log in", async t3 => {
		const { plugin, controller } = await startPlugin(t3);
		const session = await discordLogin(plugin, alice);
		t3.same(await link(plugin, session, "Player1"), alice);
		t3.same((await plugin.listAccounts(session)).json.accounts, ["Player1"]);

		const result = await plugin.login(session, "player1");
		t3.equal(result.status, 200);
		const payload = JSON.parse(Buffer.from(result.json.token.split(".")[1], "base64url").toString());
		t3.equal(payload.user, controller.users.getByName("Player1").id);
		t3.notOk(plugin.sessions.has(session), "session is used up");
	});

	t2.test("a code can only be used once", async t3 => {
		const { plugin } = await startPlugin(t3);
		const session = await discordLogin(plugin, alice);
		const { json } = await plugin.linkCode(session);
		await plugin.handleLinkRequest(new messages.DiscordLinkRequest("Player1", json.code));
		await t3.rejects(
			plugin.handleLinkRequest(new messages.DiscordLinkRequest("Player2", json.code)), /invalid or has expired/,
		);
	});

	t2.test("asking twice gives the same code", async t3 => {
		const { plugin } = await startPlugin(t3);
		const session = await discordLogin(plugin, alice);
		t3.equal((await plugin.linkCode(session)).json.code, (await plugin.linkCode(session)).json.code);
	});

	t2.test("expired codes are refused", async t3 => {
		const { plugin } = await startPlugin(t3);
		const session = await discordLogin(plugin, alice);
		const { json } = await plugin.linkCode(session);
		plugin.codes.get(json.code).expiresMs = Date.now() - 1;
		await t3.rejects(plugin.handleLinkRequest(new messages.DiscordLinkRequest("Player1", json.code)));
	});

	t2.test("several accounts up to the limit", async t3 => {
		const { plugin } = await startPlugin(t3, { config: { "exp_discord.max_accounts": 2 } });
		const session = await discordLogin(plugin, alice);
		await link(plugin, session, "Player1");
		await link(plugin, session, "Player2");
		await t3.rejects(link(plugin, session, "Player3"), /already has 2 Factorio accounts/);
		t3.same(await link(plugin, session, "PLAYER1"), alice, "relinking a linked account is fine at the limit");
		t3.same(plugin.accounts.get(alice.id).factorioNames, ["Player1", "Player2"]);
	});

	t2.test("linking moves the account away from another Discord account", async t3 => {
		const { plugin } = await startPlugin(t3);
		await link(plugin, await discordLogin(plugin, alice), "Player1");
		await link(plugin, await discordLogin(plugin, bob), "Player1");
		t3.notOk(plugin.accounts.has(alice.id), "empty account is removed");
		t3.same(plugin.accounts.get(bob.id).factorioNames, ["Player1"]);
	});

	t2.test(".login() refuses accounts not linked, missing users and banned users", async t3 => {
		const { plugin, controller } = await startPlugin(t3);
		const session = await discordLogin(plugin, alice);
		t3.equal((await plugin.login(session, "Player2")).status, 403);

		await link(plugin, session, "Player1");
		controller.users.getByNameMutable("Player1").set("isBanned", true);
		t3.equal((await plugin.login(session, "Player1")).status, 403);

		await link(plugin, session, "Ghost");
		t3.equal((await plugin.login(session, "Ghost")).status, 404);
	});

	t2.test("unlink and get", async t3 => {
		const { plugin } = await startPlugin(t3);
		await link(plugin, await discordLogin(plugin, alice), "Player1");
		t3.same(await plugin.handleLinkGetRequest(new messages.DiscordLinkGetRequest("player1")), alice);
		t3.same(await plugin.handleUnlinkRequest(new messages.DiscordUnlinkRequest("Player1")), alice);
		t3.equal(await plugin.handleLinkGetRequest(new messages.DiscordLinkGetRequest("Player1")), null);
		t3.equal(await plugin.handleUnlinkRequest(new messages.DiscordUnlinkRequest("Player1")), null);
	});

	t2.test("links are saved and loaded", async t3 => {
		const dir = t3.testdir();
		const config = { "controller.database_directory": dir };
		const { plugin } = await startPlugin(t3, { config });
		await link(plugin, await discordLogin(plugin, alice), "Player1");
		await plugin.onShutdown();

		const { plugin: reloaded } = await startPlugin(t3, { config });
		t3.same(reloaded.accounts.get(alice.id).factorioNames, ["Player1"]);
	});

	t2.test(".removeExpired() drops old sessions and codes", async t3 => {
		const { plugin } = await startPlugin(t3);
		const session = await discordLogin(plugin, alice);
		await plugin.linkCode(session);
		plugin.removeExpired(Date.now() + 60 * 60e3);
		t3.equal(plugin.sessions.size, 0);
		t3.equal(plugin.codes.size, 0);
	});
	t2.end();
});

t.test("linking from the user page", t2 => {
	/** Start a link for playerName and follow authorize, returning the OAuth state. */
	async function start(plugin, playerName) {
		const ticket = await plugin.handleLinkStartRequest(new messages.DiscordLinkStartRequest(playerName));
		const result = await plugin.authorize(ticket);
		return new URL(result.redirect).searchParams;
	}

	t2.test("links the Discord account and goes back to the user page", async t3 => {
		const { plugin } = await startPlugin(t3);
		const params = await start(plugin, "Player1");
		t3.equal(params.get("prompt"), null, "consent screen is shown");
		plugin.fetchDiscordUser = async () => alice;
		const result = await plugin.callback({ code: "c", state: params.get("state") }, params.get("state"));
		t3.equal(result.redirect, "https://example.com/cluster/users/Player1/view");
		t3.same(plugin.accounts.get(alice.id).factorioNames, ["Player1"]);
		t3.equal(plugin.sessions.size, 0, "no login session is started");
		t3.equal(plugin.pendingLinks.size, 0);
	});

	t2.test("a ticket can only be used once", async t3 => {
		const { plugin } = await startPlugin(t3);
		const ticket = await plugin.handleLinkStartRequest(new messages.DiscordLinkStartRequest("Player1"));
		await plugin.authorize(ticket);
		const result = await plugin.authorize(ticket);
		t3.match(result.redirect, /^https:\/\/example\.com\/cluster\/users#exp_discord_error=Discord%20link%20expired/);
	});

	t2.test("errors go back to the user page", async t3 => {
		const { plugin } = await startPlugin(t3, { config: { "exp_discord.max_accounts": 1 } });
		await link(plugin, await discordLogin(plugin, alice), "Player2");

		let params = await start(plugin, "Player1");
		let result = await plugin.callback({ error: "access_denied", state: params.get("state") }, params.get("state"));
		t3.match(result.redirect, /\/users\/Player1\/view#exp_discord_error=Discord%20login%20was%20cancelled$/);

		params = await start(plugin, "Player1");
		plugin.fetchDiscordUser = async () => alice;
		result = await plugin.callback({ code: "c", state: params.get("state") }, params.get("state"));
		t3.match(result.redirect, /\/users\/Player1\/view#exp_discord_error=.*already%20has%201/);
		t3.same(plugin.accounts.get(alice.id).factorioNames, ["Player2"]);
	});

	t2.test("a state without the cookie does not link", async t3 => {
		const { plugin } = await startPlugin(t3);
		const params = await start(plugin, "Player1");
		plugin.fetchDiscordUser = async () => t3.fail("should not fetch");
		const result = await plugin.callback({ code: "c", state: params.get("state") }, undefined);
		t3.match(result.redirect, "/users/Player1/view#exp_discord_error=");
		t3.notOk(plugin.accounts.has(alice.id));
	});
	t2.end();
});

t.test("permissions", t2 => {
	const user = (name, granted = []) => ({
		name,
		checkPermission(permission) {
			if (!granted.includes(permission)) {
				throw new lib.PermissionError("denied");
			}
		},
	});
	const request = name => ({ data: { player_name: name } });

	t2.test("DiscordLinkStartRequest", async t3 => {
		const permission = messages.DiscordLinkStartRequest.permission;
		t3.doesNotThrow(() => permission(user("Alice"), request("alice")), "own account");
		t3.throws(
			() => permission(user("Alice", ["exp_discord.link.get", "exp_discord.link.delete"]), request("Bob")),
			"never someone else's",
		);
	});

	for (const Request of [messages.DiscordLinkGetRequest, messages.DiscordUnlinkRequest]) {
		t2.test(Request.name, async t3 => {
			const permission = Request === messages.DiscordUnlinkRequest
				? "exp_discord.link.delete"
				: "exp_discord.link.get";
			t3.doesNotThrow(() => Request.permission(user("Alice"), request("alice")), "own link");
			t3.throws(() => Request.permission(user("Alice"), request("Bob")), "someone else's");
			t3.doesNotThrow(() => Request.permission(user("Alice", [permission]), request("Bob")), "with permission");
		});
	}
	t2.end();
});
