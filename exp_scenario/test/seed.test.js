import t from "tap";
import * as lib from "@clusterio/lib";
import { seedRoles, seedGroups, flattenSeedPermissions } from "../dist/node/seed.js";

import { plugin } from "../dist/node/index.js";

// Registering the plugin defines the permissions the seed grants
lib.registerPluginPermissions([plugin]);

t.test("seedRoles[] grant only defined permissions", t2 => {
	for (const role of seedRoles) {
		for (const permission of role.permissions) {
			t2.ok(lib.permissions.has(permission), `${role.name} grants defined permission ${permission}`);
		}
	}
	t2.end();
});

t.test("seedRoles[] are unique with one default and one admin", t2 => {
	const names = seedRoles.map(role => role.name);
	t2.strictSame(names.length, new Set(names).size, "names are unique");
	t2.strictSame(seedRoles.filter(role => role.isDefault).length, 1, "one default role");
	t2.strictSame(seedRoles.filter(role => role.isAdmin).length, 1, "one admin role");
	t2.end();
});

t.test("seedRoles[] are placed in defined groups", t2 => {
	const groupNames = new Set(seedGroups.map(group => group.name));
	for (const role of seedRoles) {
		if (role.group !== undefined) {
			t2.ok(groupNames.has(role.group), `${role.name} is placed in defined group ${role.group}`);
		}
	}
	t2.end();
});

t.test("seedGroups[] are unique", t2 => {
	const names = seedGroups.map(group => group.name);
	t2.strictSame(names.length, new Set(names).size, "names are unique");
	for (const group of seedGroups) {
		t2.strictSame(
			group.inputActions.length,
			new Set(group.inputActions).size,
			`${group.name} lists each input action once`,
		);
	}
	t2.end();
});

t.test("flattenSeedPermissions() inherits permissions from parent roles", t2 => {
	const byName = new Map(seedRoles.map(role => [role.name, role]));
	for (const role of seedRoles) {
		if (role.parent === undefined) {
			continue;
		}

		const parent = byName.get(role.parent);
		t2.ok(parent, `${role.name} has parent ${role.parent}`);

		const flattened = flattenSeedPermissions(role);
		for (const permission of flattenSeedPermissions(parent)) {
			t2.ok(flattened.has(permission), `${role.name} inherits ${permission}`);
		}
	}
	t2.end();
});

t.test("flattenSeedPermissions() does not inherit permissions when parent is undefined", t2 => {
	for (const role of seedRoles) {
		if (role.parent !== undefined) {
			continue;
		}

		const flattened = flattenSeedPermissions(role);
		for (const permission of role.permissions) {
			t2.ok(flattened.has(permission), `${role.name} contains ${permission}`);
		}

		t2.equal(
			flattened.size,
			role.permissions.length,
			`${role.name} has no inherited permissions`,
		);
	}
	t2.end();
});