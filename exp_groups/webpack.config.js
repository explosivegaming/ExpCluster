"use strict";
const path = require("path");
const webpack = require("webpack");
const { merge } = require("webpack-merge");

const common = require("@clusterio/web_ui/webpack.common");

module.exports = (env = {}) => merge(common(env), {
	context: __dirname,
	entry: "./web/index.tsx",
	output: {
		path: path.resolve(__dirname, "dist", "web"),
	},
	plugins: [
		new webpack.container.ModuleFederationPlugin({
			name: "exp_groups",
			library: { type: "window", name: "plugin_exp_groups" },
			exposes: {
				"./": "./index.ts",
				"./package.json": "./package.json",
				"./web": "./web/index.tsx",
			},
			shared: {
				"@clusterio/lib": { import: false },
				"@clusterio/web_ui": { import: false },
				"antd": { import: false },
				"react": { import: false },
				"react-dom": { import: false },
			},
		}),
	],
});
