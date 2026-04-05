# Authentication

## 1. Providing credentials

To get started, provide your registry credentials to Gantry using one of the following methods. You only need to use one, though you may use them in combination.

*Gantry* creates or updates the [Docker client configuration](https://docs.docker.com/engine/reference/commandline/cli/#configuration-files) to store credentials based on the values set via `GANTRY_REGISTRY_CONFIG`, `GANTRY_REGISTRY_CONFIG_FILE` or `GANTRY_REGISTRY_CONFIGS_FILE`. These values specify the Docker client configuration directories, each of which can be either a relative path (to *Gantry*'s working directory) or an absolute path. The default Docker client configuration directory is `${HOME}/.docker`. It is `/root/.docker` for a *Gantry* container from images of this repository under the default user `root`. You can change the default location globally via environment variable `DOCKER_CONFIG`.

### 1.1. Single registry

When logging in to a single registry, you can use the environment variables `GANTRY_REGISTRY_USER`, `GANTRY_REGISTRY_PASSWORD`, `GANTRY_REGISTRY_HOST` and `GANTRY_REGISTRY_CONFIG` to provide the authentication information. You may also use the `*_FILE` variants to pass the information through files. The files can be added to the service via [Docker secret](https://docs.docker.com/engine/swarm/secrets/).

`GANTRY_REGISTRY_HOST` is optional. Use `GANTRY_REGISTRY_HOST` when you are not using Docker Hub.

`GANTRY_REGISTRY_CONFIG` is optional. It specifies the directory for [Docker client configuration](https://docs.docker.com/engine/reference/commandline/cli/#configuration-files), i.e. `<configuration>`. Use it when you want to enable authentication for only selected services. When empty, *Gantry* logs in using the default Docker client configuration. When set, *Gantry* uses the specified path as the Docker client configuration directory.

> NOTE: *Gantry* uses `GANTRY_REGISTRY_PASSWORD` and `GANTRY_REGISTRY_USER` to obtain Docker Hub rate when `GANTRY_REGISTRY_HOST` is empty or `docker.io`. Their `_FILE` variants are also supported. If either value is empty, *Gantry* reads the Docker Hub rate for anonymous users. Monitoring Docker Hub rate helps diagnose failures caused by exceeding the rate limit.

### 1.2. Multiple registries

If the images of services are hosted on multiple registries that are required authentication, you should provide a file that contains configurations to the *Gantry* and set `GANTRY_REGISTRY_CONFIGS_FILE` correspondingly. You can use [Docker secret](https://docs.docker.com/engine/swarm/secrets/) to provision that file. The file must be in the following format:

* Each line should contain 4 columns, which are either `<TAB>` or `<SPACE>` separated. The columns are

```
<configuration> <registry> <user> <password>
```

> * configuration: The directory path for [Docker client configuration](https://docs.docker.com/engine/reference/commandline/cli/#configuration-files).
> * registry: The registry to authenticate against, e.g. `docker.io`.
> * user: The user name to authenticate as.
> * password: The password to authenticate with.

* Lines starting with `#` are comments.
* Empty lines, comment lines and invalid lines are ignored.

You can use `GANTRY_REGISTRY_CONFIGS_FILE` together with other authentication environment variables.

You can log in to multiple registries using a single Docker client configuration. For example you can set all the `<configuration>` to the default Docker client configuration location `/root/.docker`.

You can log in to the same registry with multiple credentials. When different services need to authenticate to the same registry under different usernames, each service will need its own Docker client configuration, and you need to [explicitly select configurations](#21-explicitly-select-configurations) in the following step.

### 1.3. Using an existing Docker client configuration

When you run *Gantry* as a Docker service, you can use an existing Docker client configuration from the host machines for authorization, through the following steps.

1. Log into registries on the host using [`docker login`](https://docs.docker.com/reference/cli/docker/login/). The [default configuration](https://docs.docker.com/reference/cli/docker/#configuration-files) locates at `${HOME}/.docker`. You can [change the `.docker` directory](https://docs.docker.com/reference/cli/docker/#change-the-docker-directory).
2. Mount the Docker client configuration directory from the host to the *Gantry* container, or mount only the `config.json` via [Docker secret](https://docs.docker.com/engine/swarm/secrets/).

> NOTE: The Docker client configuration directory must be writable because [`docker buildx imagetools inspect`](https://docs.docker.com/engine/reference/commandline/buildx_imagetools_inspect/) writes data to `${DOCKER_CONFIG}/buildx`. If you need read-only mounts, mount only the file `config.json` and leave the directory writable. Alternatively, set `GANTRY_MANIFEST_CMD` to `manifest` to avoid writing to the Docker client configuration directory. See also [Which `GANTRY_MANIFEST_CMD` to use](../docs/faq.md#which-gantry_manifest_cmd-to-use).

There are additional requirements:

* If the mounted Docker configuration location inside *Gantry* container is **not** the default location, you must [explicitly select configurations](#21-explicitly-select-configurations) in the following step. `<configuration>` is the directory inside the *Gantry* container containing `config.json`.
* Add `--with-registry-auth` to `GANTRY_UPDATE_OPTIONS` manually.

## 2. Selecting Docker client configurations for services

Once credentials are in place, you then specify which service uses which configuration.

*Gantry* appends `--config <configuration>` to the Docker commands for that service, overriding the default Docker client configuration location, when the `<configuration>` is not the default Docker client configuration location.

## 2.1. Explicitly select configurations

You can do either or both of the following:

* Set the environment variable `DOCKER_CONFIG` in the environment where *Gantry* is running (e.g. the *Gantry* container) to apply a configuration location `<configuration>` globally across all services. This changes the default Docker client configuration location.
* Add the label `gantry.auth.config=<configuration>` to a service being updated, to specify its Docker client configuration. This overrides the globally setting for a particular service.

## 2.2. Automatically select configurations

*Gantry* will try to automatically find the Docker client configurations set in [1.1. Single registry](#11-single-registry) and [1.2. Multiple registries](#12-multiple-registries), to minimize the effort specifying `gantry.auth.config=<configuration>` on each service. You don't need to set `gantry.auth.config=<configuration>` on services for the following cases:

* For a given registry, there is only one set of credential.
* The `<configuration>` is same as the default Docker client configuration location.

If you provide credentials via [1.3. Using an existing Docker client configuration](#13-using-an-existing-docker-client-configuration) and mount the host configuration file to the default Docker client configuration location inside the *Gantry* container, *Gantry* will use those credentials automatically.

## 2.3. Precedence

*Gantry* uses the Docker client configuration for a service in the following orders.

1. Value explicitly specified by the label `gantry.auth.config=<configuration>` on the service.
2. `<configuration>` set in [1.1. Single registry](#11-single-registry) and [1.2. Multiple registries](#12-multiple-registries), [found automatically](#22-automatically-select-configurations) for the service.
3. Value explicitly specified by the environment variable `DOCKER_CONFIG` that changes the default Docker client configuration location.
4. The default location `${HOME}/.docker`, which is `/root/.docker` for a *Gantry* container from images of this repository under the default user `root`.

## 3. Additional options

### 3.1. Adding `--with-registry-auth`

Without `--with-registry-auth`, the service, whose registry requires authentication, will be [updated to an image without digest](https://github.com/shizunge/gantry/issues/53#issuecomment-2348376336), and you will get a warning *"image \<image\> could not be accessed on a registry to record its digest. Each node will access \<image\> independently, possibly leading to different nodes running different versions of the image."*

*Gantry* automatically adds `--with-registry-auth` to the `docker service update` command for services for the following cases.

* when *Gantry* finds the label `gantry.auth.config=<configuration>` on the service.
* when *Gantry* finds `<configuration>` [automatically for the service](#22-automatically-select-configurations).

If you don't see the above warning, your setup is fine. You can manually add `--with-registry-auth` to `GANTRY_UPDATE_OPTIONS` if it is not added automatically for your case.

## 4. Examples

See [examples](../examples/authentication).
