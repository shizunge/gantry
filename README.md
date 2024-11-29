# Gantry - Docker service updater

[![Release](https://img.shields.io/github/release/shizunge/gantry.svg?label=Release)](https://github.com/shizunge/gantry/releases/latest)
[![License](https://img.shields.io/badge/License-GPLv3-blue)](https://github.com/shizunge/gantry/blob/main/LICENSE)
[![Image Size](https://img.shields.io/docker/image-size/shizunge/gantry/latest.svg?label=Image%20Size)](https://hub.docker.com/r/shizunge/gantry)
[![Docker Pulls](https://img.shields.io/docker/pulls/shizunge/gantry.svg?label=Docker%20Pulls&logo=Docker)](https://hub.docker.com/r/shizunge/gantry)
[![Build](https://img.shields.io/github/actions/workflow/status/shizunge/gantry/on-push.yml?label=Build&branch=main&logo=GitHub)](https://github.com/shizunge/gantry/actions/workflows/on-push.yml)
[![Coverage](https://img.shields.io/codecov/c/github/shizunge/gantry.svg?token=47MWUJOH4Q&label=Coverage&logo=Codecov)](https://codecov.io/gh/shizunge/gantry)
[![CodeFactor Grade](https://img.shields.io/codefactor/grade/github/shizunge/gantry?label=CodeFactor&logo=CodeFactor)](https://www.codefactor.io/repository/github/shizunge/gantry)

[*Gantry*](https://github.com/shizunge/gantry) automatically updates selected docker swarm services to newer images with the same tag. It is inspired by but [enhanced Shepherd](docs/migration.md).

## Usage

*Gantry* is released as a container [image](https://hub.docker.com/r/shizunge/gantry). You can create a docker service and run it on a swarm manager node.

```
docker service create \
  --name gantry \
  --mode replicated-job \
  --constraint "node.role==manager" \
  --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
  shizunge/gantry
```

The [examples folder](examples/README.md) contains example docker compose files, and more methods to launch *Gantry*, like [at a specific time](examples/cronjob) and [via webhook](examples/webhook).

You can also run *Gantry* as a script directly on the host outside the container
```
./src/entrypoint.sh
```

*Gantry* is written to work with `busybox ash` (v1.35+) as well as `bash`.

## Configurations

You can configure the most behaviors of *Gantry* via environment variables.

### Common

| Environment Variable  | Default |Description |
|-----------------------|---------|------------|
| GANTRY_LOG_LEVEL      | INFO | Control how many logs generated by *Gantry*. Valid values are `NONE`, `ERROR`, `WARN`, `INFO`, `DEBUG`. |
| GANTRY_NODE_NAME      |      | Add node name to logs. If not set, *Gantry* will use the host name of the Docker Swarm's manager, which is read from either the Docker daemon socket of current node or `DOCKER_HOST`. |
| GANTRY_POST_RUN_CMD   |      | Command(s) to `eval` after each updating iteration. For [example](examples/prune-and-watchtower), you can use this to remove unused containers, networks and images and update standalone docker containers. |
| GANTRY_PRE_RUN_CMD    |      | Command(s) to `eval` before each updating iteration. For [example](examples/prune-and-watchtower), you can use this to remove unused containers, networks and images and update standalone docker containers. If you changed *Gantry* configurations in the pre-run command(s), the new value would apply to the following updating. If the last pre-run command failed, *Gantry* would skip updating services. |
| GANTRY_SLEEP_SECONDS  | 0    | Interval between two updates. Set it to 0 to run *Gantry* once and then exit. When this is a non-zero value, after an updating, *Gantry* will sleep until the next scheduled update. The actual sleep time is this value minus time spent on updating services. |
| TZ                    |      | Set timezone for time in logs. |

*Gantry* bases on Docker command line, [environment variables](https://docs.docker.com/engine/reference/commandline/cli/#environment-variables) for Docker command line also works for *Gantry*.

### To login to registries

| Environment Variable  | Default | Description |
|-----------------------|---------|-------------|
| DOCKER_CONFIG                 | | The location of the [client configuration files](https://docs.docker.com/engine/reference/commandline/cli/#configuration-files) where authentication stores. It applys to all Docker commands, i.e. to all services. See [Authentication](docs/authentication.md). You can apply a different value to a particular service via [labels](#labels). |
| GANTRY_REGISTRY_CONFIG        | | See [Authentication](docs/authentication.md). |
| GANTRY_REGISTRY_CONFIG_FILE   | | See [Authentication](docs/authentication.md). |
| GANTRY_REGISTRY_CONFIGS_FILE  | | See [Authentication](docs/authentication.md). |
| GANTRY_REGISTRY_HOST          | | See [Authentication](docs/authentication.md). |
| GANTRY_REGISTRY_HOST_FILE     | | See [Authentication](docs/authentication.md). |
| GANTRY_REGISTRY_PASSWORD      | | See [Authentication](docs/authentication.md). |
| GANTRY_REGISTRY_PASSWORD_FILE | | See [Authentication](docs/authentication.md). |
| GANTRY_REGISTRY_USER          | | See [Authentication](docs/authentication.md). |
| GANTRY_REGISTRY_USER_FILE     | | See [Authentication](docs/authentication.md). |

### To select services

| Environment Variable  | Default | Description |
|-----------------------|---------|-------------|
| GANTRY_SERVICES_EXCLUDED         | | A space separated list of services names that are excluded from updating. |
| GANTRY_SERVICES_EXCLUDED_FILTERS | `label=gantry.services.excluded=true` | A space separated list of [filters](https://docs.docker.com/engine/reference/commandline/service_ls/#filter), e.g. `label=project=project-a`. Exclude services which match the given filters from updating. The default value allows you to add label `gantry.services.excluded=true` to services to exclude them from updating. Note that multiple filters will be logical **ANDED**. |
| GANTRY_SERVICES_FILTERS          | | A space separated list of [filters](https://docs.docker.com/engine/reference/commandline/service_ls/#filter) that are accepted by `docker service ls --filter` to select services to update, e.g. `label=project=project-a`. Note that multiple filters will be logical **ANDED**. Also see [How to filters multiple services by name](docs/faq.md#how-to-filters-multiple-services-by-name). |

> NOTE: *Gantry* reads labels on the services not on the containers. The labels need to go to the [deploy](https://docs.docker.com/reference/compose-file/deploy/#labels) section, if you are using docker compose files to setup your services.

### To check if new images are available

| Environment Variable  | Default | Description |
|-----------------------|---------|-------------|
| GANTRY_MANIFEST_CMD         | buildx | Valid values are `buildx`, `manifest`, and `none`.<br>Set which command for manifest inspection.<ul><li>[`docker buildx imagetools inspect`](https://docs.docker.com/engine/reference/commandline/buildx_imagetools_inspect/)</li><li>[`docker manifest inspect`](https://docs.docker.com/engine/reference/commandline/manifest_inspect/)</li></ul>Set to `none` to skip checking the manifest. As a result of skipping, `docker service update` always runs. Also see FAQ [which `GANTRY_MANIFEST_CMD` to use](docs/faq.md#which-gantry_manifest_cmd-to-use). You can apply a different value to a particular service via [labels](#labels). |
| GANTRY_MANIFEST_NUM_WORKERS | 1      | The maximum number of `GANTRY_MANIFEST_CMD` that can run in parallel. |
| GANTRY_MANIFEST_OPTIONS     |        | [Options](https://docs.docker.com/engine/reference/commandline/buildx_imagetools_inspect/#options) added to the `docker buildx imagetools inspect` or [options](https://docs.docker.com/engine/reference/commandline/manifest_inspect/#options) to `docker manifest inspect`, depending on `GANTRY_MANIFEST_CMD` value, for all services. You can apply a different value to a particular service via [labels](#labels). |

### To add options to services update

| Environment Variable  | Default | Description |
|-----------------------|---------|-------------|
| GANTRY_ROLLBACK_ON_FAILURE    | true  | Set to `true` to enable rollback when updating fails. Set to `false` to disable the rollback. You can apply a different value to a particular service via [labels](#labels). |
| GANTRY_ROLLBACK_OPTIONS       |       | [Options](https://docs.docker.com/engine/reference/commandline/service_update/#options) added to the `docker service update --rollback` command for all services. You can apply a different value to a particular service via [labels](#labels). |
| GANTRY_UPDATE_JOBS            | false | Set to `true` to update `replicated-job` or `global-job`. Set to `false` to disable updating jobs. *Gantry* adds additional options to `docker service update` when there is [no running tasks](docs/faq.md#how-to-update-services-with-no-running-tasks). You can apply a different value to a particular service via [labels](#labels). |
| GANTRY_UPDATE_NUM_WORKERS     | 1     | The maximum number of updates that can run in parallel. |
| GANTRY_UPDATE_OPTIONS         |       | [Options](https://docs.docker.com/engine/reference/commandline/service_update/#options) added to the `docker service update` command for all services. You can apply a different value to a particular service via [labels](#labels). |
| GANTRY_UPDATE_TIMEOUT_SECONDS | 0     | Error out if updating of a single service takes longer than the given time. Set to `0` to disable timeout. You can apply a different value to a particular service via [labels](#labels). |

### After updating

| Environment Variable  | Default | Description |
|-----------------------|---------|-------------|
| GANTRY_CLEANUP_IMAGES           | true  | Set to `true` to clean up the updated images on all hosts. Set to `false` to disable the cleanup. Before cleaning up, *Gantry* will try to remove any *exited* and *dead* containers that are using the images. |
| GANTRY_CLEANUP_IMAGES_OPTIONS   |       | [Options](https://docs.docker.com/engine/reference/commandline/service_create/#options) added to the `docker service create` command to create a global job for images removal. You can use this to add a label to the service or the containers. |
| GANTRY_NOTIFICATION_APPRISE_URL |       | Enable notifications on service update with [*Apprise*](https://github.com/caronc/apprise-api). This must point to the notification endpoint (e.g. `http://apprise:8000/notify`) |
| GANTRY_NOTIFICATION_CONDITION   | all   | Valid values are `all` and `on-change`. Specifies the conditions under which notifications are sent. Set to `all` to send notifications every run. Set to `on-change` to send notifications only when there are updates or errors. |
| GANTRY_NOTIFICATION_TITLE       |       | Add an additional message to the notification title. |

## Labels

Labels can be added to services to modify the behavior of *Gantry* for particular services. When *Gantry* sees the following labels on a service, it will modify the Docker command line only for that service. The value on the label overrides the global environment variables.

> NOTE: *Gantry* reads labels on the services not on the containers. The labels need to go to the [deploy](https://docs.docker.com/reference/compose-file/deploy/#labels) section, if you are using docker compose files to setup your services.

| Label  | Description |
|--------|-------------|
| `gantry.auth.config=<configuration>`     | Override [`DOCKER_CONFIG`](https://docs.docker.com/engine/reference/commandline/cli/#environment-variables). See [Authentication](docs/authentication.md). |
| `gantry.services.excluded=true`          | Exclude the services from updating if you are using the default [`GANTRY_SERVICES_EXCLUDED_FILTERS`](#to-select-services). |
| `gantry.manifest.cmd=<command>`          | Override [`GANTRY_MANIFEST_CMD`](#to-check-if-new-images-are-available). |
| `gantry.manifest.options=<string> `      | Override [`GANTRY_MANIFEST_OPTIONS`](#to-check-if-new-images-are-available). |
| `gantry.rollback.on_failure=<boolean>`   | Override [`GANTRY_ROLLBACK_ON_FAILURE`](#to-add-options-to-services-update). |
| `gantry.rollback.options=<string>`       | Override [`GANTRY_ROLLBACK_OPTIONS`](#to-add-options-to-services-update). |
| `gantry.update.jobs=<boolean>`           | Override [`GANTRY_UPDATE_JOBS`](#to-add-options-to-services-update). |
| `gantry.update.options=<string>`         | Override [`GANTRY_UPDATE_OPTIONS`](#to-add-options-to-services-update). |
| `gantry.update.timeout_seconds=<number>` | Override [`GANTRY_UPDATE_TIMEOUT_SECONDS`](#to-add-options-to-services-update). |

## FAQ

[Authentication](docs/authentication.md)

[FAQ](docs/faq.md)

[Migrate from *Shepherd*](docs/migration.md)

## Development

*Gantry* is written to work with `busybox ash` (v1.35+), thus it could run easily in an alpine-based container without additional packages installed. One exception is that the notification feature requires `curl`. *Gantry* is also tested in `bash`.

[shellcheck](https://github.com/koalaman/shellcheck) will run on push to enforce the best practices of writing shell scripts. Some checks are disabled thanks to `busybox ash` supports more features than POSIX `sh`. You can find the list of disabled checks in [.shellcheckrc](.shellcheckrc).

To run `shellcheck` locally:
```
shellcheck src/*.sh tests/*.sh
```

The [tests](./tests/README.md) [folder](./tests) contains end-to-end tests, which cover the majority of the configuration options.

## Contacts

If you have any problems or questions, please contact me through a [GitHub issue](https://github.com/shizunge/gantry/issues).
