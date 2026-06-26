import React, { useContext, useEffect } from "react";
import { Modal, Form, Input, Switch } from "antd";
import { useNavigate } from "react-router-dom";

import { ControlContext } from "@clusterio/web_ui";
import * as messages from "../../messages";

export default function GroupForm({ open, setOpen }: {
	open: boolean,
	setOpen: (open: boolean) => void,
}) {
	const control = useContext(ControlContext);
	const navigate = useNavigate();

	const [form] = Form.useForm();

	async function submit(values: any) {
		const group = await control.send(new messages.GroupCreateRequest(
			values.name, new messages.GroupPermissions(Boolean(values.isBlacklist), [])
		));
		navigate(`/permission_groups/${group.id}/view`);
		setOpen(false);
	}

	useEffect(() => {
		if (open) form.resetFields();
	}, [open]);

	return <Modal
		title="Create Group"
		open={open}
		onCancel={() => setOpen(false)}
		onOk={() => form.submit()}
	>
		<Form form={form} onFinish={submit}>
			<Form.Item name="name" label="Name" rules={[{ required: true }]}>
				<Input />
			</Form.Item>

			<Form.Item name="isBlacklist" label="Grant all by default" valuePropName="checked">
				<Switch />
			</Form.Item>
		</Form>
	</Modal>;
}
