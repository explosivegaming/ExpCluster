/**
 * The features which can be configured from the web interface. Defaults must
 * match the lua side, test/features.test.js checks this.
 */

export type FeatureValue = boolean | number | string | string[] | null;

/** A setting, shaped like a clusterio config field so the config inputs can render it */
export type FeatureField = {
	name: string,
	title: string,
	description: string,
} & (
	| ScalarField<{ type: "boolean", default: boolean }>
	| ScalarField<{ type: "number", default: number | null, min?: number, unit?: string }>
	| ScalarField<{ type: "string", default: string | null, enum?: string[] }>
	/** Feature.list or Feature.set on the lua side, both are sent as a list */
	| { type: "string_list", default: string[] }
);

type ScalarField<T> = T & {
	/** Allows null, the lua side uses Feature.optional */
	optional?: boolean,
	/** Name of an input component registered with the web interface, such as "role" */
	inputComponent?: string,
};

export type Feature = {
	name: string,
	title: string,
	description: string,
	fields: FeatureField[],
};

function bool(name: string, title: string, description: string, value: boolean): FeatureField {
	return { name, title, description, type: "boolean", default: value };
}

function num(name: string, title: string, description: string, value: number, min?: number, unit?: string): FeatureField {
	return { name, title, description, type: "number", default: value, min, unit };
}

function str(name: string, title: string, description: string, value: string): FeatureField {
	return { name, title, description, type: "string", default: value };
}

function list(name: string, title: string, description: string, value: string[]): FeatureField {
	return { name, title, description, type: "string_list", default: value };
}

/** Id of a clusterio role, null when no role is picked */
function role(name: string, title: string, description: string): FeatureField {
	return { name, title, description, type: "number", default: null, optional: true, inputComponent: "role" };
}

export const features: Feature[] = [
	{
		name: "afk_kick",
		title: "AFK Kick",
		description: "Kick everyone when nobody online is active",
		fields: [
			bool("admin_as_active", "Admins count as active", "Admins are active regardless of how long they have been afk", true),
			bool("trust_as_active", "Trusted players count as active", "Players with enough playtime are active regardless of how long they have been afk", true),
			role("active_role_id", "Role counts as active", "Players with this role or higher are active regardless of how long they have been afk"),
			num("afk_minutes", "AFK after", "Time without input before a player counts as afk", 10, 1, "minutes"),
			num("kick_minutes", "Kick after", "Time without any active player before everyone is kicked", 30, 1, "minutes"),
			num("trust_minutes", "Trusted after", "Playtime needed before a player counts as trusted", 600, 0, "minutes"),
		],
	},
	{
		name: "autofill",
		title: "Autofill",
		description: "Fill ammo and fuel into entities when they are built, configured by each player from the toolbar",
		fields: [],
	},
	{
		name: "chat_auto_reply",
		title: "Chat Auto Reply",
		description: "Reply to key words in chat and run chat commands",
		fields: [
			str("command_prefix", "Command prefix", "Prefix for chat commands, and for key words to reply to everyone", "!"),
		],
	},
	{
		name: "custom_start",
		title: "Custom Start",
		description: "Map settings applied when the map is created, and the items new players start with",
		fields: [
			bool("skip_intro", "Skip intro", "Skip the freeplay intro", true),
			bool("skip_victory", "Skip victory", "Skip the victory screen when a rocket is launched", true),
			bool("friendly_fire", "Friendly fire", "Players can damage each other", false),
			bool("disable_crashsite", "No crash site", "Do not create the crash site", true),
			bool("enemy_expansion", "Enemy expansion", "Biters expand, in case the map settings file fails to load", false),
			num("chart_radius", "Chart radius", "Tiles charted around spawn when the map starts", 320, 0, "tiles"),
		],
	},
	{
		name: "deconstruction_log",
		title: "Deconstruction Log",
		description: "Write actions of players without the bypass permission to log/deconstruction.log",
		fields: [
			bool("decon_area", "Deconstructed areas", "Log when an area is deconstructed", true),
			bool("built_entity", "Built entities", "Log when an entity is built", true),
			bool("mined_entity", "Mined entities", "Log when an entity is mined", true),
			bool("fired_rocket", "Rockets", "Log when a rocket is fired", true),
			bool("fired_explosive_rocket", "Explosive rockets", "Log when an explosive rocket is fired", true),
			bool("fired_nuke", "Nukes", "Log when a nuke is fired", true),
		],
	},
	{
		name: "degrading_tiles",
		title: "Degrading Tiles",
		description: "Tiles wear down as players walk on them and build on them",
		fields: [
			num("weakness_value", "Weakness", "Lower values make tiles degrade sooner", 70, 1),
			list("entities", "Degrading entities", "Entities which degrade the tiles under them when built", [
				"stone-furnace", "steel-furnace", "electric-furnace", "assembling-machine-1", "assembling-machine-2", "assembling-machine-3",
				"beacon", "centrifuge", "chemical-plant", "oil-refinery", "storage-tank", "nuclear-reactor",
				"steam-engine", "steam-turbine", "boiler", "heat-exchanger", "stone-wall", "gate",
				"gun-turret", "laser-turret", "flamethrower-turret", "radar", "lab", "big-electric-pole",
				"substation", "rocket-silo", "pumpjack", "electric-mining-drill", "roboport", "accumulator",
			]),
		],
	},
	{
		name: "death_markers",
		title: "Death Markers",
		description: "What happens when players die",
		fields: [
			bool("collect_corpses", "Collect corpses", "Put the items of expired corpses in chests", true),
			bool("show_map_markers", "Show map markers", "Add a map marker where a player died", true),
			bool("clean_map_markers", "Remove map markers", "Remove the map marker once the corpse is gone", false),
			bool("include_time_of_death", "Include time of death", "Add the time of death to the map marker", true),
			bool("show_light_at_corpse", "Light at corpse", "Draw a light in the player's colour at their corpse", true),
			bool("show_line_to_corpse", "Line to corpse", "Draw a line from a respawned player to their corpse", true),
		],
	},
	{
		name: "discord_alerts",
		title: "Discord Alerts",
		description: "Write alerts for the discord bot when moderation events happen",
		fields: [
			bool("show_playtime", "Show playtime", "Add the playtime of players to alerts", true),
			bool("entity_protection", "Entity protection", "Alert when a player repeatedly removes protected entities", true),
			bool("player_bans", "Bans", "Alert when a player is banned or unbanned", true),
			bool("player_mutes", "Mutes", "Alert when a player is muted or unmuted", true),
			bool("player_kicks", "Kicks", "Alert when a player is kicked", true),
			bool("player_promotes", "Promotions", "Alert when a player is promoted or demoted", false),
			bool("player_jail", "Jail", "Alert when a player is jailed or unjailed", true),
			list("logged_commands", "Logged commands", "Alert when a player uses one of these commands", [
				"config", "purge", "c", "command", "silent-command", "measured-command", "banlist", "permissions", "editor", "cheat",
			]),
		],
	},
	{
		name: "extra_logging",
		title: "Extra Logging",
		description: "Write rockets, deaths, research, joins, and leaves to a log file",
		fields: [
			str("file_name", "File name", "Path of the log file within script-output", "log/logging.log"),
			num("rocket_launch_display_rate", "Rocket log interval", "After the first few launches, log every this many rockets", 500, 1, "rockets"),
		],
	},
	{
		name: "help_bubbles",
		title: "Help Bubbles",
		description: "A compilatron at spawn which cycles through tips and the community links",
		fields: [],
	},
	{
		name: "inventory_clear",
		title: "Inventory Clear",
		description: "Move the items of banned and kicked players to a chest at spawn",
		fields: [],
	},
	{
		name: "lawnmower",
		title: "Lawnmower",
		description: "The /lawnmower command which clears corpses and nuclear ground",
		fields: [
			bool("destroy_decoratives", "Clear decoratives when building", "Remove decoratives under entities when they are built", false),
		],
	},
	{
		name: "mine_depletion",
		title: "Mine Depletion",
		description: "Deconstruct mining drills when their resources run out",
		fields: [
			bool("chest", "Remove output chests", "Also deconstruct the chest a drill outputs into", true),
			bool("beacon", "Remove beacons", "Also deconstruct beacons which no longer affect anything", true),
			bool("fluid", "Replace with pipes", "Place pipe ghosts where a drill carried fluid", true),
		],
	},
	{
		name: "module_inserter",
		title: "Module Inserter",
		description: "A tool to fill machines with modules by selecting an area",
		fields: [
			bool("copy_paste_module", "Copy modules", "Copying a machine also copies its modules", true),
			bool("copy_paste_rotation", "Copy rotation", "Copying a machine also copies its rotation", false),
		],
	},
	{
		name: "nuke_protection",
		title: "Nuke Protection",
		description: "Remove banned items from players without the nuke protection bypass permission",
		fields: [
			list("banned_items", "Banned items", "Items which are moved to a chest at spawn", ["atomic-bomb"]),
		],
	},
	{
		name: "player_bonus",
		title: "Player Bonus",
		description: "Points players spend on personal bonuses, the bonuses live in config/player_bonus.lua",
		fields: [
			num("points.base", "Base points", "The points of the points role, the standard value of each bonus adds up to this", 174, 0, "points"),
			num("points.increase_percentage_per_role_level", "Points per role level", "Extra points as a fraction of the base for each role above the points role", 0.03, 0),
			role("points.role_id", "Points role", "The role the base points apply to, without one every player gets the base"),
		],
	},
	{
		name: "pollution_grading",
		title: "Pollution Grading",
		description: "Scale the pollution overlay so it is not one red mess",
		fields: [
			num("reference_point.x", "Reference X", "Where pollution is read from", 0),
			num("reference_point.y", "Reference Y", "Where pollution is read from", 0),
			num("max_scalar", "Max scale", "The scale between the true max and the shown max", 0.5, 0),
			num("min_scalar", "Min scale", "The scale between the shown max and the shown min", 0.17, 0),
		],
	},
	{
		name: "popups",
		title: "Popups",
		description: "Flying text for chat messages and damage",
		fields: [
			bool("show_player_messages", "Chat messages", "Show chat messages above the player who sent them", true),
			bool("show_player_mentions", "Mentions", "Show a popup above players mentioned in chat", true),
			bool("show_player_damage", "Damage dealt", "Show the damage players deal to entities", true),
			bool("show_player_health", "Player health", "Show the health of players when they are attacked", true),
			num("damage_location_variance", "Damage spread", "How far from the centre of an entity damage popups appear, as a fraction of its size", 0.8, 0),
		],
	},
	{
		name: "protection",
		title: "Entity Protection",
		description: "Stop players removing protected entities placed by others, players with the bypass permission are ignored",
		fields: [
			num("repeat_count", "Repeat count", "Protected entities removed within the repeat time which count as a repeat violation", 5, 1),
			num("repeat_minutes", "Repeat time", "How long removed protected entities are remembered", 20, 1, "minutes"),
			list("always_protected_names", "Protected entity names", "Entities which are always protected", []),
			list("always_protected_types", "Protected entity types", "Entity types which are always protected", [
				"boiler", "generator", "offshore-pump", "reactor", "heat-exchanger", "heat-pipe", "fusion-reactor", "fusion-generator", "power-switch", "rocket-silo",
			]),
			list("always_trigger_repeat_names", "Repeat entity names", "Entities which count as a repeat violation straight away", []),
			list("always_trigger_repeat_types", "Repeat entity types", "Entity types which count as a repeat violation straight away", [
				"reactor", "fusion-reactor", "rocket-silo",
			]),
		],
	},
	{
		name: "research",
		title: "Research",
		description: "Research effects, the per level limits live in config/research_data.lua",
		fields: [
			bool("pollution_ageing_by_research", "Pollution ageing", "Pollution ages faster with each level of the bonus inventory researches", false),
			bool("bonus_inventory.enabled", "Bonus inventory", "Extra inventory slots for each level of the researches below", true),
			list("bonus_inventory.res", "Bonus researches", "Researches which grant the extra slots", [
				"mining-productivity", "mining-productivity-2", "mining-productivity-3", "mining-productivity-4",
			]),
			num("bonus_inventory.rate", "Slots per level", "Extra slots for each research level", 5, 0, "slots"),
			num("bonus_inventory.limit", "Slot limit", "The most extra slots a force can have", 20, 0, "slots"),
		],
	},
	{
		name: "research_milestones",
		title: "Research Milestones",
		description: "A GUI tracking research against target times, the targets live in config/research_data.lua",
		fields: [
			str("log_file", "Log file", "Where the milestone times are written within script-output", "log/research.log"),
		],
	},
	{
		name: "rocket_info",
		title: "Rocket Info",
		description: "A GUI with rocket launch statistics, milestones, and build progress",
		fields: [
			bool("show_stats", "Statistics section", "Show the statistics section", true),
			bool("show_first_rocket", "First rocket", "Show when the first rocket was launched", true),
			bool("show_last_rocket", "Last rocket", "Show when the last rocket was launched", true),
			bool("show_fastest_rocket", "Fastest rocket", "Show the time taken for the fastest rocket", true),
			bool("show_total_rockets", "Total rockets", "Show the total number of rockets launched", true),
			bool("show_game_avg", "Game average", "Show the average across the entire map time", true),
			bool("show_milestones", "Milestones section", "Show when each milestone rocket was launched", true),
			bool("show_progress", "Progress section", "Show the build progress of each silo", true),
			bool("allow_zoom_to_map", "Zoom to map", "Clicking a silo zooms the map to it", true),
		],
	},
	{
		name: "science_production",
		title: "Science Production",
		description: "A GUI with the production of each science pack",
		fields: [
			bool("show_eta", "Show ETA", "Show the estimated time until the current research completes", true),
			num("color_flux", "Colour threshold", "How much production may fluctuate before the icon changes colour", 0.1, 0),
		],
	},
	{
		name: "repair",
		title: "Repair",
		description: "The /repair command which revives ghosts and heals entities in an area",
		fields: [
			bool("allow_ghost_revive", "Revive ghosts", "Build ghosts in the area instantly", true),
			bool("allow_blueprint_repair", "Revive blueprints", "Also revive ghosts which were never built, not only those left by destroyed entities", false),
			bool("allow_heal_entities", "Heal entities", "Heal entities in the area to full health", true),
		],
	},
	{
		name: "spawn_area",
		title: "Spawn Area",
		description: "Build the spawn area when the first player joins, only the turret and resource refills apply to an existing map",
		fields: [
			num("spawn_area.deconstruction_radius", "Clear radius", "Entities within this radius are removed", 20, 0, "tiles"),
			num("spawn_area.tile_radius", "Tile radius", "Tiles within this radius are replaced", 20, 0, "tiles"),
			str("spawn_area.deconstruction_tile", "Tile", "Tile placed within the tile radius", "concrete"),
			num("spawn_area.landfill_radius", "Landfill radius", "Water within this radius is filled", 50, 0, "tiles"),
			bool("turrets.enabled", "Turrets", "Place turrets at spawn and keep them refilled", true),
			str("turrets.ammo_type", "Turret ammo", "Ammo used to refill the turrets", "uranium-rounds-magazine"),
			bool("afk_belts.enabled", "AFK belts", "Place belt loops at spawn", true),
			str("afk_belts.belt_type", "Belt type", "Belt used for the loops", "transport-belt"),
			bool("afk_belts.protected", "Protect belts", "Players can not remove the belts", true),
			bool("water.enabled", "Water", "Place water tiles at spawn", true),
			str("water.water_tile", "Water tile", "Tile used for the water", "water-mud"),
			bool("entities.enabled", "Entities", "Place walls, chests, lamps, and poles at spawn", true),
			bool("entities.protected", "Protect entities", "Players can not remove the entities", true),
			bool("entities.operable", "Operable entities", "Players can open the entities, needed for the chests", true),
			bool("pattern.enabled", "Pattern", "Place a tile pattern at spawn", true),
			str("pattern.pattern_tile", "Pattern tile", "Tile used for the pattern", "stone-path"),
			bool("resource_refill_nearby.enabled", "Refill resources", "Add to resources near spawn every 10 minutes", false),
			num("resource_refill_nearby.range", "Refill range", "Distance from spawn which resources are refilled", 128, 0, "tiles"),
			list("resource_refill_nearby.resources_name", "Refilled resources", "Resources which are refilled", [
				"iron-ore", "copper-ore", "stone", "coal", "uranium-ore",
			]),
		],
	},
	{
		name: "station_auto_name",
		title: "Station Auto Name",
		description: "Name train stops when they are built",
		fields: [
			str("station_name", "Station name", "Placeholders: __icon__ __item_name__ __backer_name__ __direction__ __x__ __y__", "[L] __icon__"),
		],
	},
	{
		name: "task_list",
		title: "Task List",
		description: "A shared list of tasks, adding and editing need the task list permissions",
		fields: [
			bool("user_can_edit_own_tasks", "Own tasks editable", "The player who made a task can edit it without the edit permission", true),
		],
	},
	{
		name: "warp_list",
		title: "Warp List",
		description: "Warp points players can travel between, adding, editing, and bypassing limits need the warp list permissions",
		fields: [
			num("minimum_distance", "Minimum distance", "Warps of a force can not be closer together than this", 100, 1, "tiles"),
			num("cooldown_duration", "Cooldown", "Wait between warps", 60, 0, "seconds"),
			num("standard_proximity_radius", "Warp radius", "How close a player must stand to a warp to use it", 4, 1, "tiles"),
			num("spawn_proximity_radius", "Spawn radius", "How close a player must stand to spawn to use it as a warp", 20, 1, "tiles"),
			bool("user_can_edit_own_warps", "Own warps editable", "The player who made a warp can edit it without the edit permission", false),
		],
	},
	{
		name: "vlayer",
		title: "Virtual Layer",
		description: "A shared virtual surface for solar panels, accumulators, and storage, the items live in config/vlayer_items.lua",
		fields: [
			bool("unlimited_capacity", "Unlimited capacity", "Energy storage without accumulators", false),
			bool("unlimited_surface_area", "Unlimited area", "Place items without landfill", false),
			bool("modded_auto_downgrade", "Downgrade modded items", "Convert modded items to their base game equivalent, the originals can not be recovered", false),
			bool("power_on_space", "Power on platforms", "Energy interfaces can be built on space platforms", false),
			str("power_on_space_research.name", "Platform research", "The research needed to build energy interfaces on platforms", "research-productivity"),
			num("power_on_space_research.level", "Platform research level", "The level of that research", 10, 0),
			str("mimic_surface", "Mimic surface", "The surface the day cycle is copied from, empty for a fixed cycle", "nauvis"),
			num("interface_limit.energy", "Energy interfaces", "More than one lets disconnected power networks receive power", 1, 0),
			num("interface_limit.circuit", "Circuit interfaces", "How many circuit interfaces can exist", 20, 0),
			num("interface_limit.storage_input", "Input interfaces", "How many storage input interfaces can exist", 20, 0),
			num("interface_limit.storage_output", "Output interfaces", "More than zero allows item teleportation of the allowed items", 1, 0),
		],
	},
];

/** Check values against the fields of a feature, returning those which differ from their default */
export function validateFeatureValues(name: string, values: Record<string, FeatureValue>) {
	const feature = features.find(f => f.name === name);
	if (!feature) {
		throw new Error(`Unknown feature ${name}`);
	}

	const result: Record<string, FeatureValue> = {};
	for (const [key, value] of Object.entries(values)) {
		const field = feature.fields.find(f => f.name === key);
		if (!field) {
			throw new Error(`Feature ${name} has no setting ${key}`);
		}
		const error = fieldValueError(field, value);
		if (error) {
			throw new Error(`Setting ${key} of ${name} ${error}`);
		}
		if (!isDefaultValue(field, value)) {
			result[key] = value;
		}
	}
	return result;
}

/** Why a value does not fit a field, undefined when it does */
function fieldValueError(field: FeatureField, value: FeatureValue) {
	if (value === null) {
		return field.type === "string_list" || !field.optional ? "can not be null" : undefined;
	}
	switch (field.type) {
		case "string_list":
			if (!Array.isArray(value) || value.some(item => typeof item !== "string")) {
				return "must be a list of strings";
			}
			return undefined;
		case "number":
			if (typeof value !== "number" || !Number.isFinite(value)) {
				return "must be a finite number";
			}
			if (field.min !== undefined && value < field.min) {
				return `must be at least ${field.min}`;
			}
			return undefined;
		case "string":
			if (typeof value !== "string") {
				return "must be a string";
			}
			if (field.enum && !field.enum.includes(value)) {
				return `must be one of ${field.enum.join(", ")}`;
			}
			return undefined;
		default:
			return typeof value === field.type ? undefined : `must be a ${field.type}`;
	}
}

/** Check if two values are equal, lists are compared by content. */
export function sameValue(a: FeatureValue | undefined, b: FeatureValue | undefined) {
	if (Array.isArray(a) && Array.isArray(b)) {
		return a.length === b.length && a.every((item, index) => item === b[index]);
	}
	return a === b;
}

export function isDefaultValue(field: FeatureField, value: FeatureValue) {
	return sameValue(value, field.default);
}

/** Split stored values into those which still fit a field and the names of the rest */
export function pruneFeatureValues(feature: Feature, values: Record<string, FeatureValue>) {
	const kept: Record<string, FeatureValue> = {};
	const dropped: string[] = [];
	for (const [key, value] of Object.entries(values)) {
		const field = feature.fields.find(f => f.name === key);
		if (field && !fieldValueError(field, value)) {
			kept[key] = value;
		} else {
			dropped.push(key);
		}
	}
	return { kept, dropped };
}
