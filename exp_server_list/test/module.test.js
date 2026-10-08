import path from "node:path";
import t from "tap";
import { reportLuaTests } from "../../test/lua/runner.js";

const envFile = path.join(import.meta.dirname, "module", "env.lua");

t.test("control.lua", t2 => reportLuaTests(t2, envFile, path.join(import.meta.dirname, "module", "control.lua")));
