import { compile } from "@clusterio/lib";

/**
 * Generate a flat array of tests from a matrix of inputs.
 *
 * @template {any[][]} T
 * @param {T} arrays - A list of arrays representing the different values for each argument
 * @returns {Array<{ [K in keyof T]: T[K][number] }>}
 * 		An array of tuples, each containing one value from each input array.
 */
function testMatrix(...arrays) {
	return arrays.reduce((acc, curr) => acc.flatMap(a => curr.map(b => [...a, b])), [[]]);
}

/**
 * Test that a class is round trip JSON serialisable across multiple test cases.
 *
 * @template {any[]} T - Constructor arguments
 * @param {import("tap").Test} t - Parent test.
 * @param {{new(...args: T): object}} Class - The class which has toJSON and fromJSON methods.
 * @param {T[]} tests - The test inputs to pass to the class constructor.
 */
function testRoundTripJsonSerialisable(t, Class, tests) {
	const validate = compile(Class.jsonSchema);

	for (const test of tests) {
		const name = JSON.stringify(test);

		try {
			const original = new Class(...test);
			const jsonObject = JSON.parse(JSON.stringify(original));
			const reconstructed = Class.fromJSON(jsonObject);

			if (!validate(jsonObject)) {
				t.fail(`schema validation: ${name}`, {
					diagnostic: {
						json: jsonObject,
						errors: validate.errors,
					},
				});
				continue;
			}

			t.strictSame(reconstructed, original, `round trip: ${name}`);
		} catch (error) {
			t.fail(`round trip: ${name}`, { error });
		}
	}
}

export {
	testMatrix,
	testRoundTripJsonSerialisable,
};
