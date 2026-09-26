import path from "node:path";
import t from "tap";
import { reportLuaTests } from "../../test/lua/runner.js";

const envFile = path.join(import.meta.dirname, "module", "env.lua");

// Each file runs in its own lua state, and each test in a fresh environment
t.test("control.lua", t2 => {
	for (const file of ["lookup.lua", "players.lua", "assignment.lua", "sync.lua", "holders.lua"]) {
		t2.test(file, t3 => reportLuaTests(t3, envFile, path.join(import.meta.dirname, "module", file)));
	}
	t2.end();
});
