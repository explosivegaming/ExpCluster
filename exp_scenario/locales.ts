/**
 * Country of each Factorio locale without a region in its code, used for the
 * flag. Languages spoken across many countries or without one, such as ar,
 * ca, eo, and eu, are left out and get no flag.
 */
const localeCountries: Record<string, string> = {
	af: "ZA", be: "BY", bg: "BG", cs: "CZ", da: "DK", de: "DE", el: "GR", en: "GB", et: "EE",
	fa: "IR", fi: "FI", fil: "PH", fr: "FR", he: "IL", hr: "HR", hu: "HU", id: "ID", is: "IS",
	it: "IT", ja: "JP", ka: "GE", kk: "KZ", ko: "KR", lt: "LT", lv: "LV", nl: "NL", no: "NO",
	pl: "PL", ro: "RO", ru: "RU", sk: "SK", sl: "SI", sq: "AL", sr: "RS", th: "TH", tr: "TR",
	uk: "UA", vi: "VN",
};

/** Flag emoji for a Factorio locale such as "de" or "pt-BR", empty when it has no obvious country. */
export function localeFlag(locale: string) {
	const [language, region] = locale.split("-");
	const country = region ?? localeCountries[language];
	if (!country || !/^[A-Z]{2}$/.test(country)) {
		return "";
	}
	// Regional indicator symbols start at U+1F1E6 for A
	return String.fromCodePoint(...[...country].map(letter => 0x1F1E6 + letter.charCodeAt(0) - 65));
}

/** English name of a locale, the code itself when it is not known. */
export function localeName(locale: string) {
	try {
		return new Intl.DisplayNames(["en"], { type: "language" }).of(locale) ?? locale;
	} catch {
		return locale;
	}
}
