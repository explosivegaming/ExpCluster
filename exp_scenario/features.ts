/**
 * The scenario features which can be configured from the web interface.
 *
 * Defaults must match module/config/<name>.lua, test/features.test.js checks
 * this. Only list settings which the lua side reads at runtime.
 */

export type FeatureValue = boolean | number | string;

export type FeatureField = {
	name: string,
	title: string,
	description: string,
} & (
	| { type: "boolean", default: boolean }
	| { type: "number", default: number, min?: number, unit?: string }
	| { type: "string", default: string }
);

export type Feature = {
	name: string,
	title: string,
	description: string,
	fields: FeatureField[],
};

export const features: Feature[] = [
	{
		name: "afk_kick",
		title: "AFK Kick",
		description: "Kick everyone when nobody online is active",
		fields: [
			{
				name: "admin_as_active",
				title: "Admins count as active",
				description: "Admins are active regardless of how long they have been afk",
				type: "boolean",
				default: true,
			},
			{
				name: "trust_as_active",
				title: "Trusted players count as active",
				description: "Players with enough playtime are active regardless of how long they have been afk",
				type: "boolean",
				default: true,
			},
			{
				name: "afk_minutes",
				title: "AFK after",
				description: "Time without input before a player counts as afk",
				type: "number",
				default: 10,
				min: 1,
				unit: "minutes",
			},
			{
				name: "kick_minutes",
				title: "Kick after",
				description: "Time without any active player before everyone is kicked",
				type: "number",
				default: 30,
				min: 1,
				unit: "minutes",
			},
			{
				name: "trust_minutes",
				title: "Trusted after",
				description: "Playtime needed before a player counts as trusted",
				type: "number",
				default: 600,
				min: 0,
				unit: "minutes",
			},
		],
	},
	{
		name: "chat_auto_reply",
		title: "Chat Auto Reply",
		description: "Reply to key words in chat and run chat commands",
		fields: [
			{
				name: "command_prefix",
				title: "Command prefix",
				description: "Prefix for chat commands, and for key words to reply to everyone",
				type: "string",
				default: "!",
			},
			{
				name: "command_admin_only",
				title: "Commands for admins only",
				description: "Only admins can use chat commands",
				type: "boolean",
				default: false,
			},
		],
	},
	{
		name: "death_markers",
		title: "Death Markers",
		description: "What happens when players die",
		fields: [
			{
				name: "collect_corpses",
				title: "Collect corpses",
				description: "Put the items of expired corpses in chests",
				type: "boolean",
				default: true,
			},
			{
				name: "show_map_markers",
				title: "Show map markers",
				description: "Add a map marker where a player died",
				type: "boolean",
				default: true,
			},
			{
				name: "clean_map_markers",
				title: "Remove map markers",
				description: "Remove the map marker once the corpse is gone",
				type: "boolean",
				default: false,
			},
			{
				name: "include_time_of_death",
				title: "Include time of death",
				description: "Add the time of death to the map marker",
				type: "boolean",
				default: true,
			},
			{
				name: "show_light_at_corpse",
				title: "Light at corpse",
				description: "Draw a light in the player's colour at their corpse",
				type: "boolean",
				default: true,
			},
			{
				name: "show_line_to_corpse",
				title: "Line to corpse",
				description: "Draw a line from a respawned player to their corpse",
				type: "boolean",
				default: true,
			},
		],
	},
	{
		name: "mine_depletion",
		title: "Mine Depletion",
		description: "Deconstruct mining drills when their resources run out",
		fields: [
			{
				name: "chest",
				title: "Remove output chests",
				description: "Also deconstruct the chest a drill outputs into",
				type: "boolean",
				default: true,
			},
			{
				name: "beacon",
				title: "Remove beacons",
				description: "Also deconstruct beacons which no longer affect anything",
				type: "boolean",
				default: true,
			},
			{
				name: "fluid",
				title: "Replace with pipes",
				description: "Place pipe ghosts where a drill carried fluid",
				type: "boolean",
				default: true,
			},
		],
	},
	{
		name: "station_auto_name",
		title: "Station Auto Name",
		description: "Name train stops when they are built",
		fields: [
			{
				name: "station_name",
				title: "Station name",
				description: "Placeholders: __icon__ __item_name__ __backer_name__ __direction__ __x__ __y__",
				type: "string",
				default: "[L] __icon__",
			},
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
		if (typeof value !== field.type) {
			throw new Error(`Setting ${key} of ${name} must be a ${field.type}`);
		}
		if (field.type === "number" && !Number.isFinite(value)) {
			throw new Error(`Setting ${key} of ${name} must be a finite number`);
		}
		if (field.type === "number" && field.min !== undefined && (value as number) < field.min) {
			throw new Error(`Setting ${key} of ${name} must be at least ${field.min}`);
		}
		if (value !== field.default) {
			result[key] = value;
		}
	}
	return result;
}
