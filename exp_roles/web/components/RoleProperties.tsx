import React, { useContext, useEffect, useState } from "react";
import { Button, Col, ColorPicker, Form, Input, InputNumber, Row, Switch, Tooltip } from "antd";

import * as lib from "@clusterio/lib";
import { ControlContext, SectionHeader, useAccount, notifyErrorHandler } from "@clusterio/web_ui";

import { RoleColor, RoleMetaRecord, RoleMetaUpdateRequest } from "../../messages.js";
import type { WebPlugin } from "..";

const MS_PER_HOUR = 3600000;

type RoleFormValues = {
	order: number;
	priority: number;
	shortHand: string;
	tag: string;
	color: string | { toRgb(): { r: number, g: number, b: number } } | null;
	autoAssignHours: number | null;
	blockAutoAssign: boolean;
};

/**
 * In game properties of a role, shown at the end of the core role page.
 *
 * The name, description and permissions of a role are owned by clusterio, this
 * only covers the properties which only mean something in game.
 */
export default function RoleProperties(props: { plugin: WebPlugin, role?: lib.Role }) {
	const control = useContext(ControlContext);
	const account = useAccount();
	const [form] = Form.useForm<RoleFormValues>();
	const [applying, setApplying] = useState(false);

	const [roles] = props.plugin.useRoles();
	const record = props.role ? roles.get(props.role.id) : undefined;
	const meta = record?.meta;
	const canUpdate = account.hasPermission("core.role.update");

	useEffect(() => {
		if (!meta) {
			return;
		}
		form.setFieldsValue({
			order: meta.order,
			priority: meta.priority,
			shortHand: meta.shortHand,
			tag: meta.tag,
			color: meta.color ? `rgb(${meta.color.r}, ${meta.color.g}, ${meta.color.b})` : null,
			autoAssignHours: meta.autoAssignOnlineTimeMs === null
				? null
				: meta.autoAssignOnlineTimeMs / MS_PER_HOUR,
			blockAutoAssign: meta.blockAutoAssign,
		});
	}, [meta, form]);

	if (!props.role || !meta) {
		return null;
	}

	async function apply() {
		const values = form.getFieldsValue();

		let color: RoleColor | null = null;
		if (values.color && typeof values.color !== "string") {
			const rgb = values.color.toRgb();
			color = new RoleColor(Math.round(rgb.r), Math.round(rgb.g), Math.round(rgb.b));
		} else if (typeof values.color === "string") {
			const match = values.color.match(/(\d+)\D+(\d+)\D+(\d+)/);
			if (match) {
				color = new RoleColor(Number(match[1]), Number(match[2]), Number(match[3]));
			}
		}

		await control.send(new RoleMetaUpdateRequest(new RoleMetaRecord(
			props.role!.id,
			values.order,
			values.priority,
			values.shortHand ?? "",
			values.tag ?? "",
			color,
			values.autoAssignHours === null || values.autoAssignHours === undefined
				? null
				: values.autoAssignHours * MS_PER_HOUR,
			values.blockAutoAssign ?? false,
		)));
	}

	const labelled = (text: string, tip: string) => <Tooltip title={tip}>{text}</Tooltip>;

	return <>
		<SectionHeader
			title="In Game Properties"
			extra={canUpdate ? <Button
				type="primary"
				loading={applying}
				onClick={() => {
					setApplying(true);
					apply()
						.catch(notifyErrorHandler("Error updating role properties"))
						.finally(() => setApplying(false));
				}}
			>Apply in game properties</Button> : undefined}
		/>
		<Form
			form={form}
			disabled={!canUpdate}
			labelCol={{ span: 12 }}
			wrapperCol={{ span: 12 }}
			labelWrap
		>
			<Row gutter={[16, 0]}>
				<Col xs={24} sm={12} xl={6}>
					<Form.Item
						name="order"
						label={labelled("Order", "A lower value is a more privileged role")}
					>
						<InputNumber style={{ width: "100%" }} />
					</Form.Item>
				</Col>

				<Col xs={24} sm={12} xl={6}>
					<Form.Item
						name="priority"
						label={labelled(
							"Priority",
							"Only the roles with the highest priority a player holds apply, "
							+ "which is how Jail suppresses every other role"
						)}
					>
						<InputNumber style={{ width: "100%" }} />
					</Form.Item>
				</Col>

				<Col xs={24} sm={12} xl={6}>
					<Form.Item
						name="shortHand"
						label={labelled("Short hand", "Short form of the name, used where space is limited")}
					>
						<Input />
					</Form.Item>
				</Col>

				<Col xs={24} sm={12} xl={6}>
					<Form.Item
						name="tag"
						label={labelled("Tag", "Shown next to the names of players with this role")}
					>
						<Input />
					</Form.Item>
				</Col>

				<Col xs={24} sm={12} xl={6}>
					<Form.Item
						name="color"
						label={labelled("Colour", "Used for the role name and tag in game")}
					>
						<ColorPicker allowClear format="rgb" disabledAlpha />
					</Form.Item>
				</Col>

				<Col xs={24} sm={12} xl={6}>
					<Form.Item
						name="autoAssignHours"
						label={labelled(
							"Auto assign after (hours)",
							"Granted once a player reaches this much online time across the cluster. "
							+ "Leave empty to never grant it automatically"
						)}
					>
						<InputNumber min={0} placeholder="Never" style={{ width: "100%" }} />
					</Form.Item>
				</Col>

				<Col xs={24} sm={12} xl={6}>
					<Form.Item
						name="blockAutoAssign"
						label={labelled(
							"Block auto assign",
							"Players holding this role are never granted any other role automatically"
						)}
						valuePropName="checked"
					>
						<Switch />
					</Form.Item>
				</Col>
			</Row>
		</Form>
	</>;
}
