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

/** Read a literal default from a Features.config call, only covers single line booleans, numbers, and strings. */
function luaDefault(source, key) {
	const match = new RegExp(`^\\s*${key} = (true|false|-?[\\d.]+|"[^"]*"),`, "m").exec(source);
	return match ? JSON.parse(match[1]) : undefined;
}

t.test("features", t2 => {
	for (const feature of features) {
		t2.test(feature.name, t3 => {
			const declarations = moduleFiles.filter(([, source]) => (
				source.includes(`Features.config("${feature.name}"`) || source.includes(`Features.guard("${feature.name}"`)
			));
			t3.equal(declarations.length, 1, "one lua file declares the feature");
			const source = declarations[0]?.[1] ?? "";
			for (const field of feature.fields) {
				t3.equal(luaDefault(source, field.name), field.default, `${field.name} default matches the lua side`);
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
	t2.end();
});
