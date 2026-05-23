import React, { useContext } from "react";
import { Modal, Form, Select, InputNumber, Switch } from "antd";

import { ControlContext, useRoles } from "@clusterio/web_ui";
import * as messages from "../../messages";

export default function RoleMappingForm({ open, setOpen, initial }: any) {
	const control = useContext(ControlContext);
	const plugin = control.plugins.get("exp_groups") as any;

	const [groups] = plugin.useGroups();
	const [roles] = useRoles();

	const [form] = Form.useForm();

	function submit(values: any) {
		const record = new messages.RoleMappingRecord(
			initial?.id,
			new Set(values.roleIds),
			values.groupId,
			values.priority,
			values.enabled,
		);

		if (initial) {
			control.send(new messages.RoleMappingUpdateRequest(record));
		} else {
			control.send(new messages.RoleMappingCreateRequest(
				values.roleIds,
				values.groupId,
				values.priority,
				values.enabled,
			));
		}

		setOpen(false);
	}

	return <Modal
		title={initial ? "Edit Role Mapping" : "Create Role Mapping"}
		open={open}
		onCancel={() => setOpen(false)}
		onOk={() => form.submit()}
	>
		<Form
			form={form}
			initialValues={{
				...initial,
				roleIds: initial ? [...initial.roleIds] : [],
			}}
			onFinish={submit}
		>
			<Form.Item name="roleIds" label="Roles" rules={[{ required: true }]}>
				<Select mode="multiple">
					{[...roles.values()].map(r => (
						<Select.Option key={r.id} value={r.id}>
							{r.name}
						</Select.Option>
					))}
				</Select>
			</Form.Item>

			<Form.Item name="groupId" label="Group" rules={[{ required: true }]}>
				<Select>
					{[...groups.values()].map(g => (
						<Select.Option key={g.id} value={g.id}>
							{g.name}
						</Select.Option>
					))}
				</Select>
			</Form.Item>

			<Form.Item name="priority" label="Priority" initialValue={0}>
				<InputNumber style={{ width: "100%" }} />
			</Form.Item>

			<Form.Item name="enabled" label="Enabled" valuePropName="checked" initialValue={true}>
				<Switch />
			</Form.Item>
		</Form>
	</Modal>;
}
