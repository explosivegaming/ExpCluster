import * as http from "node:http";
import { WebSocketServer } from "ws";

export const guildId = "100000000000000000";

/**
 * Discord REST and gateway for one guild on a local port.
 *
 * members maps user id to a Set of role ids. rateLimit makes the next n
 * requests answer 429. The gateway sends READY after identify, more events
 * go through dispatch().
 */
export async function startFakeDiscord({ token = "token", closeCode } = {}) {
	const fake = {
		roles: [
			{ id: guildId, name: "@everyone", color: 0, position: 0, managed: false },
		],
		members: new Map(),
		requests: [],
		rateLimit: 0,
		identifies: [],
		sockets: new Set(),
		dispatch(t, d) {
			for (const ws of fake.sockets) {
				ws.send(JSON.stringify({ op: 0, s: 2, t, d }));
			}
		},
	};

	const server = http.createServer((req, res) => {
		const route = `${req.method} ${req.url.replace(/^\/api\/v10/, "")}`;
		fake.requests.push(route);
		const reply = (status, body) => {
			res.writeHead(status, { "Content-Type": "application/json" });
			res.end(body === undefined ? undefined : JSON.stringify(body));
		};
		if (req.headers.authorization !== `Bot ${token}`) {
			reply(401, { message: "401: Unauthorized" });
			return;
		}
		if (fake.rateLimit > 0) {
			fake.rateLimit -= 1;
			reply(429, { message: "You are being rate limited.", retry_after: 0.05, global: false });
			return;
		}

		let match;
		if (route === `GET /guilds/${guildId}/roles`) {
			reply(200, fake.roles);
		} else if ((match = route.match(new RegExp(`^GET /guilds/${guildId}/members/(\\d+)$`)))) {
			const roles = fake.members.get(match[1]);
			if (roles) {
				reply(200, { user: { id: match[1] }, roles: [...roles] });
			} else {
				reply(404, { message: "Unknown Member", code: 10007 });
			}
		} else if ((match = route.match(new RegExp(`^(PUT|DELETE) /guilds/${guildId}/members/(\\d+)/roles/(\\d+)$`)))) {
			const roles = fake.members.get(match[2]);
			if (!roles) {
				reply(404, { message: "Unknown Member", code: 10007 });
			} else if (fake.roles.find(role => role.id === match[3])?.name === "Above bot") {
				reply(403, { message: "Missing Permissions", code: 50013 });
			} else {
				roles[match[1] === "PUT" ? "add" : "delete"](match[3]);
				reply(204);
			}
		} else {
			reply(404, { message: "404: Not Found" });
		}
	});

	const wss = new WebSocketServer({ server });
	wss.on("connection", ws => {
		fake.sockets.add(ws);
		ws.on("close", () => fake.sockets.delete(ws));
		ws.send(JSON.stringify({ op: 10, s: null, t: null, d: { heartbeat_interval: 45000 } }));
		ws.on("message", data => {
			const payload = JSON.parse(String(data));
			if (payload.op === 1) {
				ws.send(JSON.stringify({ op: 11, s: null, t: null, d: null }));
			} else if (payload.op === 2) {
				fake.identifies.push(payload.d);
				if (closeCode) {
					ws.close(closeCode, "closed by fake");
				} else if (payload.d.token !== token) {
					ws.close(4004, "Authentication failed.");
				} else {
					ws.send(JSON.stringify({ op: 0, s: 1, t: "READY", d: { session_id: "s" } }));
				}
			}
		});
	});

	await new Promise(resolve => server.listen(0, "127.0.0.1", resolve));
	const port = server.address().port;
	fake.apiBase = `http://127.0.0.1:${port}/api/v10`;
	fake.gatewayUrl = `ws://127.0.0.1:${port}/?v=10&encoding=json`;
	fake.close = async () => {
		for (const ws of wss.clients) {
			ws.terminate();
		}
		wss.close();
		server.closeAllConnections();
		await new Promise(resolve => server.close(resolve));
	};
	return fake;
}

/** Wait until check() is truthy, failing after a second. */
export async function until(check) {
	for (let i = 0; i < 100; i++) {
		if (check()) {
			return;
		}
		await new Promise(resolve => setTimeout(resolve, 10));
	}
	throw new Error("timed out waiting");
}
