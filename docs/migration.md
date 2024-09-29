## Migration from shepherd

*Gantry* started to fix the following problems I found in [*shepherd*](https://github.com/containrrr/shepherd), then it became refactored and totally rewritten, with [abundant tests](../tests/README.md).

* `docker manifest` CLI failed to get the image meta data for some registries.
* High usage of Docker Hub rate. Getting manifest and then pulling the image double the usage.
* Running `docker service update` command when there is no new image slows down the overall process.
* Removing images related
    * Failure of removing old images will exit and block subsequent updating.
    * `docker rmi` only works for the current host.
* `docker service update` CLI hangs when updating services without running tasks.
* Other UX issues when running it as a script outside the provided container.

Although I have tried to keep backward compatibility, not all configurations in *shepherd* are supported.

This guide helps you migrate from *shepherd* to *gantry* by highlighting the difference between them. Please refer to the [README](../README.md) for the full description of the configurations.

### Equivalent or similar configurations

| *Shepherd* Env | Equivalent or similar *Gantry* Env  | Enhancement |
|----------------|-------------------------------------|-------------|
| VERBOSE               | GANTRY_LOG_LEVEL                | To introduce more granularity on log levels. *Gantry* can go total slience by setting `GANTRY_LOG_LEVEL` to `NONE`. |
| HOSTNAME              | GANTRY_NODE_NAME                | |
| SLEEP_TIME            | GANTRY_SLEEP_SECONDS            | This is now the interval between two updates. The actual sleep time is this value minus time spent on updating services. |
| IGNORELIST_SERVICES   | GANTRY_SERVICES_EXCLUDED        | |
| FILTER_SERVICES       | GANTRY_SERVICES_FILTERS         | |
| UPDATE_OPTIONS        | GANTRY_UPDATE_OPTIONS           | |
| TIMEOUT               | GANTRY_UPDATE_TIMEOUT_SECONDS   | |
| ROLLBACK_OPTIONS      | GANTRY_ROLLBACK_OPTIONS         | |
| ROLLBACK_ON_FAILURE   | GANTRY_ROLLBACK_ON_FAILURE      | |
| APPRISE_SIDECAR_URL   | GANTRY_NOTIFICATION_APPRISE_URL | |
| REGISTRY_USER         | GANTRY_REGISTRY_USER            | |
| REGISTRY_PASSWORD     | GANTRY_REGISTRY_PASSWORD        | |
| REGISTRY_HOST         | GANTRY_REGISTRY_HOST            | |
| REGISTRIES_FILE       | GANTRY_REGISTRY_CONFIGS_FILE    | |
| IMAGE_AUTOCLEAN_LIMIT | GANTRY_CLEANUP_IMAGES           | *Gantry* only cleans up the images being updated, thus a limit is not used now. |

The label on the services to select config to enable authentication is renamed to `gantry.auth.config`.

### Deprecated configurations

| *Shepherd* Env | Workaround |
|----------------|------------|
| WITH_REGISTRY_AUTH     | *Gantry* automatically adds `--with-registry-auth` to the `docker service update` command for a sevice, when it finds the label `gantry.auth.config=<config-name>` on the service. Or manually add `--with-registry-auth` to `GANTRY_UPDATE_OPTIONS`. |
| WITH_INSECURE_REGISTRY | Manually add `--insecure` to `GANTRY_MANIFEST_OPTIONS` and set `GANTRY_MANIFEST_CMD` to `manifest`. |
| WITH_NO_RESOLVE_IMAGE  | Manually add `--no-resolve-image` to `GANTRY_UPDATE_OPTIONS`. |
| RUN_ONCE_AND_EXIT      | Set `GANTRY_SLEEP_SECONDS` to 0. |

### New configurations

| *Gantry* Env  | Purpose |
|---------------|----------------------|
| GANTRY_MANIFEST_CMD              | To retrieve image metadata correctly and to reduce the Docker Hub rate usage. |
| GANTRY_MANIFEST_NUM_WORKERS      | To run multiple manifest commands in parallel to accelerate the updating process. |
| GANTRY_MANIFEST_OPTIONS          | To customize `GANTRY_MANIFEST_CMD`. |
| GANTRY_NOTIFICATION_CONDITION    | To control notification. *Gantry* only send a summary of updating at the end of each iteration, which includes lists of updated services and errors. |
| GANTRY_NOTIFICATION_TITLE        | To customize notification. *Gantry* only send a summary of updating at the end of each iteration, which includes lists of updated services and errors. |
| GANTRY_POST_RUN_CMD              | To run customized tasks together with *Gantry*. See the [example](../examples/prune-and-watchtower). |
| GANTRY_PRE_RUN_CMD               | To run customized tasks together with *Gantry*. See the [example](../examples/prune-and-watchtower). |
| GANTRY_REGISTRY_CONFIG           | To apply authentication to only selected services. To use simple authentication configurations together with `GANTRY_REGISTRY_CONFIGS_FILE`. |
| GANTRY_REGISTRY_CONFIG_FILE      | To pass sensitive information via [docker secret](https://docs.docker.com/engine/swarm/secrets/). |
| GANTRY_REGISTRY_HOST_FILE        | To pass sensitive information via [docker secret](https://docs.docker.com/engine/swarm/secrets/). |
| GANTRY_REGISTRY_PASSWORD_FILE    | To pass sensitive information via [docker secret](https://docs.docker.com/engine/swarm/secrets/). |
| GANTRY_REGISTRY_USER_FILE        | To pass sensitive information via [docker secret](https://docs.docker.com/engine/swarm/secrets/). |
| GANTRY_SERVICES_EXCLUDED_FILTERS | To provide an alternative method to exclude services from being updated. |
| GANTRY_UPDATE_JOBS               | *Gantry* can distinguish `replicated-job` and `global-job` from other services. *Gantry* automatically adds more options to [update services with no running tasks](faq.md#how-to-update-services-with-no-running-tasks) to avoid hanging. |
| GANTRY_UPDATE_NUM_WORKERS        | To run multiple update commands in parallel to accelerate the updating process. |

Besides the global configurations via environment variables, you can apply a different value to a particular service via [labels](../README.md#labels).

### License

*Shepherd* is under [MIT license](https://github.com/containrrr/shepherd/blob/master/LICENSE)

*Gantry* is under [GPL-3.0 license](https://github.com/shizunge/gantry/blob/main/LICENSE)
