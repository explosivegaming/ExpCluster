import React, { useContext, useEffect, useState } from "react";
import { Button, Descriptions, Popconfirm } from "antd";

import {
	ControlContext, PluginExtensionProps, SectionHeader, notifyErrorHandler, useAccount,
} from "@clusterio/web_ui";

import { DiscordLinkGetRequest, DiscordUnlinkRequest } from "../../messages.js";

type Link = { id: string, name: string } | null;

/** The Discord account a user is linked to, shown on their user page. */
export default function UserDiscordLink(props: PluginExtensionProps<"UserViewPage">) {
	const control = useContext(ControlContext);
	const account = useAccount();
	const own = account.name.toLowerCase() === props.user.name.toLowerCase();
	const canGet = own || account.hasPermission("exp_discord.link.get");
	const canDelete = own || account.hasPermission("exp_discord.link.delete");
	const [link, setLink] = useState<Link | undefined>(undefined);

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

	return <>
		<SectionHeader title="Discord" />
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
				</> : "Not linked"}
			</Descriptions.Item>
		</Descriptions>
	</>;
}
