import t from "tap";
import * as messages from "../dist/node/messages.js";
import { testMatrix, testRoundTripJsonSerialisable } from "../../test/common.js";

const sampleReport = new messages.ReportRecord(7, "bob", "alice", "griefing", "EXP", 12345);

t.test("class ReportRecord", t2 => {
	testRoundTripJsonSerialisable(t2, messages.ReportRecord, testMatrix(
		[7], // id
		["bob"], // playerName
		["alice"], // byPlayerName
		["griefing"], // reason
		["", "EXP"], // instanceName
		[0, 12345], // updatedAtMs
		[false, true], // isDeleted
	));

	t2.end();
});

t.test("class ReportUpdatedEvent", t2 => {
	testRoundTripJsonSerialisable(t2, messages.ReportUpdatedEvent, testMatrix(
		[[], [sampleReport]], // updates
	));

	t2.end();
});

t.test("class ReportListRequest", t2 => {
	testRoundTripJsonSerialisable(t2, messages.ReportListRequest, testMatrix(
		[undefined, "bob"], // playerName
	));

	t2.end();
});

t.test("class ReportGetRequest", t2 => {
	testRoundTripJsonSerialisable(t2, messages.ReportGetRequest, testMatrix(
		[7], // id
	));

	t2.end();
});

t.test("class ReportCreateRequest", t2 => {
	testRoundTripJsonSerialisable(t2, messages.ReportCreateRequest, testMatrix(
		["bob"], // playerName
		["griefing"], // reason
		["", "alice"], // byPlayerName
	));

	t2.end();
});

t.test("class ReportDeleteRequest", t2 => {
	testRoundTripJsonSerialisable(t2, messages.ReportDeleteRequest, testMatrix(
		[7], // id
	));

	t2.end();
});
