import path from "node:path";
import t from "tap";
import { reportLuaTests } from "../../test/lua/runner.js";

const envFile = path.join(import.meta.dirname, "module", "env.lua");

// Each file runs in its own lua state, and each test in a fresh environment
t.test("lua module", t2 => {
	for (const file of ["control.lua", "events.lua"]) {
		t2.test(file, t3 => reportLuaTests(t3, envFile, path.join(import.meta.dirname, "module", file)));
	}
	t2.end();
});
