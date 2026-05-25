import React, { useContext, useEffect } from "react";
import { Modal, Form, Select } from "antd";

import { ControlContext, useUsers } from "@clusterio/web_ui";
import * as messages from "../../messages";
import type { WebPlugin } from "..";

export default function AssignmentForm({ open, setOpen, initial }: {
	open: boolean,
	setOpen: (open: boolean) => void,
	initial?: messages.AssignmentRecord,
}) {
	const control = useContext(ControlContext);
	const plugin = control.plugins.get("exp_groups") as WebPlugin;

	const [groups] = plugin.useGroups();
	const [users] = useUsers();

	const [form] = Form.useForm();

	function submit(values: any) {
		if (initial) {
			control.send(new messages.AssignmentUpdateRequest(
				new messages.AssignmentRecord(
					values.name,
					values.groupId,
				)
			));
		} else {
			control.send(new messages.AssignmentCreateRequest(
				values.name,
				values.groupId,
			));
		}

		setOpen(false);
	}

	useEffect(() => {
		if (open) {
			form.resetFields();
			form.setFieldsValue(initial);
		}
	}, [open, initial]);

	return <Modal
		title={initial ? "Edit Assignment" : "Create Assignment"}
		open={open}
		onCancel={() => setOpen(false)}
		onOk={() => form.submit()}
	>
		<Form form={form} onFinish={submit}>
			<Form.Item name="name" label="Player" rules={[{ required: true }]}>
				<Select disabled={Boolean(initial)} showSearch>
					{[...users.values()].map(u => (
						<Select.Option key={u.name} value={u.name}>
							{u.name}
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
		</Form>
	</Modal>;
}
