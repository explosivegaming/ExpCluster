import React, { useContext, useEffect, useMemo, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { Button, Checkbox, Input, Space, Spin, Alert } from "antd";

import { ControlContext, useAccount, useDefaultModPack, PageLayout, PageHeader, notifyErrorHandler } from "@clusterio/web_ui";
import DeletedConfirm from "./DeleteConfirm";

import * as messages from "../../messages";
import type { WebPlugin } from "..";

const DOMAIN_MAPPING = {
	"Admin": ["admin", "cheat", "permission", "infinity", "editor", "spawn"],
	"Building & Crafting": ["mining", "build", "craft", "deconstruct", "rotate", "entity"],
	"Inventory": ["inventory", "stack", "cursor", "slot", "quick_bar", "item", "equipment"],
	"Blueprints": ["blueprint", "copy", "paste", "undo", "redo", "upgrade"],
	"Trains": ["train", "station", "schedule", "interrupt", "rolling_stock"],
	"Circuit Network": ["combinator", "circuit", "signal", "wire", "cable", "speaker", "display_panel"],
	"GUI": ["gui", "open"],
	"Pins & Alerts": ["pin", "alert", "tag"],
	"Logistics": ["logistic", "filter", "request"],
	"Space": ["space", "surface", "planet", "rocket"],
	"Toggles": ["toggle", "switch", "swap", "set"],
};

function getDomain(name: string) {
	const n = name.toLowerCase();

	for (const [domain, keywords] of Object.entries(DOMAIN_MAPPING)) {
		if (keywords.some(k => n.includes(k))) return domain;
	}

	return "Other";
}

export default function GroupViewPage() {
	const control = useContext(ControlContext);
	const plugin = control.plugins.get("exp_groups") as WebPlugin;
	const navigate = useNavigate();
	const account = useAccount();

	const { id } = useParams();
	const groupId = Number(id);

	const [groups, synced] = plugin.useGroups();
	const group = groups.get(groupId);

	const [name, setName] = useState("");

	const defaultModPack = useDefaultModPack();
	const [definesJson, setDefinesJson] = useState<Record<string, number> | null>(null);

	const [permissionState, setPermissionState] = useState<Record<string, boolean>>({});
	const [baselineState, setBaselineState] = useState<Record<string, boolean>>({});
	const [search, setSearch] = useState("");

	const canUpdate = Boolean(account.hasPermission("exp_groups.group.update"));
	const canDelete = Boolean(account.hasPermission("exp_groups.group.delete"));

	// fetch defines
	useEffect(() => {
		if (!defaultModPack?.exportManifest?.assets?.defines) return;
		if (definesJson) return;

		const assetName = defaultModPack.exportManifest.assets.defines;
		
		(async () => {
			const response = await fetch(`${staticRoot}static/${assetName}`);
			const json = await response.json();
			setDefinesJson(json.input_action ?? {});
		})().catch(notifyErrorHandler("Failed to load permissions"));
	}, [defaultModPack]);

	// initialise permissions
	useEffect(() => {
		if (!group || !definesJson) return;
		if (Object.keys(permissionState).length) return;

		const { isBlacklist, permissions } = group.permissions;

		const base = Object.fromEntries(
			Object.keys(definesJson).map(p => [
				p, isBlacklist !== permissions.includes(p)
			])
		);

		setPermissionState(base);
		setBaselineState(base);
	}, [group, definesJson]);

	// sync name
	useEffect(() => {
		if (group) setName(group.name);
	}, [group]);

	// derived data
	const allPermissions = useMemo(() => (
		Object.keys(definesJson ?? {})
	), [definesJson]);

	const filtered = useMemo(() => allPermissions.filter(p =>
		p.toLowerCase().includes(search.toLowerCase())
	), [allPermissions, search]);

	const grouped = useMemo(() => {
		const map = new Map<string, string[]>();

		for (const p of filtered) {
			const domain = getDomain(p);
			if (!map.has(domain)) map.set(domain, []);
			map.get(domain)!.push(p);
		}

		const sorted = [...map.entries()].sort(([a], [b]) => a.localeCompare(b));

		for (const [, perms] of sorted) {
			perms.sort((a, b) => a.localeCompare(b));
		}

		return sorted;
	}, [filtered]);

	const permissionChanged = Object.keys(permissionState).some(
		k => permissionState[k] !== baselineState[k]
	);
	const metaChanged = group ? name !== group.name : false;
	const edited = permissionChanged || metaChanged;

	function applyChanges() {
		if (!group) return;

		const whitelist: string[] = [];
		const blacklist: string[] = [];

		for (const [perm, enabled] of Object.entries(permissionState)) {
			if (enabled) whitelist.push(perm);
			else blacklist.push(perm);
		}

		const isBlacklist = blacklist.length < whitelist.length;
		const permissions = isBlacklist ? blacklist : whitelist;

		control.send(new messages.GroupUpdateRequest(
			new messages.GroupRecord(group.id, name, new messages.GroupPermissions(isBlacklist, permissions))
		))
		.then(() => setBaselineState(permissionState))
		.catch(notifyErrorHandler("Error applying changes"));
	}

	function revertChanges() {
		if (!group) return;
		setPermissionState(baselineState);
		setName(group.name);
	}

	if (!synced) {
		return <PageLayout nav={[{ name: "exp_groups" }, { name: String(groupId) }]}>
			<Spin />
		</PageLayout>;
	}

	if (!group) {
		return <PageLayout nav={[{ name: "exp_groups" }, { name: String(groupId) }]}>
			<PageHeader title="Group not found" />
		</PageLayout>;
	}

	return <PageLayout nav={[{ name: "Permission Groups", path: "/permission_groups" }, { name: group.name }]}>
		<PageHeader
			title={group.name}
			extra={<Space wrap>
				{canDelete && <DeletedConfirm placement="bottomRight" onConfirm={async () => {
					control.send(new messages.GroupDeleteRequest(group.id));
					navigate(`/permission_groups`);
				}}/>}
			</Space>}
		/>

		{edited && (
			<div style={{
				position: "fixed",
				bottom: 24,
				left: "50%",
				transform: "translateX(-50%)",
				background: "#2a1912",
				borderRadius: 8,
				padding: "10px 14px",
				display: "flex",
				gap: 12,
				zIndex: 1000,
			}}>
				<span>You have unsaved changes</span>
				<Space>
					<Button onClick={revertChanges}>Revert</Button>
					<Button type="primary" onClick={applyChanges}>Apply</Button>
				</Space>
			</div>
		)}

		<div style={{ marginBottom: 16, display: "flex", gap: 12 }}>
			<label style={{ width: 110 }}>Name</label>
			<Input value={name} disabled={!canUpdate} onChange={e => setName(e.target.value)} />
		</div>

		<h3>Permissions</h3>

		{!defaultModPack?.exportManifest?.assets?.defines && (
			<Alert
				type="warning"
				message="Missing export"
				description="An export of the default mod pack is required to modify permissions."
				style={{ marginBottom: 16 }}
				showIcon
			/>
		)}

		{defaultModPack?.exportManifest?.assets?.defines && !definesJson && <Spin />}

		{definesJson && <>
			<Input.Search
				placeholder="Search permissions"
				allowClear
				onChange={e => setSearch(e.target.value)}
				style={{ marginBottom: 16 }}
			/>

			<Space direction="vertical" style={{ width: "100%" }}>
				{grouped.map(([groupName, permissions]) => (
					<div key={groupName} style={{ border: "1px solid #424242", padding: 12, borderRadius: 6 }}>
						
						<Space style={{ width: "100%", justifyContent: "space-between" }}>
							<strong>{groupName}</strong>
							<Space>
								<Button
									size="small"
									disabled={!canUpdate}
									onClick={() => {
										setPermissionState(prev => {
											const next = { ...prev };
											for (const p of permissions) next[p] = true;
											return next;
										});
									}}
								>
									Select all
								</Button>

								<Button
									size="small"
									disabled={!canUpdate}
									onClick={() => {
										setPermissionState(prev => {
											const next = { ...prev };
											for (const p of permissions) next[p] = false;
											return next;
										});
									}}
								>
									Clear
								</Button>
							</Space>
						</Space>

						<div style={{
							marginTop: 12,
							display: "grid",
							gridTemplateColumns: "repeat(auto-fill, minmax(250px, 1fr))",
							gap: 8,
						}}>
							{permissions.map(p => (
								<Checkbox
									key={p}
									checked={permissionState[p]}
									disabled={!canUpdate}
									onChange={e =>
										setPermissionState(prev => ({ ...prev, [p]: e.target.checked }))
									}
								>
									{p}
								</Checkbox>
							))}
						</div>
					</div>
				))}
			</Space>
		</>}
	</PageLayout>;
}
