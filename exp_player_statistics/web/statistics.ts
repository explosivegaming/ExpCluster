/** Same order and names as module/config.lua and module/locale/en.cfg */
export const statistics: [name: string, title: string][] = [
	["Playtime", "Playtime"],
	["AfkTime", "AFK Time"],
	["MapsPlayed", "Maps Played"],
	["JoinCount", "Join Count"],
	["ChatMessages", "Messages"],
	["CommandsUsed", "Commands"],
	["RocketsLaunched", "Rockets Launched"],
	["ResearchCompleted", "Research Completed"],
	["MachinesBuilt", "Machines Built"],
	["MachinesRemoved", "Machines Removed"],
	["TilesBuilt", "Tiles Placed"],
	["TilesRemoved", "Tiles Removed"],
	["TreesDestroyed", "Trees Destroyed"],
	["OreMined", "Ore Mined"],
	["ItemsCrafted", "Items Crafted"],
	["ItemsPickedUp", "Items Picked Up"],
	["Kills", "Kills"],
	["Deaths", "Deaths"],
	["DamageDealt", "Damage Dealt"],
	["DistanceTravelled", "Distance Travelled"],
	["CapsulesUsed", "Capsules Used"],
	["EntityRepaired", "Machines Repaired"],
	["DeconstructionPlannerUsed", "Decon Planner Used"],
	["MapTagsMade", "Map Tags Created"],
];

/** Measured in minutes */
const timeStatistics = new Set(["Playtime", "AfkTime"]);

export function formatValue(name: string, value: number) {
	if (timeStatistics.has(name)) {
		return `${Math.floor(value / 60)} h ${value % 60} m`;
	}
	if (name === "DistanceTravelled") {
		return `${value.toLocaleString()} tiles`;
	}
	return value.toLocaleString();
}
