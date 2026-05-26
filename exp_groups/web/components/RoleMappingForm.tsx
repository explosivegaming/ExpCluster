import React, { useContext, useEffect } from "react";
import { Modal, Form, Select, InputNumber, Switch, Alert } from "antd";

import { ControlContext, useRoles } from "@clusterio/web_ui";
import { RoleMappingRecord, RoleMappingCreateRequest, RoleMappingUpdateRequest } from "../../messages";
import type { WebPlugin } from "..";

export default function RoleMappingForm({ open, setOpen, initial }: {
	open: boolean,
	setOpen: (open: boolean) => void,
	initial?: RoleMappingRecord,
}) {
	const control = useContext(ControlContext);
	const plugin = control.plugins.get("exp_groups") as WebPlugin;

	const [groups] = plugin.useGroups();
	const [roles] = useRoles();

	const [form] = Form.useForm();

	function submit(values: any) {
		if (initial) {
			control.send(new RoleMappingUpdateRequest(
				new RoleMappingRecord(
					initial.id,
					new Set(values.roleIds),
					values.groupId,
					values.priority,
					values.enabled,
				)
			));
		} else {
			control.send(new RoleMappingCreateRequest(
				values.roleIds,
				values.groupId,
				values.priority,
				values.enabled,
			));
		}

		setOpen(false);
	}

	useEffect(() => {
		if (open) {
			form.resetFields();
			form.setFieldsValue({
				...initial,
				roleIds: initial ? [...initial.roleIds] : [],
			});
		}
	}, [open, initial]);

	return <Modal
		title={initial ? "Edit Role Mapping" : "Create Role Mapping"}
		open={open}
		onCancel={() => setOpen(false)}
		onOk={() => form.submit()}
	>
		<Alert
			type="info"
			showIcon
			message="How role mappings work"
			style={{ marginBottom: 16 }}
			description={
				<ul style={{ paddingLeft: 16, margin: 0 }}>
					<li>Manual assignments always take priority.</li>
					<li>Mappings are checked in priority order (highest first).</li>
					<li>A mapping applies only if the user has <b>all listed roles</b>.</li>
					<li>The first matching mapping assigns the group.</li>
					<li>If none match, the player is given all permissions.</li>
				</ul>
			}
		/>

		<Form form={form} onFinish={submit}>
			<Form.Item name="groupId" label="Group" rules={[{ required: true }]}>
				<Select>
					{[...groups.values()].map(g => (
						<Select.Option key={g.id} value={g.id}>
							{g.name}
						</Select.Option>
					))}
				</Select>
			</Form.Item>

			<Form.Item name="roleIds" label="Roles" rules={[{ required: true }]}>
				<Select mode="multiple">
					{[...roles.values()].map(r => (
						<Select.Option key={r.id} value={r.id}>
							{r.name}
						</Select.Option>
					))}
				</Select>
			</Form.Item>

			<Form.Item name="priority" label="Priority" initialValue={100}>
				<InputNumber style={{ width: "100%" }} />
			</Form.Item>

			<Form.Item name="enabled" label="Enabled" valuePropName="checked" initialValue={true}>
				<Switch />
			</Form.Item>
		</Form>
	</Modal>;
}
