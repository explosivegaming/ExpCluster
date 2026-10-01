import React, { useContext, useState } from "react";
import { Button, Checkbox, Col, ConfigProvider, Divider, Input, InputNumber, Row, Select, Space, Switch } from "antd";

import * as lib from "@clusterio/lib";
import { ControlContext, PageHeader, PageLayout, notifyErrorHandler, useAccount } from "@clusterio/web_ui";

import { Feature, FeatureField, FeatureValue, features, isDefaultValue } from "../../features.js";
import { FeatureRecord, FeatureUpdateRequest } from "../../messages.js";
import { useFeatures } from "../index";

type FeatureState = { enabled: boolean, values: Record<string, FeatureValue> };
type PendingChanges = Record<string, { enabled?: boolean, values: Record<string, FeatureValue> }>;

// Same colours as the role and permission group pages
const borderColor = "#424242";
const modifiedColor = "#2a1912";

function sameValue(a: FeatureValue | undefined, b: FeatureValue | undefined) {
	if (Array.isArray(a) && Array.isArray(b)) {
		return a.length === b.length && a.every((item, index) => item === b[index]);
	}
	return a === b;
}

/** The stored state of a feature, with defaults for values which were not set. */
function storedState(feature: Feature, record: FeatureRecord | undefined): FeatureState {
	return {
		enabled: record?.enabled ?? true,
		values: {
			...Object.fromEntries(feature.fields.map(field => [field.name, field.default])),
			...record?.values,
		},
	};
}

/** Group fields by the section in their name, "turrets.enabled" is in the "turrets" section. */
function groupFields(fields: FeatureField[]) {
	const groups = new Map<string, FeatureField[]>();
	for (const field of fields) {
		const section = field.name.includes(".") ? field.name.slice(0, field.name.lastIndexOf(".")) : "";
		if (!groups.has(section)) {
			groups.set(section, []);
		}
		groups.get(section)!.push(field);
	}
	return [...groups.entries()];
}

/** Converts a section name into Title Case, same as the group titles on the role page */
function formatSectionTitle(name: string) {
	return name
		.replace(/\./g, " / ")
		.replace(/_/g, " ")
		.split(" ")
		.filter(Boolean)
		.map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
		.join(" ");
}

function matches(text: string, query: string) {
	return text.toLowerCase().includes(query);
}

/** The fields of a feature which match the search, every field if the feature itself matches. */
function searchFields(feature: Feature, query: string) {
	if (!query || matches(feature.title, query) || matches(feature.description, query) || matches(feature.name, query)) {
		return feature.fields;
	}
	return feature.fields.filter(field => (
		matches(field.title, query) || matches(field.description, query) || matches(field.name, query)
	));
}

/**
 * Render the input for a setting the same way the config pages do, input components registered
 * with the web interface take priority so plugins can provide inputs for other types
 */
function FieldInput(props: { field: FeatureField, value: FeatureValue, disabled: boolean, onChange: (value: FeatureValue) => void }) {
	const { field, value, disabled, onChange } = props;
	const control = useContext(ControlContext);
	const CustomInput = field.inputComponent ? control.inputComponents.get(field.inputComponent) : undefined;
	if (CustomInput) {
		const fieldDefinition = {
			type: field.type === "string_list" ? "object" : field.type,
			title: field.title,
			description: field.description,
			optional: field.optional,
			inputComponent: field.inputComponent,
		} as lib.FieldDefinition;
		return <CustomInput
			fieldDefinition={fieldDefinition}
			value={value as Exclude<FeatureValue, string[]>}
			onChange={onChange}
			disabled={disabled}
		/>;
	}

	switch (field.type) {
		case "number":
			return <InputNumber
				value={value as number}
				min={field.min}
				addonAfter={field.unit}
				disabled={disabled}
				onChange={next => onChange(next ?? (field.optional ? null : field.default))}
			/>;
		case "string":
			if (field.enum) {
				return <Select
					showSearch
					style={{ minWidth: 175 }}
					value={value as string}
					options={field.enum.map(option => ({ label: option, value: option }))}
					allowClear={field.optional}
					disabled={disabled}
					onChange={next => onChange(next ?? null)}
				/>;
			}
			return <Input value={value as string} disabled={disabled} onChange={e => onChange(e.target.value)} style={{ width: 300 }} />;
		case "string_list":
			return <Select
				mode="tags"
				value={value as string[]}
				disabled={disabled}
				onChange={next => onChange(next)}
				open={false}
				style={{ width: "100%", maxWidth: 600 }}
			/>;
		default:
			return null;
	}
}

/** A single setting, laid out like a permission on the role page. */
function FieldItem(props: {
	field: FeatureField, value: FeatureValue, stored: FeatureValue, disabled: boolean, onChange: (value: FeatureValue) => void,
}) {
	const { field, value, stored, disabled, onChange } = props;
	const modified = !sameValue(value, stored);
	return <div style={{
		marginBottom: 8,
		padding: "4px 6px",
		background: modified ? modifiedColor : undefined,
		borderRadius: 4,
	}}>
		{field.type === "boolean"
			? <Checkbox checked={value as boolean} disabled={disabled} onChange={e => onChange(e.target.checked)}>
				{field.title}
			</Checkbox>
			: <Space wrap>
				<span>{field.title}</span>
				<FieldInput field={field} value={value} disabled={disabled} onChange={onChange} />
			</Space>}
		<div style={{ marginLeft: field.type === "boolean" ? 24 : 0, color: "#888", fontSize: 12 }}>
			{field.description}
		</div>
	</div>;
}

function FeatureSection(props: {
	feature: Feature,
	fields: FeatureField[],
	state: FeatureState,
	stored: FeatureState,
	canEdit: boolean,
	onEnabled: (enabled: boolean) => void,
	onValue: (name: string, value: FeatureValue) => void,
	onReset: () => void,
}) {
	const { feature, fields, state, stored, canEdit } = props;
	const atDefaults = feature.fields.every(field => isDefaultValue(field, state.values[field.name]));
	return <div id={`feature-${feature.name}`} style={{ border: `1px solid ${borderColor}`, padding: 12, borderRadius: 6, scrollMarginTop: 80 }}>
		<div style={{ display: "flex", alignItems: "center", gap: 12 }}>
			<div style={{
				padding: "4px 6px",
				borderRadius: 4,
				background: state.enabled !== stored.enabled ? modifiedColor : undefined,
			}}>
				<Switch size="default" checked={state.enabled} disabled={!canEdit} onChange={props.onEnabled} />
			</div>
			<div style={{ flexGrow: 1 }}>
				<strong>{feature.title}</strong>
				<div style={{ color: "#888", fontSize: 12 }}>{feature.description}</div>
			</div>
			{canEdit && feature.fields.length > 0 && <Button size="small" disabled={atDefaults} onClick={props.onReset}>
				Reset to defaults
			</Button>}
		</div>
		{fields.length > 0 && <>
			<Divider style={{ margin: "12px 0" }} />
			<div style={{ opacity: state.enabled ? 1 : 0.6 }}>
				{groupFields(fields).map(([section, sectionFields]) => <div key={section}>
					{section && <div style={{ fontWeight: 600, margin: "8px 6px 4px" }}>{formatSectionTitle(section)}</div>}
					{sectionFields.map(field => <FieldItem
						key={field.name}
						field={field}
						value={state.values[field.name]}
						stored={stored.values[field.name]}
						disabled={!canEdit}
						onChange={value => props.onValue(field.name, value)}
					/>)}
				</div>)}
			</div>
		</>}
	</div>;
}

function FeatureNav(props: { feature: Feature, enabled: boolean }) {
	return <div
		role="button"
		onClick={() => document.getElementById(`feature-${props.feature.name}`)?.scrollIntoView({ behavior: "smooth" })}
		style={{ display: "flex", alignItems: "center", gap: 8, padding: "4px 8px", cursor: "pointer", borderRadius: 4 }}
	>
		<span style={{
			width: 8,
			height: 8,
			borderRadius: "50%",
			flexShrink: 0,
			background: props.enabled ? "#52c41a" : "#595959",
		}} />
		{props.feature.title}
	</div>;
}

/** Enable, disable, and configure the scenario features listed in features.ts. */
export default function FeaturesPage() {
	const control = useContext(ControlContext);
	const account = useAccount();
	const [records] = useFeatures();
	const [pending, setPending] = useState<PendingChanges>({});
	const [search, setSearch] = useState("");
	const canEdit = Boolean(account.hasPermission("exp_scenario.config.edit"));

	const stored = Object.fromEntries(features.map(feature => [feature.name, storedState(feature, records.get(feature.name))]));
	const current = (name: string): FeatureState => ({
		enabled: pending[name]?.enabled ?? stored[name].enabled,
		values: { ...stored[name].values, ...pending[name]?.values },
	});

	/** Record a change, dropping it again if it matches what is stored */
	function change(name: string, update: (entry: PendingChanges[string]) => void) {
		setPending(prev => {
			const entry = { enabled: prev[name]?.enabled, values: { ...prev[name]?.values } };
			update(entry);
			if (entry.enabled === stored[name].enabled) {
				delete entry.enabled;
			}
			for (const [key, value] of Object.entries(entry.values)) {
				if (sameValue(value, stored[name].values[key])) {
					delete entry.values[key];
				}
			}
			const next = { ...prev };
			if (entry.enabled === undefined && !Object.keys(entry.values).length) {
				delete next[name];
			} else {
				next[name] = entry;
			}
			return next;
		});
	}

	function applyChanges() {
		for (const name of Object.keys(pending)) {
			const state = current(name);
			control.send(new FeatureUpdateRequest(name, state.enabled, state.values))
				.then(() => setPending(prev => {
					const next = { ...prev };
					delete next[name];
					return next;
				}))
				.catch(notifyErrorHandler(`Error saving ${features.find(f => f.name === name)?.title ?? name}`));
		}
	}

	const query = search.trim().toLowerCase();
	const shown = features
		.map(feature => ({ feature, fields: searchFields(feature, query) }))
		.filter(({ feature, fields }) => !query || fields.length || matches(feature.title, query));

	return <PageLayout nav={[{ name: "Scenario Features" }]}>
		<PageHeader title="Scenario Features" />

		{Object.keys(pending).length > 0 && <div style={{
			position: "fixed",
			bottom: 24,
			left: "50%",
			transform: "translateX(-50%)",
			background: modifiedColor,
			borderRadius: 8,
			boxShadow: "0 8px 24px rgba(0,0,0,0.12)",
			padding: "10px 14px",
			display: "flex",
			alignItems: "center",
			gap: 12,
			zIndex: 1000,
		}}>
			<span style={{ color: "#FFF" }}>You have unsaved changes</span>
			<Space>
				<Button onClick={() => setPending({})}>Revert</Button>
				<Button type="primary" onClick={applyChanges}>Apply</Button>
			</Space>
		</div>}

		<Input.Search placeholder="Search features and settings" allowClear
			onChange={e => setSearch(e.target.value)} style={{ marginBottom: 16 }} />

		<Row gutter={16} wrap={false}>
			<Col flex="200px">
				{/* Clear of the fixed page header */}
				<div style={{ position: "sticky", top: 80 }}>
					{shown.map(({ feature }) => <FeatureNav
						key={feature.name}
						feature={feature}
						enabled={current(feature.name).enabled}
					/>)}
				</div>
			</Col>
			<Col flex="auto" style={{ minWidth: 0 }}>
				{/* Small inputs match the line height of the text, same as the config pages */}
				<ConfigProvider componentSize="small">
					<Space direction="vertical" style={{ width: "100%" }}>
						{shown.map(({ feature, fields }) => <FeatureSection
							key={feature.name}
							feature={feature}
							fields={fields}
							state={current(feature.name)}
							stored={stored[feature.name]}
							canEdit={canEdit}
							onEnabled={enabled => change(feature.name, entry => { entry.enabled = enabled; })}
							onValue={(key, value) => change(feature.name, entry => { entry.values[key] = value; })}
							onReset={() => change(feature.name, entry => {
								for (const field of feature.fields) {
									entry.values[field.name] = field.default;
								}
							})}
						/>)}
					</Space>
				</ConfigProvider>
			</Col>
		</Row>
	</PageLayout>;
}
