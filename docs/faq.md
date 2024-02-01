## FAQ

### How does *Gantry* work?

Fundamentally *Gantry* calls [`docker service update`](https://docs.docker.com/engine/reference/commandline/service_update/) CLI and let docker engine [applies rolling updates to a service](https://docs.docker.com/engine/swarm/swarm-tutorial/rolling-update/).

Before updating a service, *Gantry* will try to obtain the manifest of the image used by the service to decide whether there is a new image.

At the end of updating, *Gantry* optionally removes the old images.

### How to update standalone docker containers?

*Gantry* only works for docker swarm services. If you need to update standalone docker containers, you can try [*watchtower*](https://github.com/containrrr/watchtower). *Gantry* can launch *watchtower* via `GANTRY_PRE_RUN_CMD` or `GANTRY_POST_RUN_CMD`. See the [example](../examples/prune-and-watchtower).

### How to filters multiple services by name?

It will not work by setting multiple filters with different names, because filters are logical **ANDED**.

To filter multiple services, you can set a label on each service then let *Gantry* filter on that label. Or you can run multiple *Gantry* instances.

Advanced user can also create their own entrypoint using functions in [lib-gantry.sh](../src/lib-gantry.sh).
```
# notification.sh is optional.
source ./src/lib-common.sh;
source ./src/lib-gantry.sh;
gantry_initialize;
gantry_update_services_list "${LIST_OF_SERVICES_TO_UPDATE}";
gantry_finalize;
```

### How to run *Gantry* on a cron schedule?

You can start *Gantry* as a docker swarm service and use [`swarm-cronjob`](https://github.com/crazy-max/swarm-cronjob) to run it at a given time. When use `swarm-cronjob`, you need to set `GANTRY_SLEEP_SECONDS` to 0. See the [example](../examples/cronjob).

### How to update services with no running tasks?

As discussed [here](https://github.com/docker/cli/issues/627), the CLI will hang when running `docker service update` on a service with no running tasks. We must add `--detach=true` option to the `docker service update`.

*Gantry* will check whether there are running tasks in a service. If there is no running task, *Gantry* automatically adds the option `--detach=true`. In addition to the detach option, *Gantry* also adds `--replicas=0` for services in replicated mode. You don't need to add these options manually.

### When to set `GANTRY_MANIFEST_CMD`?

Before updating a service, *Gantry* will try to obtain the image's meta data to decide whether there is a new image. If there is no new image, *Gantry* skips calling `docker service update`.

`docker buildx imagetools inspect` is selected as the default, because `docker manifest inspect` could [fail on some registries](https://github.com/orgs/community/discussions/45779). Additionally, `docker buildx imagetools` can obtain the digest of multi-arch images, which could help not to run the `docker service update` CLI when there is no new images.

You can switch back to use [`docker manifest inspect`](https://docs.docker.com/engine/reference/commandline/manifest_inspect/) for the features that are not supported by [`docker buildx imagetools inspect`](https://docs.docker.com/engine/reference/commandline/buildx_imagetools_inspect/).

### I logged in my Docker Hub account, but the Docker Hub rate reported seems incorrect.

When checking Docker Hub rate, *Gantry* reads the Docker Hub credential only from `GANTRY_REGISTRY_PASSWORD` and `GANTRY_REGISTRY_USER`, or their `_FILE` variants. `GANTRY_REGISTRY_HOST` or its `_FILE` variant must be either empty or `docker.io`.

If you need to login to multiple registries, you can use `GANTRY_REGISTRY_CONFIGS_FILE` together with `GANTRY_REGISTRY_PASSWORD` and `GANTRY_REGISTRY_USER`. Credentials in `GANTRY_REGISTRY_CONFIGS_FILE` will be used for services updating, but they won't be used for checking Docker Hub rate. See [Authentication](../README.md#authentication) for more information.
