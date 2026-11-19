import React, { useContext, useEffect, useState } from "react";
import { Alert, Button, Select, Typography } from "antd";

import { ControlContext, PluginExtensionProps, SectionHeader, notifyErrorHandler, useAccount } from "@clusterio/web_ui";

import { GuildRoleListRequest, RoleMappingUpdateRequest } from "../../messages.js";
import { useRoleMappings } from "..";

type GuildRole = { id: string, name: string, color: number };

function roleColor(color: number) {
	return color ? `#${color.toString(16).padStart(6, "0")}` : undefined;
}

/** The Discord roles given to linked players holding this role. */
export default function RoleDiscordRoles(props: PluginExtensionProps<"RoleViewPageBeforePermissions">) {
	const control = useContext(ControlContext);
	const account = useAccount();
	const [mappings, synced] = useRoleMappings();
	const [guildRoles, setGuildRoles] = useState<GuildRole[]>([]);
	const [guildError, setGuildError] = useState<string>();
	const [selected, setSelected] = useState<string[]>();
	const [applying, setApplying] = useState(false);

	const canUpdate = account.hasPermission("exp_discord_sync.mapping.update");
	const saved = (props.role ? mappings.get(props.role.id)?.discordRoleIds : undefined) ?? [];
	const value = selected ?? saved;
	const changed = selected !== undefined && selected.join() !== saved.join();

	useEffect(() => {
		control.send(new GuildRoleListRequest())
			.then(roles => { setGuildRoles(roles); setGuildError(undefined); })
			.catch(err => setGuildError(err.message));
	}, []);

	useEffect(() => setSelected(undefined), [props.role?.id, saved.join()]);

	if (!props.role || !synced) {
		return null;
	}

	async function apply() {
		await control.send(new RoleMappingUpdateRequest(props.role!.id, value));
		setSelected(undefined);
	}

	const options = guildRoles.map(role => ({
		value: role.id,
		label: <span style={{ color: roleColor(role.color) }}>{role.name}</span>,
		search: role.name,
	}));

	return <>
		<SectionHeader
			title="Discord Roles"
			extra={canUpdate ? <Button
				type="primary"
				disabled={!changed}
				loading={applying}
				onClick={() => {
					setApplying(true);
					apply()
						.catch(notifyErrorHandler("Error updating Discord roles"))
						.finally(() => setApplying(false));
				}}
			>Apply Discord roles</Button> : undefined}
		/>
		{guildError && <Alert
			type="warning"
			showIcon
			message={`Could not list the Discord roles: ${guildError}`}
			description={canUpdate ? "Role IDs can still be typed in." : undefined}
			style={{ marginBottom: 8 }}
		/>}
		<Select
			mode="tags"
			style={{ width: "100%" }}
			placeholder={canUpdate ? "Select Discord roles or type a role ID" : "None"}
			disabled={!canUpdate}
			value={value}
			options={options}
			optionFilterProp="search"
			tokenSeparators={[",", " "]}
			onChange={setSelected}
		/>
		<Typography.Paragraph type="secondary" style={{ marginTop: 8 }}>
			Players linked to Discord get these roles while they hold this role.
		</Typography.Paragraph>
	</>;
}
