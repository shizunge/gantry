## FAQ

### How does *Gantry* work?

Fundamentally *Gantry* calls [`docker service update`](https://docs.docker.com/engine/reference/commandline/service_update/) CLI and let docker engine [applies rolling updates to a service](https://docs.docker.com/engine/swarm/swarm-tutorial/rolling-update/).

Before updating a service, *Gantry* will try to obtain the manifest of the image used by the service to decide whether there is a new image.

At the end of updating, *Gantry* optionally removes the old images.

### How to update standalone docker containers?

*Gantry* only works for docker swarm services. If you need to update standalone docker containers, you can try [watchtower](https://github.com/containrrr/watchtower).

### How to filters multiple services by name?

You can set multiple filters. However filters are **ANDED**. So multiple filters on different names will not work.

To filter multiple services, you can set a label on each service then let *Gantry* filter on that label. Or you can run multiple *Gantry* instances.

### How to run *Gantry* on a cron schedule?

You can start *Gantry* as a docker swarm service and use [`swarm-cronjob`](https://github.com/crazy-max/swarm-cronjob) to run it at a given time. When use `swarm-cronjob`, you need to set `GANTRY_SLEEP_SECONDS` to 0. See the [example](examples/docker-compose.yml).

### How to update services with no running tasks?

As discussed [here](https://github.com/docker/cli/issues/627), it will lead the CLI hanging by running `docker service update` on a service with no running tasks. We must add `--detach=true` option to the `docker service update`. 

*Gantry* will check if there are running tasks in a services and automatically add the option `--detach=true`. You don't need to add the option manually.

### When to set `GANTRY_MANIFEST_USE_MANIFEST_CMD`?

Before updating a service, *Gantry* will try to obtain the image's meta data to decide whether there is a new image. If there is no new image, *Gantry* skips the updating.

I found `docker manifest inspect` [failed on some registries](https://github.com/orgs/community/discussions/45779), so I use `docker buildx imagetools inspect` to obtain the image digest by default.

You can switch back to use `docker manifest inspect` in case `docker buildx imagetools inspect` does not support some features you need.

### I logged in my Docker Hub account, but the Docker Hub rate reported seems incorrect.

*Gantry* does not yet support to report Docker Hub rate with a user account.
