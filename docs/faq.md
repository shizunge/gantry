## FAQ

### How does *Gantry* work?

Fundamentally *Gantry* calls [`docker service update`](https://docs.docker.com/engine/reference/commandline/service_update/) CLI and let docker engine [applies rolling updates to a service](https://docs.docker.com/engine/swarm/swarm-tutorial/rolling-update/).

Before updating a service, *Gantry* will try to obtain the manifest of the image used by the service to decide whether there is a new image.

At the end of updating, *Gantry* optionally removes the old images.

### How to update standalone docker containers?

*Gantry* only works for docker swarm services. If you need to update standalone docker containers, you can try [*watchtower*](https://github.com/containrrr/watchtower). *Gantry* can launch *watchtower* via `GANTRY_PRE_RUN_CMD` or `GANTRY_POST_RUN_CMD`. See the [example](../examples/prune-and-watchtower).

### How to filters multiple services by name?

It will not work by setting multiple filters with different names, because filters are logical **ANDED**.

To filter multiple services, you can set a label on each service then let *Gantry* filter on that label via `GANTRY_SERVICES_FILTERS`. Or you can run multiple *Gantry* instances.

### How to run *Gantry* on a cron schedule?

You can start *Gantry* as a docker swarm service and use [`swarm-cronjob`](https://github.com/crazy-max/swarm-cronjob) to run it at a given time. When use `swarm-cronjob`, you need to set `GANTRY_SLEEP_SECONDS` to 0. See the [example](../examples/cronjob).

### How to update services with no running tasks?

As discussed [here](https://github.com/docker/cli/issues/627), the CLI will hang when running `docker service update` on a service with no running tasks. We must add `--detach=true` option to the `docker service update`.

*Gantry* will check whether there are running tasks in a service. If there is no running task, *Gantry* automatically adds the option `--detach=true`. In addition to the detach option, *Gantry* also adds `--replicas=0` for services in replicated mode. You don't need to add these options manually.

### What `GANTRY_MANIFEST_CMD` to use?

Before updating a service, *Gantry* will try to obtain the image's meta data to decide whether there is a new image. If there is no new image, *Gantry* skips calling `docker service update`, leading to a speedup of the overall process.

In most cases, the default value `buildx` of `GANTRY_MANIFEST_CMD` should work. `docker buildx imagetools inspect` is selected as the default, because `docker manifest inspect` could [fail on some registries](https://github.com/orgs/community/discussions/45779). Additionally, `docker buildx imagetools` can obtain the digest of multi-arch images, which could help reduce the number of calling the `docker service update` CLI when there is no new images.

We keep [`docker manifest inspect`](https://docs.docker.com/engine/reference/commandline/manifest_inspect/) for debugging purpose. There is no known advantage to use `manifest`.

You can disable the image inspection by setting `GANTRY_MANIFEST_CMD` to `none` in case there is a bug. Please report the bug through a [GitHub issue](https://github.com/shizunge/gantry/issues). Another use case of `none` is that you want to add `--force` to the `docker service update` command via `GANTRY_UPDATE_OPTIONS`, which updates the services even if there is nothing changed.

### I logged in my Docker Hub account, but the Docker Hub rate reported seems incorrect.

When checking Docker Hub rate, *Gantry* reads the Docker Hub credential only from `GANTRY_REGISTRY_PASSWORD` and `GANTRY_REGISTRY_USER`, or their `_FILE` variants. `GANTRY_REGISTRY_HOST` or its `_FILE` variant must be either empty or `docker.io`.

If you need to login to multiple registries, you can use `GANTRY_REGISTRY_CONFIGS_FILE` together with `GANTRY_REGISTRY_PASSWORD` and `GANTRY_REGISTRY_USER`. Credentials in `GANTRY_REGISTRY_CONFIGS_FILE` will be used for services updating, but they won't be used for checking Docker Hub rate. See [Authentication](../README.md#authentication) for more information.
