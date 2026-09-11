import path from "node:path";
import fs from "node:fs";
import { createRequire } from "node:module";

/**
 * Run one lua test file in its own lua state and return its results.
 *
 * The state is created here, on first use by the caller, so every test file
 * gets an independent set of stubs. Three chunks run in order, each taking one
 * argument and returning one value:
 *
 * 1. The plugin's env.lua, receiving this directory so it can load the shared
 *    stubs and framework, returning its environment module.
 * 2. The test file, receiving the environment module, declaring its tests.
 * 3. The tests then run, each against a fresh environment, and the results
 *    are returned as JSON.
 *
 * @param {string} envFile - Absolute path of the plugin's test/lua/env.lua.
 * @param {string} testFile - Absolute path of the lua test file to run.
 * @returns {{ name: string, ok: boolean, detail?: string }[]}
 */
function runLuaTests(envFile, testFile) {
	// fengari is a devDependency of the plugin whose tests run, so resolve it from there
	const { lua, lauxlib, lualib, to_luastring, to_jsstring } = createRequire(testFile)("fengari");
	const L = lauxlib.luaL_newstate();
	lualib.luaL_openlibs(L);

	const load = (file) => {
		const code = fs.readFileSync(file);
		const status = lauxlib.luaL_loadbuffer(L, code, code.length, to_luastring(`@${file}`));
		if (status !== lua.LUA_OK) {
			throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
		}
	};
	const call = () => {
		if (lua.lua_pcall(L, 1, 1, 0) !== lua.LUA_OK) {
			throw new Error(to_jsstring(lua.lua_tostring(L, -1)));
		}
	};

	load(envFile);
	lua.lua_pushstring(L, to_luastring(import.meta.dirname));
	call();

	// The environment stays on the stack and is passed to the test chunk
	load(testFile);
	lua.lua_insert(L, -2);
	call();

	const json = to_jsstring(lua.lua_tostring(L, -1));
	return JSON.parse(json);
}

/** Report the results of a lua test file through a tap test object. */
function reportLuaTests(t, envFile, testFile) {
	const results = runLuaTests(envFile, testFile);
	t.ok(results.length > 0, `${path.basename(testFile)} produced results`);
	for (const result of results) {
		t.ok(result.ok, result.name, result.detail ? { detail: result.detail } : {});
	}
	t.end();
}

export { runLuaTests, reportLuaTests };
