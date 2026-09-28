import React, { useContext, useState } from "react";
import { Button, Card, Col, Empty, Form, Input, InputNumber, Row, Space, Switch, Typography, theme } from "antd";

import { ControlContext, PageHeader, PageLayout, notifyErrorHandler, useAccount } from "@clusterio/web_ui";

import { Feature, FeatureField, FeatureValue, features } from "../../features.js";
import { FeatureRecord, FeatureUpdateRequest } from "../../messages.js";
import { useFeatures } from "../index";

function FeatureListItem(props: { feature: Feature, enabled: boolean, selected: boolean, onClick: () => void }) {
	const { token } = theme.useToken();
	return <div
		role="button"
		onClick={props.onClick}
		style={{
			display: "flex",
			alignItems: "center",
			gap: token.marginXS,
			padding: `${token.paddingXS}px ${token.paddingSM}px`,
			marginBottom: token.marginXS,
			cursor: "pointer",
			borderRadius: token.borderRadius,
			border: `1px solid ${props.enabled ? token.colorSuccessBorder : token.colorBorder}`,
			outline: props.selected ? `2px solid ${token.colorPrimary}` : undefined,
			background: props.enabled ? token.colorSuccessBg : undefined,
		}}
	>
		<span style={{
			width: 8,
			height: 8,
			borderRadius: "50%",
			flexShrink: 0,
			background: props.enabled ? token.colorSuccess : token.colorTextQuaternary,
		}} />
		{props.feature.title}
	</div>;
}

/** Returned as an element rather than a component so Form.Item can pass its value and onChange to it. */
function fieldInput(field: FeatureField, disabled: boolean) {
	switch (field.type) {
		case "boolean":
			return <Switch disabled={disabled} />;
		case "number":
			return <InputNumber disabled={disabled} min={field.min} addonAfter={field.unit} />;
		case "string":
			return <Input disabled={disabled} />;
	}
}

function defaultValues(feature: Feature) {
	return Object.fromEntries(feature.fields.map(field => [field.name, field.default]));
}

function FeatureForm(props: { feature: Feature, record: FeatureRecord | undefined }) {
	const { feature, record } = props;
	const control = useContext(ControlContext);
	const account = useAccount();
	const [form] = Form.useForm();
	const [dirty, setDirty] = useState(false);
	const [saving, setSaving] = useState(false);
	const canEdit = account.hasPermission("exp_scenario.config.edit");

	const initialValues = {
		enabled: record?.enabled ?? true,
		...defaultValues(feature),
		...record?.values,
	};

	function save() {
		const { enabled, ...values } = form.getFieldsValue() as { enabled: boolean } & Record<string, FeatureValue>;
		setSaving(true);
		control.send(new FeatureUpdateRequest(feature.name, enabled, values))
			.then(() => setDirty(false))
			.catch(notifyErrorHandler(`Error saving ${feature.title}`))
			.finally(() => setSaving(false));
	}

	return <Card
		title={<>
			{feature.title}
			<Typography.Paragraph type="secondary" style={{ fontWeight: "normal", margin: 0 }}>
				{feature.description}
			</Typography.Paragraph>
		</>}
	>
		<Form
			form={form}
			layout="vertical"
			initialValues={initialValues}
			onValuesChange={() => setDirty(true)}
			onFinish={save}
		>
			<Form.Item name="enabled" label="Enabled" valuePropName="checked">
				<Switch disabled={!canEdit} />
			</Form.Item>
			{feature.fields.map(field => <Form.Item
				key={field.name}
				name={field.name}
				label={field.title}
				extra={field.description}
				valuePropName={field.type === "boolean" ? "checked" : "value"}
				rules={field.type === "boolean" ? [] : [{ required: true, message: `${field.title} is required` }]}
			>
				{fieldInput(field, !canEdit)}
			</Form.Item>)}
			{canEdit && <Space>
				<Button type="primary" htmlType="submit" loading={saving} disabled={!dirty}>Save</Button>
				<Button onClick={() => {
					form.setFieldsValue(defaultValues(feature));
					setDirty(true);
				}}>Reset to defaults</Button>
			</Space>}
		</Form>
	</Card>;
}

/** Enable, disable, and configure the scenario features listed in features.ts. */
export default function FeaturesPage() {
	const [records] = useFeatures();
	const [selected, setSelected] = useState(features[0]?.name);
	const feature = features.find(f => f.name === selected);
	const record = selected ? records.get(selected) : undefined;

	return <PageLayout nav={[{ name: "Scenario Features" }]}>
		<PageHeader title="Scenario Features" />
		<Row gutter={[16, 16]}>
			<Col xs={24} md={8} lg={6}>
				<Card title="Features">
					{features.map(f => <FeatureListItem
						key={f.name}
						feature={f}
						enabled={records.get(f.name)?.enabled ?? true}
						selected={f.name === selected}
						onClick={() => setSelected(f.name)}
					/>)}
				</Card>
			</Col>
			<Col xs={24} md={16} lg={18}>
				{feature
					// Remount on save from anywhere so the form shows the stored values
					? <FeatureForm key={`${feature.name}:${record?.updatedAtMs ?? 0}`} feature={feature} record={record} />
					: <Card><Empty /></Card>}
			</Col>
		</Row>
	</PageLayout>;
}
