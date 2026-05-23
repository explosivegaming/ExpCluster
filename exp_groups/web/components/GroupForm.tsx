import React, { useContext } from "react";
import { Modal, Form, Input, Switch } from "antd";
import { useNavigate } from "react-router-dom";

import { ControlContext } from "@clusterio/web_ui";
import * as messages from "../../messages";

export default function GroupForm({ open, setOpen, initial }: any) {
	const control = useContext(ControlContext);
	const [form] = Form.useForm();
	const navigate = useNavigate();

	async function submit(values: any) {
		if (initial) {
			control.send(new messages.GroupUpdateRequest(
				new messages.GroupRecord(
					initial.id, values.name,
					new messages.GroupPermissions(Boolean(values.isBlacklist), [])
				)
			));
		} else {
			const group = await control.send(new messages.GroupCreateRequest(
				values.name, new messages.GroupPermissions(Boolean(values.isBlacklist), [])
			));
			navigate(`/exp_groups/${group.id}/view`);
		}

		setOpen(false);
	}

	return <Modal title="Group" open={open} onCancel={() => setOpen(false)} onOk={() => form.submit()}>
		<Form form={form} initialValues={initial} onFinish={submit}>
			<Form.Item name="name" label="Name" rules={[{ required: true }]}>
				<Input />
			</Form.Item>
			<Form.Item name="isBlacklist" label="Grant all by default" valuePropName="checked">
				<Switch />
			</Form.Item>
		</Form>
	</Modal>;
}
