import React, { useContext, useEffect, useState } from "react";
import { Alert, Button, Descriptions, Popconfirm } from "antd";

import {
	ControlContext, PluginExtensionProps, SectionHeader, notifyErrorHandler, useAccount,
} from "@clusterio/web_ui";

import { DiscordLinkGetRequest, DiscordLinkStartRequest, DiscordUnlinkRequest } from "../../messages.js";

declare const webRoot: string;

type Link = { id: string, name: string } | null;

/** An error from linking on Discord, taken out of the url so a reload does not show it again. */
function readError() {
	const error = new URLSearchParams(window.location.hash.slice(1)).get("exp_discord_error");
	if (error) {
		window.history.replaceState(null, "", window.location.pathname + window.location.search);
	}
	return error;
}

/** The Discord account a user is linked to, shown on their user page. */
export default function UserDiscordLink(props: PluginExtensionProps<"UserViewPage">) {
	const control = useContext(ControlContext);
	const account = useAccount();
	const own = account.name.toLowerCase() === props.user.name.toLowerCase();
	const canGet = own || account.hasPermission("exp_discord.link.get");
	const canDelete = own || account.hasPermission("exp_discord.link.delete");
	const [link, setLink] = useState<Link | undefined>(undefined);
	const [error, setError] = useState(readError);

	useEffect(() => {
		if (!canGet) {
			return;
		}
		control.send(new DiscordLinkGetRequest(props.user.name))
			.then(setLink)
			.catch(notifyErrorHandler("Error loading Discord link"));
	}, [props.user.name, canGet]);

	if (!canGet || link === undefined) {
		return null;
	}

	async function unlink() {
		await control.send(new DiscordUnlinkRequest(props.user.name));
		setLink(null);
	}

	async function startLink() {
		const ticket = await control.send(new DiscordLinkStartRequest(props.user.name));
		window.location.href = `${webRoot}api/exp_discord/authorize?link=${encodeURIComponent(ticket)}`;
	}

	return <>
		<SectionHeader title="Discord" />
		{error && <Alert
			type="error"
			message={error}
			showIcon
			closable
			onClose={() => setError(null)}
			style={{ marginBottom: 16 }}
		/>}
		<Descriptions bordered size="small" column={1}>
			<Descriptions.Item label="Linked account">
				{link ? <>
					{link.name}
					{canDelete && <Popconfirm
						title={`Unlink ${props.user.name} from ${link.name}?`}
						onConfirm={() => { unlink().catch(notifyErrorHandler("Error unlinking Discord")); }}
					>
						<Button danger size="small" style={{ marginLeft: 8 }}>Unlink</Button>
					</Popconfirm>}
				</> : <>
					Not linked
					{own && <Button
						size="small"
						style={{ marginLeft: 8 }}
						onClick={() => { startLink().catch(notifyErrorHandler("Error linking Discord")); }}
					>Link Discord</Button>}
				</>}
			</Descriptions.Item>
		</Descriptions>
	</>;
}
