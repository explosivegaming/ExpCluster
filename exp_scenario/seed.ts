import type * as lib from "@clusterio/lib";
import { RoleColor } from "@expcluster/roles";

/**
 * A role created by the seed, as the scenario defined it before roles moved to
 * the controller. `parent` stands in for the inheritance
 * the old config had and is flattened by the seed. The default and admin roles
 * already exist, so those entries only provide the in game properties.
 */
export interface SeedRole {
	name: string;
	shortHand: string;
	color: RoleColor | null;
	priority?: number;
	autoAssignHours?: number;
	blockAutoAssign?: boolean;
	/** Uses the controller's default role rather than creating one. */
	isDefault?: boolean;
	/** Uses the controller's admin role rather than creating one. */
	isAdmin?: boolean;
	/** Name of the role whose permissions are also granted, applied recursively. */
	parent?: string;
	permissions: lib.PermissionName[];
	/**
	 * Name of the seed group holders are placed in by their highest role.
	 * Without one the holders stay in Factorio's Default group.
	 */
	group?: string;
}

/**
 * A Factorio permission group created by the seed, as the scenario defined it
 * before groups moved to the controller.
 */
export interface SeedGroup {
	name: string;
	/** When true the input actions are the only ones disallowed, otherwise the only ones allowed. */
	isBlacklist: boolean;
	inputActions: string[];
}

export const seedRoles: SeedRole[] = [
	{
		name: "System",
		shortHand: "SYS",
		color: null,
		isAdmin: true,
		permissions: [],
	},
	{
		name: "Senior Administrator",
		group: "Admin",
		shortHand: "SAdmin",
		color: new RoleColor(233, 63, 233),
		parent: "Administrator",
		permissions: [
			"exp_scenario.command._rcon",
			"exp_scenario.command.debug",
			"exp_scenario.command.set_cheat_mode",
			"exp_scenario.command.research_all",
		],
	},
	{
		name: "Administrator",
		group: "Admin",
		shortHand: "Admin",
		color: new RoleColor(233, 63, 233),
		parent: "Moderator",
		permissions: [
			"exp_scenario.gui.warp_list.bypass_proximity",
			"exp_scenario.gui.warp_list.bypass_cooldown",
			"exp_scenario.command.connect_all",
		],
	},
	{
		name: "Moderator",
		group: "Admin",
		shortHand: "Mod",
		color: new RoleColor(0, 170, 0),
		parent: "Trainee",
		permissions: [
			"exp_scenario.player.instant_respawn",
			"exp_scenario.command.assign_role",
			"exp_scenario.command.unassign_role",
			"exp_scenario.command.repair",
			"exp_scenario.command.kill.always",
			"exp_scenario.command.tag_clear.always",
			"exp_scenario.command.spawn.always",
			"exp_scenario.command.clear_reports",
			"exp_scenario.command.clear_inventory",
			"exp_scenario.command.kill_enemies",
			"exp_scenario.command.remove_enemies",
			"exp_scenario.command.home",
			"exp_scenario.command.set_home",
			"exp_scenario.command.get_home",
			"exp_scenario.command.return",
			"exp_scenario.command.connect_player",
			"exp_scenario.command.set_bot_queue",
			"exp_scenario.command.set_game_speed",
			"exp_scenario.command.set_friendly_fire",
			"exp_scenario.command.set_always_day",
			"exp_scenario.command.set_pollution_enabled",
			"exp_scenario.command.clear_pollution",
			"exp_scenario.gui.rocket_info.toggle_active",
			"exp_scenario.gui.rocket_info.remote_launch",
			"exp_scenario.gui.bonus",
			"exp_scenario.decon.fast_trees",
		],
	},
	{
		name: "Trainee",
		group: "Admin",
		shortHand: "TrMod",
		color: new RoleColor(0, 170, 0),
		parent: "Veteran",
		permissions: [
			"exp_scenario.player.admin",
			"exp_scenario.player.spectator",
			"exp_scenario.bypass.reports",
			"exp_scenario.command.admin_chat",
			"exp_scenario.command.goto",
			"exp_scenario.command.teleport",
			"exp_scenario.command.bring",
			"exp_scenario.command.get_reports",
			"exp_scenario.command.protect_entity",
			"exp_scenario.command.protect_area",
			"exp_scenario.command.protect_tag",
			"exp_scenario.command.jail",
			"exp_scenario.command.unjail",
			"exp_scenario.gui.player_list.kick",
			"exp_scenario.gui.player_list.ban",
			"exp_scenario.command.spectate",
			"exp_scenario.command.follow",
			"exp_scenario.command.search",
			"exp_scenario.command.search_online",
			"exp_scenario.command.search_amount",
			"exp_scenario.command.search_recent",
			"exp_scenario.command.clear_blueprints_surface",
			"exp_scenario.gui.playerdata",
		],
	},
	{
		name: "Board Member",
		group: "Trusted",
		shortHand: "Board",
		color: new RoleColor(247, 246, 54),
		parent: "Sponsor",
		permissions: [
			"exp_scenario.command.goto",
			"exp_scenario.command.repair",
			"exp_scenario.command.spectate",
			"exp_scenario.command.follow",
			"exp_scenario.gui.playerdata",
		],
	},
	{
		name: "Senior Backer",
		group: "Trusted",
		shortHand: "Backer",
		color: new RoleColor(238, 172, 44),
		parent: "Sponsor",
		permissions: [],
	},
	{
		name: "Sponsor",
		group: "Trusted",
		shortHand: "Spon",
		color: new RoleColor(238, 172, 44),
		parent: "Supporter",
		permissions: [
			"exp_scenario.bypass.reports",
			"exp_scenario.player.instant_respawn",
			"exp_scenario.gui.rocket_info.toggle_active",
			"exp_scenario.gui.rocket_info.remote_launch",
			"exp_scenario.gui.bonus",
			"exp_scenario.command.home",
			"exp_scenario.command.set_home",
			"exp_scenario.command.get_home",
			"exp_scenario.command.return",
			"exp_scenario.decon.fast_trees",
		],
	},
	{
		name: "Supporter",
		group: "Trusted",
		shortHand: "Sup",
		color: new RoleColor(230, 99, 34),
		parent: "Veteran",
		permissions: [
			"exp_scenario.player.spectator",
			"exp_scenario.command.tag_color",
			"exp_scenario.command.jail",
			"exp_scenario.command.unjail",
			"exp_scenario.command.set_join_message",
			"exp_scenario.command.remove_join_message",
		],
	},
	{
		name: "Partner",
		group: "Trusted",
		shortHand: "Part",
		color: new RoleColor(140, 120, 200),
		parent: "Veteran",
		permissions: [
			"exp_scenario.player.spectator",
			"exp_scenario.command.jail",
			"exp_scenario.command.unjail",
		],
	},
	{
		name: "Veteran",
		group: "Trusted",
		shortHand: "Vet",
		color: new RoleColor(140, 120, 200),
		parent: "Member",
		autoAssignHours: 10,
		permissions: [
			"exp_scenario.chat.commands",
			"exp_scenario.command.clear_ground_items",
			"exp_scenario.command.clear_blueprints",
			"exp_scenario.command.set_trains_to_automatic",
		],
	},
	{
		name: "Member",
		group: "Standard",
		shortHand: "Mem",
		color: new RoleColor(24, 172, 188),
		parent: "Regular",
		permissions: [
			"exp_scenario.bypass.deconstruction_log",
			"exp_scenario.gui.task_list.add",
			"exp_scenario.gui.task_list.edit",
			"exp_scenario.gui.warp_list.add",
			"exp_scenario.gui.warp_list.edit",
			"exp_scenario.gui.surveillance",
			"exp_scenario.gui.vlayer_edit",
			"exp_scenario.gui.tool",
			"exp_scenario.command.save_quickbar",
			"exp_scenario.command.vlayer_info",
			"exp_scenario.command.lawnmower",
			"exp_scenario.command.waterfill",
			"exp_scenario.command.artillery",
		],
	},
	{
		name: "Regular",
		group: "Standard",
		shortHand: "Reg",
		color: new RoleColor(79, 155, 163),
		autoAssignHours: 3,
		permissions: [
			"exp_scenario.command.kill",
			"exp_scenario.command.rainbow",
			"exp_scenario.command.spawn",
			"exp_scenario.command.me",
			"exp_scenario.decon.standard",
			"exp_scenario.bypass.entity_protection",
			"exp_scenario.bypass.nuke_protection",
		],
	},
	{
		name: "Jail",
		group: "Restricted",
		shortHand: "Jail",
		color: new RoleColor(50, 50, 50),
		priority: 1,
		blockAutoAssign: true,
		permissions: [],
	},
	{
		name: "Guest",
		group: "Guest",
		shortHand: "",
		color: new RoleColor(185, 187, 160),
		isDefault: true,
		permissions: [],
	},
];

const adminDisallowed = [
	"add_permission_group",
	"delete_permission_group",
	"edit_permission_group",
	"import_permissions_string",
	"map_editor_action",
	"toggle_map_editor",
	"change_multiplayer_config",
	"set_heat_interface_mode",
	"set_heat_interface_temperature",
	"set_infinity_container_filter_item",
	"set_infinity_container_remove_unfiltered_items",
	"set_infinity_pipe_filter",
];

const trustedDisallowed = [
	...adminDisallowed,
	"admin_action",
];

const standardDisallowed = [
	...trustedDisallowed,
	"change_programmable_speaker_alert_parameters",
	"drop_item",
	"open_new_platform_button_from_rocket_silo",
	"set_rocket_silo_send_to_orbit_automated_mode",
];

const guestDisallowed = [
	...standardDisallowed,
	"change_programmable_speaker_parameters",
	"change_train_stop_station",
	"remove_cables",
	"remove_train_station",
	"reset_assembling_machine",
	"rotate_entity",
	"launch_rocket",
	"cancel_research",
	"flush_opened_entity_fluid",
	"flush_opened_entity_specific_fluid",
];

export const seedGroups: SeedGroup[] = [
	{ name: "Admin", isBlacklist: true, inputActions: adminDisallowed },
	{ name: "Trusted", isBlacklist: true, inputActions: trustedDisallowed },
	{ name: "Standard", isBlacklist: true, inputActions: standardDisallowed },
	{ name: "Guest", isBlacklist: true, inputActions: guestDisallowed },
	{ name: "Restricted", isBlacklist: false, inputActions: ["write_to_console"] },
];

/** The permissions a seed role grants, including those of its parents. */
export function flattenSeedPermissions(role: SeedRole, roles = seedRoles) {
	const permissions = new Set<lib.PermissionName>();
	const seen = new Set<string>();
	let current: SeedRole | undefined = role;
	while (current && !seen.has(current.name)) {
		seen.add(current.name);
		for (const permission of current.permissions) {
			permissions.add(permission);
		}
		current = roles.find(other => other.name === current!.parent);
	}
	return permissions;
}
