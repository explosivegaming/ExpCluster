import type { Controller, ControllerPluginContext } from "@clusterio/controller";
import * as lib from "@clusterio/lib";
import * as path from "node:path";
import type { ControllerPlugin as DiscordAuth } from "@expcluster/discord-auth/dist/node/controller.js";
import * as messages from "./messages.js";
import {
	DiscordApiError, DiscordGateway, DiscordRest, GuildMember, gatewayIntents,
} from "./discord.js";

const snowflake = /^\d{17,20}$/;

function roleKey(roleIds: Iterable<number>) {
	return [...roleIds].sort((a, b) => a - b).join(",");
}

export class ControllerPlugin {
	/** Discord accounts waiting to be synced */
	pending = new Set<string>();
	syncAll = false;
	/** Resolves once the queue is empty */
	draining?: Promise<void>;
	/** Roles of each user as last seen, so updates which don't touch roles are ignored */
	userRoles = new Map<string, string>();

	private constructor(
		public controller: Controller,
		public logger: lib.Logger,
		public name: string,
		public mappings: lib.SubscribableDatastore<messages.RoleMappingRecord>,
		/** Undefined if exp_discord_auth did not load, nothing is synced then */
		public discordAuth: DiscordAuth | undefined,
		public rest: DiscordRest,
		public gateway: DiscordGateway,
	) {}

	static async fromContext(context: ControllerPluginContext) {
		const controller = context.controller;
		const databaseDirectory = controller.config.get("controller.database_directory");

		const mappings = await lib.SubscribableDatastore.fromProvider(new lib.JsonIdDatastoreProvider(
			path.join(databaseDirectory, "exp_discord_sync", "role_mappings.json"),
			messages.RoleMappingRecord.fromJSON.bind(messages.RoleMappingRecord),
		));

		const discordAuth = await context.plugins.waitFor<DiscordAuth>("exp_discord_auth");
		const token = () => controller.config.get("exp_discord_sync.bot_token") ?? "";
		const rest = new DiscordRest(token);
		const gateway = new DiscordGateway(token, gatewayIntents.GUILD_MEMBERS, context.logger);
		const plugin = new ControllerPlugin(
			controller, context.logger, context.plugin.name, mappings, discordAuth, rest, gateway,
		);
		plugin.sweepMappings();
		for (const user of controller.users.values()) {
			plugin.userRoles.set(user.id, roleKey(user.roleIds));
		}

		controller.subscriptions.handle(
			messages.RoleMappingUpdatedEvent, plugin.handleMappingSubscription.bind(plugin)
		);
		controller.handle(messages.RoleMappingUpdateRequest, plugin.handleMappingUpdateRequest.bind(plugin));
		controller.handle(messages.GuildRoleListRequest, plugin.handleGuildRoleListRequest.bind(plugin));

		mappings.on("update", plugin.mappingsUpdated.bind(plugin));
		controller.roles.on("update", plugin.sweepMappings.bind(plugin));
		controller.users.records.on("update", plugin.usersUpdated.bind(plugin));

		const hooks = controller.hooks;
		hooks.save.attach(plugin.name, plugin.onSave.bind(plugin));
		hooks.shutdown.attach(plugin.name, plugin.onShutdown.bind(plugin));
		hooks.controllerConfigFieldChanged.attach(plugin.name, plugin.onControllerConfigFieldChanged.bind(plugin));
		discordAuth?.hooks.linked.attach(plugin.name, plugin.onLinkChanged.bind(plugin));
		discordAuth?.hooks.unlinked.attach(plugin.name, plugin.onLinkChanged.bind(plugin));

		gateway.on("ready", plugin.onGatewayReady.bind(plugin));
		gateway.on("dispatch", plugin.onGatewayDispatch.bind(plugin));
		gateway.on("fatalClose", plugin.onGatewayFatalClose.bind(plugin));

		plugin.connect();
		return plugin;
	}

	async onSave() {
		await this.mappings.save();
	}

	async onShutdown() {
		this.disconnect();
		await this.mappings.save();
	}

	async onControllerConfigFieldChanged(field: string) {
		if (field === "exp_discord_sync.bot_token" || field === "exp_discord_sync.guild_id") {
			this.disconnect();
			this.connect();
		}
	}

	/*
		Discord connection
	*/

	/** The configured guild, or undefined if the bot is not configured or can't sync */
	get guildId() {
		const token = this.controller.config.get("exp_discord_sync.bot_token");
		const guildId = this.controller.config.get("exp_discord_sync.guild_id");
		return token && guildId && this.discordAuth ? guildId : undefined;
	}

	connect() {
		const token = this.controller.config.get("exp_discord_sync.bot_token");
		const guildId = this.controller.config.get("exp_discord_sync.guild_id");
		if (!token || !guildId) {
			return;
		}
		if (!this.discordAuth) {
			this.logger.error("exp_discord_auth is not loaded, Discord roles can not be synced");
			return;
		}
		this.gateway.start();
	}

	disconnect() {
		this.gateway.stop();
		this.pending.clear();
		this.syncAll = false;
	}

	// Joins are missed while disconnected, so every (re)connect syncs everyone
	onGatewayReady() {
		this.queueAll();
	}

	onGatewayDispatch(type: string, data: any) {
		if (type === "GUILD_MEMBER_ADD" && data.guild_id === this.guildId) {
			this.queue(data.user.id);
		}
	}

	onGatewayFatalClose(code: number, reason: string) {
		if (code === 4014) {
			this.logger.warn(
				"The Discord bot is missing the Server Members intent, joining the server does not give roles"
			);
			this.queueAll();
		} else {
			this.logger.error(`Discord gateway refused the bot with ${code}: ${reason}`);
		}
	}

	onLinkChanged(_playerName: string, discordUser: { id: string }) {
		this.queue(discordUser.id);
	}

	/*
		Syncing
	*/

	queue(discordId: string) {
		if (!this.guildId) {
			return;
		}
		this.pending.add(discordId);
		this.drain();
	}

	queueAll() {
		if (!this.guildId) {
			return;
		}
		this.syncAll = true;
		this.drain();
	}

	drain() {
		this.draining ??= this._processQueue().finally(() => { this.draining = undefined; });
		return this.draining;
	}

	private async _processQueue() {
		while (this.syncAll || this.pending.size) {
			if (this.syncAll) {
				this.syncAll = false;
				for (const account of this.discordAuth?.getAccounts() ?? []) {
					this.pending.add(account.id);
				}
			}
			const [discordId] = this.pending;
			if (discordId === undefined) {
				continue;
			}
			this.pending.delete(discordId);
			try {
				await this.syncAccount(discordId);
			} catch (err: any) {
				if (err instanceof DiscordApiError && err.status === 403) {
					this.logger.warn(
						`Discord refused to change roles of ${discordId}, the bot needs Manage Roles `
						+ "and a role above every mapped role"
					);
				} else {
					this.logger.warn(`Failed to sync Discord roles of ${discordId}: ${err.message}`);
				}
			}
		}
	}

	/** Every Discord role this plugin gives, any other role is left alone. */
	managedRoleIds() {
		const managed = new Set<string>();
		for (const mapping of this.mappings.values()) {
			for (const id of mapping.discordRoleIds) {
				managed.add(id);
			}
		}
		return managed;
	}

	/** The mapped Discord roles for the clusterio roles of every player linked to the account. */
	wantedRoleIds(discordId: string) {
		const wanted = new Set<string>();
		const account = this.discordAuth?.getAccount(discordId);
		for (const playerName of account?.playerNames ?? []) {
			const user = this.controller.users.getByName(playerName);
			for (const roleId of user?.roleIds ?? []) {
				for (const id of this.mappings.get(roleId)?.discordRoleIds ?? []) {
					wanted.add(id);
				}
			}
		}
		return wanted;
	}

	async syncAccount(discordId: string) {
		const managed = this.managedRoleIds();
		const guildId = this.guildId;
		if (!guildId || !managed.size) {
			return;
		}
		const rest = this.rest;
		const member: GuildMember | undefined = await rest.getGuildMember(guildId, discordId);
		if (!member) {
			return;
		}

		const wanted = this.wantedRoleIds(discordId);
		const current = new Set(member.roles);
		for (const id of wanted) {
			if (!current.has(id)) {
				await rest.addMemberRole(guildId, discordId, id);
			}
		}
		for (const id of current) {
			if (managed.has(id) && !wanted.has(id)) {
				await rest.removeMemberRole(guildId, discordId, id);
			}
		}
	}

	usersUpdated(users: lib.UserDetails[]) {
		for (const user of users) {
			const key = user.isDeleted ? "" : roleKey(user.roleIds);
			if (this.userRoles.get(user.id) === key) {
				continue;
			}
			if (user.isDeleted) {
				this.userRoles.delete(user.id);
			} else {
				this.userRoles.set(user.id, key);
			}
			const link = this.guildId ? this.discordAuth?.getLink(user.name) : undefined;
			if (link) {
				this.queue(link.id);
			}
		}
	}

	/*
		Role mappings
	*/

	/** Mappings of deleted roles, the Discord roles they gave stay on members. */
	sweepMappings() {
		const orphaned = [...this.mappings.valuesMutable()].filter(mapping => !this.controller.roles.has(mapping.id));
		if (orphaned.length) {
			this.mappings.deleteMany(orphaned);
		}
	}

	mappingsUpdated(updates: messages.RoleMappingRecord[]) {
		this.controller.subscriptions.broadcast(new messages.RoleMappingUpdatedEvent(updates));
	}

	async handleMappingSubscription(request: lib.SubscriptionRequest) {
		const updates = [...this.mappings.values()].filter(mapping => mapping.updatedAtMs > request.lastRequestTimeMs);
		return updates.length ? new messages.RoleMappingUpdatedEvent(updates) : null;
	}

	async handleMappingUpdateRequest(request: messages.RoleMappingUpdateRequest) {
		if (!this.controller.roles.has(request.roleId)) {
			throw new lib.NotFoundError(`Role with ID ${request.roleId} does not exist`);
		}
		const discordRoleIds = [...new Set(request.discordRoleIds)];
		const invalid = discordRoleIds.filter(id => !snowflake.test(id));
		if (invalid.length) {
			throw new lib.ValidationError(`Not a Discord role ID: ${invalid.join(", ")}`);
		}

		const existing = this.mappings.getMutable(request.roleId);
		if (!discordRoleIds.length) {
			if (existing) {
				this.mappings.delete(existing);
			}
		} else {
			this.mappings.set(new messages.RoleMappingRecord(request.roleId, discordRoleIds));
		}
		this.queueAll();
	}

	async handleGuildRoleListRequest() {
		const guildId = this.guildId;
		if (!guildId) {
			throw new lib.UnavailableError("The Discord bot is not configured");
		}
		const roles = await this.rest.getGuildRoles(guildId);
		return roles
			// @everyone has the guild id, and integration roles can't be given by bots
			.filter(role => role.id !== guildId && !role.managed)
			.sort((a, b) => b.position - a.position)
			.map(role => ({ id: role.id, name: role.name, color: role.color }));
	}
}

export default ControllerPlugin.fromContext.bind(ControllerPlugin);
