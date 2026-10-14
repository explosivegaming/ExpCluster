import t from "tap";
import { localeFlag, localeName } from "../dist/node/locales.js";

// The locale folders of Factorio 2.1
const factorioLocales = [
	"af", "ar", "be", "bg", "ca", "cs", "da", "de", "el", "en", "eo", "es-ES", "et", "eu", "fa", "fi", "fil", "fr",
	"fy-NL", "ga-IE", "he", "hr", "hu", "id", "is", "it", "ja", "ka", "kk", "ko", "lt", "lv", "nl", "no", "pl",
	"pt-BR", "pt-PT", "ro", "ru", "sk", "sl", "sq", "sr", "sv-SE", "th", "tr", "uk", "vi", "zh-CN", "zh-TW",
];
const noFlag = ["ar", "ca", "eo", "eu"];

t.test("localeFlag()", async t2 => {
	t2.equal(localeFlag("de"), "\u{1F1E9}\u{1F1EA}", "language codes use the table");
	t2.equal(localeFlag("pt-BR"), "\u{1F1E7}\u{1F1F7}", "regions are used directly");
	t2.equal(localeFlag("zh-TW"), "\u{1F1F9}\u{1F1FC}");
	for (const locale of factorioLocales) {
		t2.equal(localeFlag(locale) === "", noFlag.includes(locale), `${locale} has a flag unless it has no country`);
	}
	t2.equal(localeFlag("xx"), "", "unknown languages have no flag");
	t2.equal(localeFlag(""), "");
});

t.test("localeName()", async t2 => {
	t2.equal(localeName("de"), "German");
	t2.equal(localeName("not a locale"), "not a locale", "invalid codes are shown as they are");
});
