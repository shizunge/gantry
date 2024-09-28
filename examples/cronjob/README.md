# cronjob

Use [*swarm-cronjob*](https://github.com/crazy-max/swarm-cronjob) to launch [*Gantry*](https://github.com/shizunge/gantry) at a specific time.

In this example, we only want to run *Gantry* at the specific time, therefore we set `replicas` to `0` on the *Gantry* service to avoid running it as soon as the service is deployed. We also need to set `restart_policy.condition` to `none` to prevent *Gantry* from restarting automatically after a cronjob.

Refer to the [*swarm-cronjob* document](https://crazymax.dev/swarm-cronjob/) for more information.
