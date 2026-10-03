/**
 * The scenario features which can be configured from the web interface.
 *
 * Defaults must match the Features.config call in the lua module,
 * test/features.test.js checks this. Only list settings which the lua side
 * reads at runtime. Settings in nested tables are named "section.key".
 */

export type FeatureValue = boolean | number | string | string[] | null;

/**
 * A setting of a feature, shaped like a clusterio config field definition so
 * the web interface can render it with the same inputs, including the input
 * components registered by plugins.
 */
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
		name: "nuke_protection",
		title: "Nuke Protection",
		description: "Remove banned items from players without the nuke protection bypass permission",
		fields: [
			list("banned_items", "Banned items", "Items which are moved to a chest at spawn", ["atomic-bomb"]),
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
];

/**
 * Check the values for a feature against its fields.
 *
 * @returns the values which differ from their default
 * @throws Error if the feature is unknown, or a value is unknown or the wrong type
 */
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
		checkFieldValue(field, value, `Setting ${key} of ${name}`);
		if (!isDefaultValue(field, value)) {
			result[key] = value;
		}
	}
	return result;
}

function checkFieldValue(field: FeatureField, value: FeatureValue, label: string) {
	if (value === null) {
		if (field.type === "string_list" || !field.optional) {
			throw new Error(`${label} can not be null`);
		}
		return;
	}
	switch (field.type) {
		case "string_list":
			if (!Array.isArray(value) || value.some(item => typeof item !== "string")) {
				throw new Error(`${label} must be a list of strings`);
			}
			return;
		case "number":
			if (typeof value !== "number" || !Number.isFinite(value)) {
				throw new Error(`${label} must be a finite number`);
			}
			if (field.min !== undefined && value < field.min) {
				throw new Error(`${label} must be at least ${field.min}`);
			}
			return;
		case "string":
			if (typeof value !== "string") {
				throw new Error(`${label} must be a string`);
			}
			if (field.enum && !field.enum.includes(value)) {
				throw new Error(`${label} must be one of ${field.enum.join(", ")}`);
			}
			return;
		default:
			if (typeof value !== field.type) {
				throw new Error(`${label} must be a ${field.type}`);
			}
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

/**
 * Drop stored values which no longer match the fields of a feature, after a
 * setting was renamed, removed, or changed type.
 *
 * @returns the values which are still valid, and the names of those dropped
 */
export function pruneFeatureValues(feature: Feature, values: Record<string, FeatureValue>) {
	const kept: Record<string, FeatureValue> = {};
	const dropped: string[] = [];
	for (const [key, value] of Object.entries(values)) {
		const field = feature.fields.find(f => f.name === key);
		try {
			if (!field) {
				throw new Error("removed");
			}
			checkFieldValue(field, value, key);
			kept[key] = value;
		} catch {
			dropped.push(key);
		}
	}
	return { kept, dropped };
}
