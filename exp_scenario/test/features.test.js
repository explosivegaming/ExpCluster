import fs from "node:fs";
import path from "node:path";
import t from "tap";
import { features, validateFeatureValues } from "../dist/node/features.js";

/** Every lua file in the module, by path relative to it. */
function luaFiles(dir, prefix = "") {
	return fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
		const relative = path.posix.join(prefix, entry.name);
		if (entry.isDirectory()) {
			return luaFiles(path.join(dir, entry.name), relative);
		}
		return entry.name.endsWith(".lua") ? [[relative, fs.readFileSync(path.join(dir, entry.name), "utf8")]] : [];
	});
}

const moduleFiles = luaFiles(path.join(import.meta.dirname, "..", "module"));

/**
 * Read a default from a Feature.register call, a path of "a.b" looks for b after the table a starts.
 * Only covers booleans, numbers, strings, lists of strings, and Feature.optional.
 */
function luaDefault(source, path) {
	const keys = path.split(".");
	let start = 0;
	for (const section of keys.slice(0, -1)) {
		const match = new RegExp(`^\\s*${section} = \\{`, "m").exec(source.slice(start));
		if (!match) {
			return undefined;
		}
		start += match.index + match[0].length;
	}

	const key = keys.at(-1);
	const match = new RegExp(`^\\s*${key} = (true|false|-?[\\d.]+|"[^"]*"|Feature\\.optional\\("\\w+"\\)|\\{[^{}]*\\})`, "m")
		.exec(source.slice(start));
	if (!match) {
		return undefined;
	}
	const literal = match[1];
	if (literal.startsWith("Feature.optional")) {
		return null;
	}
	if (literal.startsWith("{")) {
		return [...literal.matchAll(/"([^"]*)"/g)].map(item => item[1]);
	}
	return JSON.parse(literal);
}

t.test("features", t2 => {
	for (const feature of features) {
		t2.test(feature.name, t3 => {
			const declarations = moduleFiles.filter(([, source]) => (
				source.includes(`Feature.register("${feature.name}"`)
			));
			t3.equal(declarations.length, 1, "one lua file declares the feature");
			const source = declarations[0]?.[1] ?? "";
			for (const field of feature.fields) {
				t3.strictSame(luaDefault(source, field.name), field.default, `${field.name} default matches the lua side`);
			}
			t3.end();
		});
	}
	t2.end();
});

t.test("validateFeatureValues()", t2 => {
	t2.same(
		validateFeatureValues("death_markers", { show_map_markers: false, collect_corpses: true }),
		{ show_map_markers: false },
		"values equal to their default are dropped",
	);
	t2.throws(() => validateFeatureValues("unknown", {}), { message: "Unknown feature unknown" });
	t2.throws(
		() => validateFeatureValues("death_markers", { map_icon: "x" }),
		{ message: "Feature death_markers has no setting map_icon" },
	);
	t2.throws(
		() => validateFeatureValues("death_markers", { show_map_markers: "no" }),
		{ message: "Setting show_map_markers of death_markers must be a boolean" },
	);
	t2.throws(
		() => validateFeatureValues("afk_kick", { afk_minutes: 0 }),
		{ message: "Setting afk_minutes of afk_kick must be at least 1" },
	);
	t2.throws(
		() => validateFeatureValues("afk_kick", { afk_minutes: Infinity }),
		{ message: "Setting afk_minutes of afk_kick must be a finite number" },
	);
	t2.throws(
		() => validateFeatureValues("protection", { always_protected_types: ["boiler", 1] }),
		{ message: "Setting always_protected_types of protection must be a list of strings" },
	);
	t2.throws(
		() => validateFeatureValues("afk_kick", { afk_minutes: null }),
		{ message: "Setting afk_minutes of afk_kick can not be null" },
	);
	t2.same(
		validateFeatureValues("protection", { always_protected_types: ["boiler"], always_trigger_repeat_types: ["reactor", "fusion-reactor", "rocket-silo"] }),
		{ always_protected_types: ["boiler"] },
		"lists equal to their default are dropped",
	);
	t2.same(validateFeatureValues("afk_kick", { active_role_id: null }), {}, "no role is the default");
	t2.same(validateFeatureValues("afk_kick", { active_role_id: 3 }), { active_role_id: 3 });
	t2.same(validateFeatureValues("spawn_area", { "turrets.enabled": false }), { "turrets.enabled": false }, "nested settings");
	t2.end();
});
