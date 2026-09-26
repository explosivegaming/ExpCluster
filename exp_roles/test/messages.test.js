import t from "tap";
import * as messages from "../dist/node/messages.js";
import { testMatrix, testRoundTripJsonSerialisable } from "../../test/common.js";

const fullMeta = new messages.RoleMetaRecord(
	7, 3, 1, "Mod", "[Mod]", new messages.RoleColor(1, 2, 3), 3600000, true, 12345, false,
);

t.test("class RoleColor", t2 => {
	testRoundTripJsonSerialisable(t2, messages.RoleColor, testMatrix(
		[0, 255], // r
		[0, 128], // g
		[0, 1], // b
	));

	t2.end();
});

t.test("class RoleMetaRecord", t2 => {
	testRoundTripJsonSerialisable(t2, messages.RoleMetaRecord, testMatrix(
		[7], // id
		[3], // order
		[0, 1], // priority
		["", "Mod"], // shortHand
		["", "[Mod]"], // tag
		[null, new messages.RoleColor(1, 2, 3)], // color
		[null, 3600000], // autoAssignOnlineTimeMs
		[false, true], // blockAutoAssign
		[0, 12345], // updatedAtMs
		[false, true], // isDeleted
	));

	t2.end();
});

t.test("class RoleRecord", t2 => {
	testRoundTripJsonSerialisable(t2, messages.RoleRecord, testMatrix(
		[7], // id
		["Moderator"], // name
		[[], ["a.b", "c.d"]], // permissions
		[new messages.RoleMetaRecord(7, 3), fullMeta], // meta
		[false, true], // isDefault
		[0, 12345], // updatedAtMs
		[false, true], // isDeleted
	));

	t2.end();
});

t.test("class AssignmentRecord", t2 => {
	testRoundTripJsonSerialisable(t2, messages.AssignmentRecord, testMatrix(
		["alice"], // name
		[new Set(), new Set([5, 6])], // roleIds
		[0, 12345], // updatedAtMs
		[false, true], // isDeleted
	));

	t2.test("get id()", t3 => {
		const record = new messages.AssignmentRecord("alice", new Set([5]), 12345);
		t3.equal(record.id, "alice");
		t3.end();
	});

	t2.end();
});

const sampleRecord = new messages.RoleRecord(7, "Moderator", ["a.b"], fullMeta, true, 12345);
const sampleAssignment = new messages.AssignmentRecord("alice", new Set([5]), 12345);

t.test("class RoleUpdatedEvent", t2 => {
	testRoundTripJsonSerialisable(t2, messages.RoleUpdatedEvent, testMatrix(
		[[], [sampleRecord]], // updates
	));

	t2.end();
});

t.test("class AssignmentUpdatedEvent", t2 => {
	testRoundTripJsonSerialisable(t2, messages.AssignmentUpdatedEvent, testMatrix(
		[[], [sampleAssignment]], // updates
	));

	t2.end();
});

t.test("class RoleMetaUpdateRequest", t2 => {
	testRoundTripJsonSerialisable(t2, messages.RoleMetaUpdateRequest, testMatrix(
		[new messages.RoleMetaRecord(7, 3), fullMeta], // meta
	));

	t2.end();
});

t.test("class AssignmentUpdateRequest", t2 => {
	testRoundTripJsonSerialisable(t2, messages.AssignmentUpdateRequest, testMatrix(
		["alice"], // name
		[[], [5]], // assign
		[[], [6]], // unassign
	));

	t2.end();
});

t.test("encodeRolesForLua() sends each permission name once", t2 => {
	const meta = id => new messages.RoleMetaRecord(id, id);
	const encoded = messages.encodeRolesForLua([
		new messages.RoleRecord(1, "A", ["p.one", "p.two"], meta(1)),
		new messages.RoleRecord(2, "B", ["p.two", "p.three"], meta(2)),
	]);

	t2.strictSame(encoded.permission_names, ["p.one", "p.two", "p.three"], "names are deduplicated");
	t2.strictSame(encoded.roles[0].permissions, [0, 1], "indexes are zero based");
	t2.strictSame(encoded.roles[1].permissions, [1, 2], "shared names reuse their index");
	t2.end();
});
