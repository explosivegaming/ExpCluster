import fs from "node:fs";
import path from "node:path";
import t from "tap";
import { features, validateFeatureValues } from "../dist/node/features.js";

/** Read a literal default from a module/config file, only covers single line booleans, numbers, and strings. */
function luaDefault(source, key) {
	const match = new RegExp(`^\\s*${key} = (true|false|-?[\\d.]+|"[^"]*"),`, "m").exec(source);
	return match ? JSON.parse(match[1]) : undefined;
}

t.test("features", t2 => {
	for (const feature of features) {
		t2.test(feature.name, t3 => {
			const file = path.join(import.meta.dirname, "..", "module", "config", `${feature.name}.lua`);
			const source = fs.readFileSync(file, "utf8");
			t3.match(source, `Features.register("${feature.name}"`, "the config file registers the feature");
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
		() => validateFeatureValues("death_markers", { period_check_map_tags: 60 }),
		{ message: "Feature death_markers has no setting period_check_map_tags" },
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
