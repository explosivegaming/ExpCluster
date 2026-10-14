import React, { useContext, useEffect, useState } from "react";
import { Button, Descriptions, Input, Space } from "antd";

import { ControlContext, PluginExtensionProps, SectionHeader, notifyErrorHandler, useAccount } from "@clusterio/web_ui";

import { JoinMessageSetRequest, PlayerGetRequest, PlayerRecord, joinMessageMaxLength } from "../../messages.js";

/** The settings the scenario keeps for a player, shown on their user page. */
export default function UserPlayerSettings(props: PluginExtensionProps<"UserViewPage">) {
	const control = useContext(ControlContext);
	const account = useAccount();
	const name = props.user.name;
	const own = account.name.toLowerCase() === name.toLowerCase();
	const canGet = own || Boolean(account.hasPermission("core.user.get"));
	const canEdit = Boolean(account.hasPermission(
		own ? "exp_scenario.join_message.set" : "exp_scenario.join_message.set_other",
	));
	const [record, setRecord] = useState<PlayerRecord>();
	/** The message being typed, undefined while not editing */
	const [draft, setDraft] = useState<string>();

	function load() {
		control.send(new PlayerGetRequest(name))
			.then(setRecord)
			.catch(notifyErrorHandler("Error loading player settings"));
	}

	useEffect(() => {
		if (canGet) {
			load();
		}
	}, [name, canGet]);

	if (!canGet || !record) {
		return null;
	}

	async function save(message: string) {
		await control.send(new JoinMessageSetRequest(name, message.trim() || null));
		setDraft(undefined);
		load();
	}

	function onSave() {
		save(draft ?? "").catch(notifyErrorHandler("Error saving join message"));
	}

	return <>
		<SectionHeader title="Scenario" />
		<Descriptions bordered size="small" column={1}>
			<Descriptions.Item label="Join message">
				{draft !== undefined
					? <Space.Compact style={{ width: "100%", maxWidth: 600 }}>
						<Input
							value={draft}
							maxLength={joinMessageMaxLength}
							placeholder="Shown to everyone when they join, empty for none"
							onChange={e => setDraft(e.target.value)}
							onPressEnter={onSave}
						/>
						<Button type="primary" onClick={onSave}>Save</Button>
						<Button onClick={() => setDraft(undefined)}>Cancel</Button>
					</Space.Compact>
					: <>
						{record.joinMessage ?? <span style={{ color: "#888" }}>None</span>}
						{canEdit && <Button
							size="small"
							style={{ marginLeft: 8 }}
							onClick={() => setDraft(record.joinMessage ?? "")}
						>Edit</Button>}
					</>}
			</Descriptions.Item>
		</Descriptions>
	</>;
}
