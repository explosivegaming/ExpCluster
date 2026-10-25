import t from "tap";
import * as messages from "../dist/node/messages.js";
import { testMatrix, testRoundTripJsonSerialisable } from "../../test/common.js";

const sampleReport = new messages.ReportRecord(7, "bob", "alice", "griefing", "EXP", 12345);
const sampleEntry = new messages.WatchListRecord("bob", "griefing", "alice", 12345);

t.test("class ReportRecord", t2 => {
	testRoundTripJsonSerialisable(t2, messages.ReportRecord, testMatrix(
		[7], // id
		["bob"], // playerName
		["alice"], // byPlayerName
		["griefing"], // reason
		["", "EXP"], // instanceName
		[12345], // createdAtMs
		[false, true], // isRead
		[0, 12345], // updatedAtMs
		[false, true], // isDeleted
	));

	t2.end();
});

t.test("class WatchListRecord", t2 => {
	testRoundTripJsonSerialisable(t2, messages.WatchListRecord, testMatrix(
		["bob"], // playerName
		["griefing"], // reason
		["alice"], // byPlayerName
		[12345], // createdAtMs
		[0, 12345], // updatedAtMs
		[false, true], // isDeleted
	));
	t2.equal(new messages.WatchListRecord("Bob", "griefing", "alice").id, "bob", "the lower case player name is the id");

	t2.end();
});

t.test("class ReportUpdatedEvent", t2 => {
	testRoundTripJsonSerialisable(t2, messages.ReportUpdatedEvent, testMatrix(
		[[], [sampleReport]], // updates
	));

	t2.end();
});

t.test("class WatchListUpdatedEvent", t2 => {
	testRoundTripJsonSerialisable(t2, messages.WatchListUpdatedEvent, testMatrix(
		[[], [sampleEntry]], // updates
	));

	t2.end();
});

t.test("class WatchedPlayerJoinedEvent", t2 => {
	testRoundTripJsonSerialisable(t2, messages.WatchedPlayerJoinedEvent, testMatrix(
		["bob"], // playerName
		["EXP"], // instanceName
		[undefined, sampleEntry], // watchListEntry
		[[], [sampleReport]], // unreadReports
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

t.test("class ReportSetReadRequest", t2 => {
	testRoundTripJsonSerialisable(t2, messages.ReportSetReadRequest, testMatrix(
		[7], // id
		[false, true], // isRead
	));

	t2.end();
});

t.test("class WatchListAddRequest", t2 => {
	testRoundTripJsonSerialisable(t2, messages.WatchListAddRequest, testMatrix(
		["bob"], // playerName
		["griefing"], // reason
	));

	t2.end();
});

t.test("class WatchListRemoveRequest", t2 => {
	testRoundTripJsonSerialisable(t2, messages.WatchListRemoveRequest, testMatrix(
		["bob"], // playerName
	));

	t2.end();
});
