import React from "react";
import { WebPluginContext } from "@clusterio/web_ui";

import DiscordLoginForm from "./components/DiscordLoginForm";
import UserDiscordLink from "./components/UserDiscordLink";

export default function registerPlugin(context: WebPluginContext) {
	context.control.hooks.loginForms.attach("exp_discord", () => [
		{
			name: "exp_discord",
			title: "Discord",
			Component: DiscordLoginForm,
		},
	]);

	context.control.hooks.extensionComponents.attach("exp_discord", () => ({
		UserViewPage: UserDiscordLink,
	}));
}
