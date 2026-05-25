import React from "react";
import { Button, Popconfirm } from "antd";
import { DeleteOutlined } from "@ant-design/icons";
import { TooltipPlacement } from "antd/es/tooltip";

export default function DeletedConfirm(props: { onConfirm: () => void, placement?: TooltipPlacement }) {
    return <Popconfirm
        title="Delete?"
        okText="Delete"
		okButtonProps={{ danger: true }}
        onConfirm={props.onConfirm}
        placement={props.placement}
    >
        <Button danger icon={<DeleteOutlined />} />
    </Popconfirm>
}
