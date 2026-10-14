import React, { useEffect, useRef, useState } from "react";
import { Alert, Button, Space, Spin, Typography } from "antd";

declare const webRoot: string;

const { Link, Paragraph, Text } = Typography;
const sessionKey = "exp_discord_auth_session";

type Accounts = {
	discord: { id: string, name: string },
	accounts: string[],
	max_accounts: number,
};

async function api(method: "GET" | "POST", route: string, session: string) {
	const response = await fetch(`${webRoot}api/exp_discord_auth/${route}`, {
		method,
		headers: { Authorization: `Bearer ${session}` },
	});
	const json = await response.json();
	if (!response.ok) {
		throw new Error(json.error ?? `Bad server response: ${response.status}`);
	}
	return json;
}

/** Take the outcome of the Discord redirect out of the url, so a reload does not reuse it. */
function readRedirect() {
	const params = new URLSearchParams(window.location.hash.slice(1));
	const session = params.get("exp_discord_auth_session");
	const error = params.get("exp_discord_auth_error");
	if (session || error) {
		window.history.replaceState(null, "", window.location.pathname + window.location.search);
	}
	if (session) {
		sessionStorage.setItem(sessionKey, session);
	}
	return { session: session ?? sessionStorage.getItem(sessionKey), error };
}

export default function DiscordLoginForm(props: { setToken(token: string): void }) {
	const [redirect] = useState(readRedirect);
	const [session, setSession] = useState<string | null>(redirect.session);
	const [error, setError] = useState<string | null>(redirect.error);
	const [accounts, setAccounts] = useState<Accounts | null>(null);
	const [code, setCode] = useState<string | null>(null);
	const [configured, setConfigured] = useState<boolean | null>(null);
	const linkedCount = useRef<number | null>(null);

	function forget(message: string | null) {
		sessionStorage.removeItem(sessionKey);
		setSession(null);
		setAccounts(null);
		setCode(null);
		linkedCount.current = null;
		setError(message);
	}

	useEffect(() => {
		if (session || configured !== null) {
			return;
		}
		fetch(`${webRoot}api/exp_discord_auth/status`)
			.then(response => response.json())
			.then(json => setConfigured(json.configured))
			.catch(err => setError(`Failed to load Discord login: ${err.message}`));
	}, [session, configured]);

	useEffect(() => {
		if (!session) {
			return undefined;
		}

		let cancelled = false;
		async function load() {
			try {
				const json = await api("GET", "accounts", session!) as Accounts;
				if (!cancelled) {
					// The code was used once a new account shows up
					if (linkedCount.current !== null && json.accounts.length > linkedCount.current) {
						setCode(null);
					}
					linkedCount.current = json.accounts.length;
					setAccounts(json);
				}
			} catch (err: any) {
				if (!cancelled) {
					forget(err.message);
				}
			}
		}

		load();
		// While a code is shown, poll until it is used in game
		const interval = code ? setInterval(load, 3e3) : undefined;
		return () => {
			cancelled = true;
			clearInterval(interval);
		};
	}, [session, code]);

	async function login(name: string) {
		try {
			const json = await api("POST", `login?name=${encodeURIComponent(name)}`, session!);
			sessionStorage.removeItem(sessionKey);
			props.setToken(json.token);
		} catch (err: any) {
			setError(err.message);
		}
	}

	async function getCode() {
		try {
			const json = await api("POST", "link_code", session!);
			setCode(json.code);
		} catch (err: any) {
			forget(err.message);
		}
	}

	const errorAlert = error && <Alert type="error" message={error} showIcon style={{ marginBottom: 16 }} />;

	if (!session) {
		if (configured === false) {
			return <Alert type="error" message="Discord login is not configured on this controller" showIcon />;
		}
		return <>
			{errorAlert}
			<Paragraph>Log in with a linked Discord account. New accounts can be linked after logging in.</Paragraph>
			<Button type="primary" block disabled={!configured} href={`${webRoot}api/exp_discord_auth/authorize`}>
				Log in with Discord
			</Button>
		</>;
	}

	if (!accounts) {
		return <Spin size="large" />;
	}

	const canLinkMore = accounts.accounts.length < accounts.max_accounts;
	return <>
		{errorAlert}
		<Paragraph>
			Logged in to Discord as <Text strong>{accounts.discord.name}</Text>. <Link onClick={() => forget(null)}>Not you?</Link>
		</Paragraph>

		{accounts.accounts.length
			? <Space direction="vertical" style={{ width: "100%", marginBottom: 16 }}>
				{accounts.accounts.map(name => <Button
					key={name}
					type="primary"
					block
					onClick={() => { login(name); }}
				>Log in as {name}</Button>)}
			</Space>
			: <Paragraph>No Factorio accounts are linked to this Discord account yet.</Paragraph>}

		{code
			? <Alert
				type="info"
				style={{ marginBottom: 16 }}
				message="Link your Factorio account"
				description={<>
					Join any of our servers and type this in the chat:
					<Paragraph copyable={{ text: `/link-discord ${code}` }} style={{ margin: "8px 0" }}>
						<Text code style={{ fontSize: 18 }}>/link-discord {code}</Text>
					</Paragraph>
					The code is valid for 10 minutes. This page continues once it has been used.
				</>}
			/>
			: canLinkMore && <Paragraph>
				<Button block onClick={() => { getCode(); }}>
					{accounts.accounts.length ? "Link another Factorio account" : "Link a Factorio account"}
				</Button>
			</Paragraph>}
	</>;
}
