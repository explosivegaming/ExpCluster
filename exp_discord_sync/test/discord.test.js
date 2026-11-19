import t from "tap";
import * as lib from "@clusterio/lib";
import { DiscordApiError, DiscordGateway, DiscordRest, gatewayIntents } from "../dist/node/discord.js";
import { guildId, startFakeDiscord, until } from "./fake_discord.js";

const logger = { child: () => logger, info: () => {}, warn: () => {}, error: () => {}, verbose: () => {} };
const memberId = "300000000000000000";
const roleId = "200000000000000001";

t.test("class DiscordRest", async t2 => {
	const fake = await startFakeDiscord();
	t2.teardown(fake.close);
	fake.members.set(memberId, new Set());

	t2.test(".getGuildMember() returns the member, or undefined when not in the guild", async t3 => {
		const rest = new DiscordRest("token", fake.apiBase);
		t3.same(await rest.getGuildMember(guildId, memberId), { user: { id: memberId }, roles: [] });
		t3.equal(await rest.getGuildMember(guildId, "1"), undefined);
	});

	t2.test(".addMemberRole() and .removeMemberRole() change roles", async t3 => {
		const rest = new DiscordRest("token", fake.apiBase);
		await rest.addMemberRole(guildId, memberId, roleId);
		t3.same([...fake.members.get(memberId)], [roleId]);
		await rest.removeMemberRole(guildId, memberId, roleId);
		t3.same([...fake.members.get(memberId)], []);
	});

	t2.test("waits out 429 responses and retries", async t3 => {
		const rest = new DiscordRest("token", fake.apiBase);
		fake.requests.length = 0;
		fake.rateLimit = 2;
		const start = Date.now();
		await rest.getGuildRoles(guildId);
		t3.equal(fake.requests.length, 3);
		t3.ok(Date.now() - start >= 90, "waited retry_after twice");
	});

	t2.test("gives up after repeated 429 responses", async t3 => {
		const rest = new DiscordRest("token", fake.apiBase);
		fake.rateLimit = 6;
		await t3.rejects(rest.getGuildRoles(guildId), { status: 429 });
		fake.rateLimit = 0;
	});

	t2.test("throws DiscordApiError with the status", async t3 => {
		const rest = new DiscordRest("wrong", fake.apiBase);
		const err = await rest.getGuildRoles(guildId).catch(e => e);
		t3.ok(err instanceof DiscordApiError);
		t3.equal(err.status, 401);
	});

	t2.test("sends one request at a time", async t3 => {
		const rest = new DiscordRest("token", fake.apiBase);
		fake.requests.length = 0;
		fake.rateLimit = 1;
		await Promise.all([rest.getGuildRoles(guildId), rest.getGuildMember(guildId, memberId)]);
		t3.same(fake.requests, [
			`GET /guilds/${guildId}/roles`,
			`GET /guilds/${guildId}/roles`,
			`GET /guilds/${guildId}/members/${memberId}`,
		]);
	});
});

t.test("class DiscordGateway", async t2 => {
	t2.test("identifies with the intents and passes on dispatches", async t3 => {
		const fake = await startFakeDiscord();
		t3.teardown(fake.close);
		const events = [];
		const gateway = new DiscordGateway("token", gatewayIntents.GUILD_MEMBERS, logger, {
			onReady: () => events.push("ready"),
			onDispatch: (type, data) => events.push([type, data]),
		}, fake.gatewayUrl);
		t3.teardown(() => gateway.stop());
		gateway.start();
		await until(() => events.length);
		t3.equal(fake.identifies[0].token, "token");
		t3.equal(fake.identifies[0].intents, gatewayIntents.GUILD_MEMBERS);
		fake.dispatch("GUILD_MEMBER_ADD", { guild_id: guildId, user: { id: memberId } });
		await until(() => events.length === 2);
		t3.same(events, ["ready", ["GUILD_MEMBER_ADD", { guild_id: guildId, user: { id: memberId } }]]);
	});

	t2.test("reconnects when the connection drops", async t3 => {
		const fake = await startFakeDiscord();
		t3.teardown(fake.close);
		let ready = 0;
		const gateway = new DiscordGateway("token", 0, logger, { onReady: () => { ready += 1; } }, fake.gatewayUrl);
		gateway.backoff = new lib.ExponentialBackoff({ base: 0.01, max: 0.02 });
		t3.teardown(() => gateway.stop());
		gateway.start();
		await until(() => ready === 1);
		for (const ws of fake.sockets) {
			ws.terminate();
		}
		await until(() => ready === 2);
		t3.equal(fake.identifies.length, 2);
	});

	t2.test("stops on a fatal close code", async t3 => {
		const fake = await startFakeDiscord({ closeCode: 4014 });
		t3.teardown(fake.close);
		let closed;
		const gateway = new DiscordGateway("token", 0, logger, {
			onFatalClose: (code, reason) => { closed = { code, reason }; },
		}, fake.gatewayUrl);
		gateway.backoff = new lib.ExponentialBackoff({ base: 0.01, max: 0.02 });
		gateway.start();
		await until(() => closed);
		t3.same(closed, { code: 4014, reason: "closed by fake" });
		await new Promise(resolve => setTimeout(resolve, 100));
		t3.equal(fake.identifies.length, 1, "did not reconnect");
	});

	t2.test(".stop() closes without reconnecting", async t3 => {
		const fake = await startFakeDiscord();
		t3.teardown(fake.close);
		let ready = 0;
		const gateway = new DiscordGateway("token", 0, logger, { onReady: () => { ready += 1; } }, fake.gatewayUrl);
		gateway.backoff = new lib.ExponentialBackoff({ base: 0.01, max: 0.02 });
		gateway.start();
		await until(() => ready === 1);
		gateway.stop();
		await until(() => fake.sockets.size === 0);
		await new Promise(resolve => setTimeout(resolve, 100));
		t3.equal(fake.identifies.length, 1);
	});
});
