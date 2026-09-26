/** Create the roles and permission groups the scenario shipped with, see seed.ts. */
export class SeedRequest {
	declare ["constructor"]: typeof SeedRequest;
	static plugin = "exp_scenario" as const;
	static type = "request" as const;
	static src = "control" as const;
	static dst = "controller" as const;
	static permission = "exp_scenario.seed" as const;

	constructor() {}
}
