import path from "node:path";
import t from "tap";
import { reportLuaTests } from "../../test/lua/runner.js";

const envFile = path.join(import.meta.dirname, "module", "env.lua");

// Each file runs in its own lua state, and each test in a fresh environment
t.test("features.lua", t2 => reportLuaTests(t2, envFile, path.join(import.meta.dirname, "module", "features.lua")));
