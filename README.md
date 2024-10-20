<p align="center">
  <img alt="logo" src="https://avatars2.githubusercontent.com/u/39745392?s=200&v=4" width="120">
  <br>
  <a href="https://github.com/explosivegaming/scenario/tags">
    <img src="https://img.shields.io/github/tag/explosivegaming/scenario.svg?label=Release" alt="Release">
  </a>
  <a href="https://github.com/explosivegaming/scenario/archive/master.zip">
    <img src="https://img.shields.io/github/downloads/explosivegaming/scenario/total.svg?label=Downloads" alt="Downloads">
  </a>
  <a href="https://github.com/explosivegaming/scenario/stargazers">
    <img src="https://img.shields.io/github/stars/explosivegaming/scenario.svg?label=Stars" alt="Star">
  </a>
  <a href="http://github.com/explosivegaming/scenario/fork">
    <img src="https://img.shields.io/github/forks/explosivegaming/scenario.svg?label=Forks" alt="Fork">
  </a>
  <a href="https://www.codefactor.io/repository/github/explosivegaming/scenario">
    <img src="https://www.codefactor.io/repository/github/explosivegaming/scenario/badge" alt="CodeFactor">
  </a>
  <a href="https://discord.explosivegaming.nl">
    <img src="https://discordapp.com/api/guilds/260843215836545025/widget.png?style=shield" alt="Discord">
  </a>
</p>
<h1 align="center">ExpGaming Clusterio Repository</h2>

## Explosive Gaming

Explosive Gaming (often ExpGaming) is a server hosting community with a strong focus on [Factorio][factorio] and games with similar themes. We are best known for our weekly reset Factorio server with a vanilla+ scenario where we add new features and mechanics that are balanced with base game progression. Although our servers tend to attract the more experienced players, our servers are open to everyone. You can find us through our [website], [discord], or the public server list with the name ExpGaming.

## Installation

This is a plugin collection for [Clustorio](https://github.com/clusterio/clusterio) which provides all our scenario features.

To use this plugin you must already have a clustorio instance running, see [here](https://github.com/clusterio/clusterio?tab=readme-ov-file#installation) for clustorio installation instructions.

This module is currently not published and therefore can not be installed via `npm`. Instead follow the steps for [building from source](#building-from-source)

## Building from source

1) Create a `external_plugins` directory within your clustorio instance.
2) Clone this repository into that directory: `git clone https://github.com/explosivegaming/ExpCluster`
3) Install the package dev dependencies: `pnpm install`
4) Add the plugins to your clustorio instance such as: `npx clustorioctl plugin add ./external_plugins/ExpCluster/exp_groups`

## Contributing

See [Contributing](CONTRIBUTING.md) for how to make pull requests and issues.

## Releases

| Release* | Release Name | Factorio Version** |
|---|---|---|
| [6.4][s6.4] | Farewell Factorio 1.1 | [1.1.110][f1.1.110] |
| [6.3][s6.3] | Feature Bundle 2: Electric Boogaloo | [1.1.101][f1.1.101] |
| [6.2][s6.2] | Mega Feature Bundle | [1.1.32][f1.1.32] |
| [6.1][s6.1] | External Data Overhaul | [1.0.0][f1.0.0] |
| [6.0][s6.0] | Gui / 0.18 Overhaul | [0.18.17][f0.18.17] |
| [5.10][s5.10] | Data Store Rewrite | [0.17.71][f0.17.71] |
| [5.9][s5.9] | Control Modules and Documentation | [0.17.63][f0.17.63] |
| [5.8][s5.8] | Home and Chat Bot | [0.17.47][f0.17.49] |
| [5.7][s5.7] | Warp System | [0.17.47][f0.17.47] |
| [5.6][s5.6] | Information Guis | [0.17.44][f0.17.44] |
| [5.5][s5.5] | Gui System | [0.17.43][f0.17.43] |
| [5.4][s5.4] | Admin Controls | [0.17.32][f0.17.32] |
| [5.3][s5.3] | Custom Roles | [0.17.28][f0.17.28] |
| [5.2][s5.2] | Quality of life | [0.17.22][f0.17.22] |
| [5.1][s5.1] | Permission Groups | [0.17.13][f0.17.13] |
| [5.0][s5.0] | 0.17 Overhaul| [0.17][f0.17.9] |
| [4.0][s4.0] | Softmod Manager | [0.16.51][f0.16.51] |
| [3.0][s3.0] | 0.16 Overhaul | [0.16][f0.16] |
| [2.0][s2.0] | Localization and clean up | [0.15][f0.15] |
| [1.0][s1.0] | Modulation | [0.15][f0.15] |
| [0.1][s0.1] | First Tracked Version | [0.14][f0.14] |

\* Scenario patch releases have been omitted and can be found [here][releases].

\*\* Factorio versions show the version they were made for, often the minimum requirement to run the scenario.

[s6.4]: https://github.com/explosivegaming/scenario/releases/tag/6.4.0
[s6.3]: https://github.com/explosivegaming/scenario/releases/tag/6.3.0
[s6.2]: https://github.com/explosivegaming/scenario/releases/tag/6.2.0
[s6.1]: https://github.com/explosivegaming/scenario/releases/tag/6.1.0
[s6.0]: https://github.com/explosivegaming/scenario/releases/tag/6.0.0
[s5.10]: https://github.com/explosivegaming/scenario/releases/tag/5.10.0
[s5.9]: https://github.com/explosivegaming/scenario/releases/tag/5.9.0
[s5.8]: https://github.com/explosivegaming/scenario/releases/tag/5.8.0
[s5.7]: https://github.com/explosivegaming/scenario/releases/tag/5.7.0
[s5.6]: https://github.com/explosivegaming/scenario/releases/tag/5.6.0
[s5.5]: https://github.com/explosivegaming/scenario/releases/tag/5.5.0
[s5.4]: https://github.com/explosivegaming/scenario/releases/tag/5.4.0
[s5.3]: https://github.com/explosivegaming/scenario/releases/tag/5.3.0
[s5.2]: https://github.com/explosivegaming/scenario/releases/tag/5.2.0
[s5.1]: https://github.com/explosivegaming/scenario/releases/tag/5.1.0
[s5.0]: https://github.com/explosivegaming/scenario/releases/tag/5.0.0
[s4.0]: https://github.com/explosivegaming/scenario/releases/tag/v4.0
[s3.0]: https://github.com/explosivegaming/scenario/releases/tag/v3.0
[s2.0]: https://github.com/explosivegaming/scenario/releases/tag/v2.0
[s1.0]: https://github.com/explosivegaming/scenario/releases/tag/v1.0
[s0.1]: https://github.com/explosivegaming/scenario/releases/tag/v0.1

[f1.1.110]: https://wiki.factorio.com/Version_history/1.1.0#1.1.110
[f1.1.101]: https://wiki.factorio.com/Version_history/1.1.0#1.1.101
[f1.1.32]: https://wiki.factorio.com/Version_history/1.1.0#1.1.32
[f1.0.0]: https://wiki.factorio.com/Version_history/1.0.0#1.0.0
[f0.18.17]: https://wiki.factorio.com/Version_history/0.18.0#0.18.17
[f0.17.71]: https://wiki.factorio.com/Version_history/0.17.0#0.17.71
[f0.17.63]: https://wiki.factorio.com/Version_history/0.17.0#0.17.63
[f0.17.49]: https://wiki.factorio.com/Version_history/0.17.0#0.17.49
[f0.17.47]: https://wiki.factorio.com/Version_history/0.17.0#0.17.47
[f0.17.44]: https://wiki.factorio.com/Version_history/0.17.0#0.17.44
[f0.17.43]: https://wiki.factorio.com/Version_history/0.17.0#0.17.43
[f0.17.32]: https://wiki.factorio.com/Version_history/0.17.0#0.17.32
[f0.17.28]: https://wiki.factorio.com/Version_history/0.17.0#0.17.28
[f0.17.22]: https://wiki.factorio.com/Version_history/0.17.0#0.17.22
[f0.17.13]: https://wiki.factorio.com/Version_history/0.17.0#0.17.13
[f0.17.9]: https://wiki.factorio.com/Version_history/0.17.0#0.17.9
[f0.16.51]: https://wiki.factorio.com/Version_history/0.16.0#0.16.51
[f0.16]: https://wiki.factorio.com/Version_history/0.16.0
[f0.15]: https://wiki.factorio.com/Version_history/0.15.0
[f0.14]: https://wiki.factorio.com/Version_history/0.14.0

## License

The Explosive Gaming codebase is licensed under the [MIT](LICENSE)

[stable-dl]: https://github.com/explosivegaming/scenario/archive/master.zip
[experimental-dl]: https://github.com/explosivegaming/scenario/archive/dev.zip
[releases]: https://github.com/explosivegaming/scenario/releases
[factorio]: https://factorio.com
[docs]: https://explosivegaming.github.io/scenario
[issues]: https://github.com/explosivegaming/scenario/issues/new/choose
[website]: https://explosivegaming.nl
[discord]: https://discord.explosivegaming.nl
