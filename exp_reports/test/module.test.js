"use strict";
const path = require("node:path");
const t = require("tap");
const { reportLuaTests } = require("../../test/lua/runner");

const envFile = path.join(__dirname, "module", "env.lua");

// Each file runs in its own lua state, and each test in a fresh environment
t.test("control.lua", t2 => {
	for (const file of ["requests.lua", "receivers.lua"]) {
		t2.test(file, t3 => reportLuaTests(t3, envFile, path.join(__dirname, "module", file)));
	}
	t2.end();
});
