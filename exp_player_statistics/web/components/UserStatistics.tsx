import React, { useContext, useEffect, useState } from "react";
import { Descriptions } from "antd";

import { ControlContext, PluginExtensionProps, SectionHeader, notifyErrorHandler, useAccount } from "@clusterio/web_ui";

import { PlayerStatistics, StatisticsGetRequest } from "../../messages.js";
import { formatValue, statistics } from "../statistics";

/** The statistics of a player, shown on their user page. */
export default function UserStatistics(props: PluginExtensionProps<"UserViewPage">) {
	const control = useContext(ControlContext);
	const account = useAccount();
	const canView = Boolean(account.hasPermission("exp_player_statistics.view"));
	const name = props.user.name;
	const [record, setRecord] = useState<PlayerStatistics>();

	useEffect(() => {
		if (canView) {
			control.send(new StatisticsGetRequest(name))
				.then(setRecord)
				.catch(notifyErrorHandler("Error loading player statistics"));
		}
	}, [name, canView]);

	if (!canView || !record) {
		return null;
	}

	return <>
		<SectionHeader title="Statistics" />
		<Descriptions size="small" bordered column={{ xs: 1, sm: 2, md: 2, lg: 2, xl: 2, xxl: 2 }}>
			{statistics.map(([statistic, title]) => <Descriptions.Item key={statistic} label={title}>
				{formatValue(statistic, record.stats[statistic] ?? 0)}
			</Descriptions.Item>)}
		</Descriptions>
	</>;
}
