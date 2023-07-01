## Migration from shepherd

*Gantry* started to fix the following problems I found in [*shepherd*](https://github.com/containrrr/shepherd), then it became refactored and totally rewritten, with abundant tests.

* `docker manifest` CLI failed to get the image meta data for some registries.
* High usage of docker hub rate. Getting manifest and then pulling the image double the usage.
* Removing images related: Failure of removing old images will exit and block subsequent updating. `docker rmi` only works for the current host.
* `docker service update` CLI hangs when updating services without running tasks.
* Other UX issues when running it as a script outside the provided container.

Although I have tried to keep backward compatibility, not all configurations in *shepherd* are supported.

This guide helps you migrate from *shepherd* to *gantry* by highlighting the difference between them. Please refer to the [README](../README.md) for the full description of the configurations.

### Renamed configurations

| *Shepherd* Env | Equivalent *Gantry* Env  |
|----------------|---------------|
| HOSTNAME            | GANTRY_NODE_NAME                |
| SLEEP_TIME          | GANTRY_SLEEP_SECONDS            |
| IGNORELIST_SERVICES | GANTRY_SERVICES_EXCLUDED        |
| FILTER_SERVICES     | GANTRY_SERVICES_FILTERS         |
| UPDATE_OPTIONS      | GANTRY_UPDATE_OPTIONS           |
| TIMEOUT             | GANTRY_UPDATE_TIMEOUT_SECONDS   |
| ROLLBACK_OPTIONS    | GANTRY_ROLLBACK_OPTIONS         |
| ROLLBACK_ON_FAILURE | GANTRY_ROLLBACK_ON_FAILURE      |
| APPRISE_SIDECAR_URL | GANTRY_NOTIFICATION_APPRISE_URL |
| REGISTRY_USER       | GANTRY_REGISTRY_USER            |
| REGISTRY_PASSWORD   | GANTRY_REGISTRY_PASSWORD        |
| REGISTRY_HOST       | GANTRY_REGISTRY_HOST            |
| REGISTRIES_FILE     | GANTRY_REGISTRY_CONFIGS_FILE    |

The label on the services to select config to enable authentication is renamed to `gantry.auth.config`.

### Deprecated configurations

| *Shepherd* Env | Workaround |
|----------------|------------|
| VERBOSE                | Use `GANTRY_LOG_LEVEL` |
| WITH_REGISTRY_AUTH     | Manually add `--with-registry-auth` to `GANTRY_UPDATE_OPTIONS` and `GANTRY_ROLLBACK_OPTIONS`. |
| WITH_INSECURE_REGISTRY | Manually add `--insecure` to `GANTRY_MANIFEST_OPTIONS`, `GANTRY_UPDATE_OPTIONS` and `GANTRY_ROLLBACK_OPTIONS`. |
| WITH_NO_RESOLVE_IMAGE  | Manually add `--no-resolve-image` to `GANTRY_UPDATE_OPTIONS` and `GANTRY_ROLLBACK_OPTIONS`. |
| IMAGE_AUTOCLEAN_LIMIT  | Use `GANTRY_CLEANUP_IMAGES`. *Gantry* will only clean up the updated images. |
| RUN_ONCE_AND_EXIT      | Set `GANTRY_SLEEP_SECONDS` to 0. |

### New configurations

| *Gantry* Env  |
|---------------|
| GANTRY_CLEANUP_IMAGES            |
| GANTRY_LOG_LEVEL                 |
| GANTRY_MANIFEST_CMD              |
| GANTRY_MANIFEST_OPTIONS          |
| GANTRY_NOTIFICATION_TITLE        |
| GANTRY_REGISTRY_CONFIG           |
| GANTRY_REGISTRY_CONFIG_FILE      |
| GANTRY_REGISTRY_HOST_FILE        |
| GANTRY_REGISTRY_PASSWORD_FILE    |
| GANTRY_REGISTRY_USER_FILE        |
| GANTRY_SERVICES_EXCLUDED_FILTERS |
| GANTRY_SERVICES_SELF             |
| GANTRY_UPDATE_JOBS               |

### License

*Shepherd* is under [MIT license](https://github.com/containrrr/shepherd/blob/master/LICENSE)

*Gantry* is under [GPL-3.0 license](https://github.com/shizunge/gantry/blob/main/LICENSE)
