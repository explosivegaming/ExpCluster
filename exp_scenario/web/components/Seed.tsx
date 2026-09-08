import React, { useContext, useState } from "react";
import { Button, Popconfirm } from "antd";

import { ControlContext, SectionHeader, useAccount, notifyErrorHandler } from "@clusterio/web_ui";

import { SeedRequest } from "../../messages";

/** Button on the roles page which creates the roles and permission groups the scenario shipped with. */
export default function Seed() {
	const control = useContext(ControlContext);
	const account = useAccount();
	const [seeding, setSeeding] = useState(false);

	if (!account.hasPermission("exp_scenario.seed")) {
		return null;
	}

	return <SectionHeader
		title="ExpGaming Roles"
		extra={<Popconfirm
			title="Create the ExpGaming roles and permission groups?"
			description="Roles which already exist by name only gain permissions, groups are reset to the defaults."
			onConfirm={() => {
				setSeeding(true);
				control.send(new SeedRequest())
					.catch(notifyErrorHandler("Error seeding roles and groups"))
					.finally(() => setSeeding(false));
			}}
		>
			<Button loading={seeding}>Seed roles and groups</Button>
		</Popconfirm>}
	/>;
}
