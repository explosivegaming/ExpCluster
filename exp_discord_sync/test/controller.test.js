import t from "tap";
import * as lib from "@clusterio/lib";
import { Controller } from "@clusterio/controller";
import { ControllerPlugin as DiscordAuth } from "@expcluster/discord-auth/dist/node/controller.js";
import { plugin as discordAuthDeclaration } from "@expcluster/discord-auth/dist/node/index.js";
import entrypoint, { ControllerPlugin } from "../dist/node/controller.js";
import * as messages from "../dist/node/messages.js";
import { plugin as pluginDeclaration } from "../dist/node/index.js";
import { guildId, startFakeDiscord, until } from "./fake_discord.js";

for (const Message of [...pluginDeclaration.messages, ...discordAuthDeclaration.messages]) {
	lib.Link.register(Message);
}
lib.addPluginConfigFields([pluginDeclaration, discordAuthDeclaration]);

const warnings = [];
const logger = {
	child: () => logger, info: () => {}, error: msg => warnings.push(msg), verbose: () => {},
	warn: msg => warnings.push(msg),
};

lib.logger.silent = true;
t.after(() => {
	lib.logger.silent = false;
});

const discordRoles = { moderator: "200000000000000001", trusted: "200000000000000002", other: "200000000000000003" };
const alice = { id: "300000000000000001", name: "Alice" };
const bob = { id: "300000000000000002", name: "Bob" };
const role = (id, name) => new lib.Role(id, name, "", new Set());

/**
 * exp_discord_sync and exp_discord_auth on a real controller, talking to a fake Discord.
 *
 * Sync loads before auth to cover auth being looked up late.
 */
const defaultMappings = { 5: [discordRoles.moderator], 6: [discordRoles.trusted] };
async function startPlugin(t2, { fakeOptions, mappings = defaultMappings } = {}) {
	const fake = await startFakeDiscord(fakeOptions);
	t2.teardown(fake.close);
	fake.roles.push(
		{ id: discordRoles.moderator, name: "Moderator", color: 0xff0000, position: 3, managed: false },
		{ id: discordRoles.trusted, name: "Trusted", color: 0, position: 2, managed: false },
		{ id: discordRoles.other, name: "Other", color: 0, position: 1, managed: false },
		{ id: "200000000000000004", name: "Some Bot", color: 0, position: 4, managed: true },
	);

	const controllerConfig = new lib.ControllerConfig("controller", {
		"controller.database_directory": t2.testdir(),
		"controller.auth_secret": Buffer.from("test secret").toString("base64"),
	});
	const controller = new Controller(logger, [], controllerConfig);
	controller.roles.set(role(5, "Moderator"));
	controller.roles.set(role(6, "Trusted"));
	controller.roles.set(role(7, "Regular"));
	for (const name of ["Player1", "Player2", "Player3"]) {
		controller.users.createUser(name);
	}

	const plugin = await ControllerPlugin.fromContext({ plugin: { name: "exp_discord_sync" }, controller, logger });
	t2.teardown(() => plugin.disconnect());
	const auth = await DiscordAuth.fromContext({ plugin: { name: "exp_discord_auth" }, controller, logger });
	t2.teardown(() => clearInterval(auth.cleanupInterval));
	for (const [roleId, ids] of Object.entries(mappings)) {
		plugin.mappings.set(new messages.RoleMappingRecord(Number(roleId), ids));
	}

	plugin.apiBase = fake.apiBase;
	plugin.gatewayUrl = fake.gatewayUrl;
	controller.config.set("exp_discord_sync.bot_token", "token");
	controller.config.set("exp_discord_sync.guild_id", guildId);
	if (!plugin.gateway) {
		plugin.connect();
	}
	return { plugin, auth, controller, fake };
}

function setRoles(controller, name, roleIds) {
	controller.users.getByNameMutable(name).set("roleIds", new Set(roleIds));
}
const rolesOf = (fake, id) => [...fake.members.get(id)].sort();
async function settled(plugin) {
	await until(() => !plugin.draining && !plugin.pending.size);
}

t.test("entrypoint", async t2 => {
	const controllerConfig = new lib.ControllerConfig("controller", { "controller.database_directory": t2.testdir() });
	const controller = new Controller(logger, [], controllerConfig);
	await entrypoint({ controller, logger, plugin: { name: "exp_discord_sync" }, metrics: undefined });
	for (const hook of ["save", "shutdown", "controllerConfigFieldChanged"]) {
		t2.ok([...controller.hooks[hook].attached].includes("exp_discord_sync"), `attached to ${hook}`);
	}
	await controller.hooks.shutdown.invoke();
});

t.test("syncing", t2 => {
	t2.test("connecting syncs every linked account and only touches mapped roles", async t3 => {
		const { fake, auth, controller, plugin } = await startPlugin(t3);
		await plugin.drain();
		fake.members.set(alice.id, new Set([discordRoles.trusted, discordRoles.other]));
		fake.members.set(bob.id, new Set([discordRoles.trusted]));
		setRoles(controller, "Player1", [5]);
		auth.linkAccount(alice, "Player1");
		await settled(plugin);

		plugin.disconnect();
		fake.members.set(alice.id, new Set([discordRoles.trusted, discordRoles.other]));
		plugin.connect();
		await until(() => fake.identifies.length === 2);
		await until(() => rolesOf(fake, alice.id).join() === [discordRoles.moderator, discordRoles.other].join());
		t3.same(rolesOf(fake, bob.id), [discordRoles.trusted], "unlinked member is left alone");
	});

	t2.test("roles come from every player linked to the account", async t3 => {
		const { fake, auth, controller, plugin } = await startPlugin(t3);
		fake.members.set(alice.id, new Set());
		setRoles(controller, "Player1", [5]);
		setRoles(controller, "Player2", [6, 7]);
		auth.linkAccount(alice, "Player1");
		auth.linkAccount(alice, "Player2");
		await until(() => rolesOf(fake, alice.id).length === 2);
		t3.same(rolesOf(fake, alice.id), [discordRoles.moderator, discordRoles.trusted]);
	});

	t2.test("unlinking takes the roles away", async t3 => {
		const { fake, auth, controller, plugin } = await startPlugin(t3);
		fake.members.set(alice.id, new Set([discordRoles.other]));
		setRoles(controller, "Player1", [5]);
		auth.linkAccount(alice, "Player1");
		await until(() => rolesOf(fake, alice.id).length === 2);
		auth.removeLink("Player1");
		await until(() => rolesOf(fake, alice.id).length === 1);
		t3.same(rolesOf(fake, alice.id), [discordRoles.other]);
		await settled(plugin);
	});

	t2.test("role changes in clusterio are passed on, other user updates are not", async t3 => {
		const { fake, auth, controller, plugin } = await startPlugin(t3);
		fake.members.set(alice.id, new Set());
		auth.linkAccount(alice, "Player1");
		await settled(plugin);

		setRoles(controller, "Player1", [6]);
		await until(() => rolesOf(fake, alice.id).length === 1);
		t3.same(rolesOf(fake, alice.id), [discordRoles.trusted]);
		setRoles(controller, "Player1", [5]);
		await until(() => rolesOf(fake, alice.id)[0] === discordRoles.moderator);
		t3.same(rolesOf(fake, alice.id), [discordRoles.moderator]);

		await settled(plugin);
		fake.requests.length = 0;
		controller.users.getByNameMutable("Player1").set("isAdmin", true);
		setRoles(controller, "Player2", [5]);
		await settled(plugin);
		t3.same(fake.requests, [], "no requests for unlinked users or other fields");
	});

	t2.test("a member joining the guild gets their roles", async t3 => {
		const { fake, auth, controller, plugin } = await startPlugin(t3);
		setRoles(controller, "Player1", [5]);
		auth.linkAccount(alice, "Player1");
		await settled(plugin);

		fake.members.set(alice.id, new Set());
		fake.dispatch("GUILD_MEMBER_ADD", { guild_id: guildId, user: { id: alice.id }, roles: [] });
		await until(() => rolesOf(fake, alice.id).length === 1);
		t3.same(rolesOf(fake, alice.id), [discordRoles.moderator]);
	});

	t2.test("roles Discord refuses are logged and the rest carry on", async t3 => {
		const { fake, auth, controller, plugin } = await startPlugin(t3);
		fake.roles.find(r => r.id === discordRoles.moderator).name = "Above bot";
		fake.members.set(alice.id, new Set());
		fake.members.set(bob.id, new Set());
		setRoles(controller, "Player1", [5]);
		setRoles(controller, "Player2", [6]);
		warnings.length = 0;
		auth.linkAccount(alice, "Player1");
		auth.linkAccount(bob, "Player2");
		await until(() => rolesOf(fake, bob.id).length === 1);
		t3.ok(warnings.some(msg => /Discord refused to change roles of 300000000000000001/.test(msg)));
		await settled(plugin);
	});

	t2.test("a bot without the members intent still syncs", async t3 => {
		const { fake, auth, controller, plugin } = await startPlugin(t3, { fakeOptions: { closeCode: 4014 } });
		await until(() => fake.identifies.length === 1);
		await settled(plugin);
		fake.members.set(alice.id, new Set());
		setRoles(controller, "Player1", [5]);
		auth.linkAccount(alice, "Player1");
		await until(() => rolesOf(fake, alice.id).length === 1);
		t3.ok(plugin.rest, "rest is kept");
		t3.ok(warnings.some(msg => /missing the Server Members intent/.test(msg)));
	});

	t2.test("nothing is sent while the bot is not configured", async t3 => {
		const { fake, auth, controller, plugin } = await startPlugin(t3);
		await settled(plugin);
		controller.config.set("exp_discord_sync.bot_token", null);
		plugin.disconnect();
		plugin.connect();
		fake.requests.length = 0;
		fake.members.set(alice.id, new Set());
		setRoles(controller, "Player1", [5]);
		auth.linkAccount(alice, "Player1");
		await settled(plugin);
		t3.same(fake.requests, []);
		t3.ok(await plugin.handleGuildRoleListRequest().catch(err => err) instanceof lib.UnavailableError);
	});
	t2.end();
});

t.test("role mappings", t2 => {
	t2.test("RoleMappingUpdateRequest sets, validates and removes mappings", async t3 => {
		const { fake, auth, controller, plugin } = await startPlugin(t3, { mappings: {} });
		fake.members.set(alice.id, new Set());
		setRoles(controller, "Player1", [7]);
		auth.linkAccount(alice, "Player1");
		await settled(plugin);

		const update = (roleId, ids) => plugin.handleMappingUpdateRequest(
			new messages.RoleMappingUpdateRequest(roleId, ids)
		);
		await update(7, [discordRoles.other, discordRoles.other]);
		t3.same(plugin.mappings.get(7).discordRoleIds, [discordRoles.other], "duplicates are dropped");
		await until(() => rolesOf(fake, alice.id).length === 1);

		t3.ok(await update(7, ["abc"]).catch(err => err) instanceof lib.ValidationError);
		t3.ok(await update(99, [discordRoles.other]).catch(err => err) instanceof lib.NotFoundError);

		await update(7, []);
		t3.notOk(plugin.mappings.has(7), "empty list removes the mapping");
		await settled(plugin);
		t3.same(rolesOf(fake, alice.id), [discordRoles.other], "roles no longer mapped are left on members");
	});

	t2.test("mapping changes are broadcast", async t3 => {
		const { controller, plugin } = await startPlugin(t3, { mappings: {} });
		const sent = [];
		controller.subscriptions.broadcast = event => sent.push(event);
		await plugin.handleMappingUpdateRequest(new messages.RoleMappingUpdateRequest(5, [discordRoles.moderator]));
		t3.equal(sent.length, 1);
		t3.same(sent[0].updates.map(m => [m.id, m.discordRoleIds]), [[5, [discordRoles.moderator]]]);
		const event = await plugin.handleMappingSubscription({ lastRequestTimeMs: 0 });
		t3.same(event.updates.map(m => m.id), [5]);
		await settled(plugin);
	});

	t2.test("mappings of deleted roles are removed", async t3 => {
		const { controller, plugin } = await startPlugin(t3);
		controller.roles.delete(controller.roles.get(6));
		t3.same([...plugin.mappings.values()].map(m => m.id), [5]);
		await settled(plugin);
	});

	t2.test("mappings are saved and loaded", async t3 => {
		const { controller, plugin } = await startPlugin(t3);
		await plugin.onShutdown();
		const restarted = new Controller(logger, [], new lib.ControllerConfig("controller", {
			"controller.database_directory": controller.config.get("controller.database_directory"),
		}));
		restarted.roles.set(role(5, "Moderator"));
		restarted.roles.set(role(6, "Trusted"));
		const reloaded = await ControllerPlugin.fromContext({
			plugin: { name: "exp_discord_sync" }, controller: restarted, logger,
		});
		t3.same([...reloaded.mappings.values()].map(m => [m.id, m.discordRoleIds]), [
			[5, [discordRoles.moderator]],
			[6, [discordRoles.trusted]],
		]);
	});

	t2.test("GuildRoleListRequest lists roles the bot can give, highest first", async t3 => {
		const { plugin } = await startPlugin(t3);
		t3.same(await plugin.handleGuildRoleListRequest(), [
			{ id: discordRoles.moderator, name: "Moderator", color: 0xff0000 },
			{ id: discordRoles.trusted, name: "Trusted", color: 0 },
			{ id: discordRoles.other, name: "Other", color: 0 },
		]);
		await settled(plugin);
	});
	t2.end();
});
