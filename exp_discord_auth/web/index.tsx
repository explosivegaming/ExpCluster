import React from "react";
import { WebPluginContext } from "@clusterio/web_ui";

import DiscordLoginForm from "./components/DiscordLoginForm";
import UserDiscordLink from "./components/UserDiscordLink";

export default function registerPlugin(context: WebPluginContext) {
	context.control.hooks.loginForms.attach("exp_discord_auth", () => [
		{
			name: "exp_discord_auth",
			title: "Discord",
			Component: DiscordLoginForm,
		},
	]);

	context.control.hooks.extensionComponents.attach("exp_discord_auth", () => ({
		UserViewPage: UserDiscordLink,
	}));
}
