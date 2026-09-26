# ExpGaming - Auto Restart

Restarts hosts, and optionally the controller, that need a restart once nobody is playing on them.

A host needs a restart after a plugin or clusterio update, and after a config change that only applies on restart. The web UI shows this as "Restart Required". This plugin waits until the host has had no players online for a while and then sends it the same restart request the web UI button does.

Restarting a host stops every instance on it. Once the host is back, the instances that were running are started again. Instances with auto start enabled are started by the host itself.

## Requirements

- Hosts must be run with `--can-restart` so their process monitor starts them again. The systemd units and run scripts written by the installer do this.
- `controller.system_metrics_interval` must be above 0. That poll is how the controller learns a host needs a restart.
- Installing a plugin on a host does not yet mark it as needing a restart, only updates and config changes do. Until clusterio does, restart the host by hand after an install.

## Config

All fields are on the controller.

| Field | Default | Description |
|---|---|---|
| `exp_auto_restart.idle_seconds` | 300 | How long a host must have had no players online before it is restarted. |
| `exp_auto_restart.scope` | host | With `cluster`, players on any host hold back every restart. |
| `exp_auto_restart.start_instances` | true | Start the instances that were running again once the host is back. |
| `exp_auto_restart.restart_controller` | false | Also restart the controller when it needs it and no players are online anywhere. |

Hosts are checked every 10 seconds. A host that refuses the restart, for example because it was not run with `--can-restart`, is logged once and left alone until its process changes.
