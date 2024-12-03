# Authentication

## Single registry

If you only need to login to a single registry, you can use the environment variables `GANTRY_REGISTRY_USER`, `GANTRY_REGISTRY_PASSWORD`, `GANTRY_REGISTRY_HOST` and `GANTRY_REGISTRY_CONFIG` to provide the authentication information. You may also use the `*_FILE` variants to pass the information through files. The files can be added to the service via [Docker secret](https://docs.docker.com/engine/swarm/secrets/).

`GANTRY_REGISTRY_HOST` is optional. Use `GANTRY_REGISTRY_HOST` when you are not using Docker Hub.

`GANTRY_REGISTRY_CONFIG` is optional. Use `GANTRY_REGISTRY_CONFIG` when you want to enable authentication for only selected services. When `GANTRY_REGISTRY_CONFIG` is empty, *Gantry* login using the default [Docker configuration](https://docs.docker.com/engine/reference/commandline/cli/#configuration-files). When `GANTRY_REGISTRY_CONFIG` is set, *Gantry* use it as the path of the Docker configuration folder.

> NOTE: *Gantry* uses `GANTRY_REGISTRY_PASSWORD` and `GANTRY_REGISTRY_USER` to obtain Docker Hub rate when `GANTRY_REGISTRY_HOST` is empty or `docker.io`. You can also use their `_FILE` variants. If either password or user is empty, *Gantry* reads the Docker Hub rate for anonymous users.

## Multiple registries

If the images of services are hosted on multiple registries that are required authentication, you should provide a configuration file to the *Gantry* and set `GANTRY_REGISTRY_CONFIGS_FILE` correspondingly. You can use [Docker secret](https://docs.docker.com/engine/swarm/secrets/) to provision the configuration file. The configuration file must be in the following format:

* Each line should contain 4 columns, which are either `<TAB>` or `<SPACE>` separated. The columns are

```
<configuration> <host> <user> <password>
```

> * configuration: The location of the [client configuration files](https://docs.docker.com/engine/reference/commandline/cli/#configuration-files) where authentication stores. It could be either a relative path or an absolute path.
> * host: the registry to authenticate against, e.g. docker.io.
> * user: the user name to authenticate as.
> * password: the password to authenticate with.

* Lines starting with  `#` are comments.
* Empty lines, comment lines and invalid lines are ignored.

You can use `GANTRY_REGISTRY_CONFIGS_FILE` together with other authentication environment variables.

You can login to multiple registries using the same Docker configuration. For example you can set all the configurations to the default Docker configuration location `${HOME}/.docker/`. However if you login to the same registry with different user names for different services, you need to use different Docker configurations.

## Selecting Docker configurations for services

If you login to a single registry using `GANTRY_REGISTRY_USER`, `GANTRY_REGISTRY_PASSWORD` and `GANTRY_REGISTRY_HOST` **without** setting `GANTRY_REGISTRY_CONFIG`, the default Docker configuration is used. When using the default Docker configuration, you don't need to set anything extra for authentication.

 *Gantry* creates or updates the docker configurations based on the locations set via `GANTRY_REGISTRY_CONFIG`, `GANTRY_REGISTRY_CONFIG_FILE` or `GANTRY_REGISTRY_CONFIGS_FILE`. They could be same as the the default Docker configuration location. When using the default Docker configuration, you don't need to set anything extra for authentication.

The default Docker configuration location is `/root/.docker/` inside the container created based on the image built from this repository, because the default user is `root`. You can use environment variable [`DOCKER_CONFIG`](https://docs.docker.com/engine/reference/commandline/cli/#environment-variables) to explicitly set the default docker configuration location, which applies to all docker commands, i.e. to all services.

Optionally you can use different configurations for different services, for example when you want to login to the same registry with different user names. In this case, besides using different configuration values in `GANTRY_REGISTRY_CONFIG` and `GANTRY_REGISTRY_CONFIG_FILE`, you need to add the label `gantry.auth.config=<configuration>` on the particular services to tell which Docker configuration to use for authentication. When *Gantry* finds the label `gantry.auth.config=<configuration>` on services, it adds `--config <configuration>` to the Docker commands for the corresponding services to overrides the default configuration location.

## Adding `--with-registry-auth`

*Gantry* automatically adds `--with-registry-auth` to the `docker service update` command for services for the following cases.

* when *Gantry* finds the label `gantry.auth.config=<configuration>` on the service.
* when *Gantry* logs in with the default Docker configuration.
  * when `GANTRY_REGISTRY_USER`, `GANTRY_REGISTRY_PASSWORD` are set, while `GANTRY_REGISTRY_CONFIG` is empty.
  * when the configuration from `GANTRY_REGISTRY_CONFIG` or `GANTRY_REGISTRY_CONFIGS_FILE` is same as the default Docker configuration location `${HOME}/.docker/` or the location specified by `DOCKER_CONFIG`.

You can manually add `--with-registry-auth` to `GANTRY_UPDATE_OPTIONS` if it is not added automatically for your case. When `--with-registry-auth` is missing but the registry requires authentication, the service will be [updated to an image without digest](https://github.com/shizunge/gantry/issues/53#issuecomment-2348376336), and you will get a warning *"image \<image\> could not be accessed on a registry to record its digest. Each node will access \<image\> independently, possibly leading to different nodes running different versions of the image."*

## Using an existing Docker configuration

You can use an existing Docker configuration from the host machines for authorization when you run *Gantry* as a Docker service. You need to do the followings.

* Log into registries on the host using [`docker login`](https://docs.docker.com/reference/cli/docker/login/). The [default configuration](https://docs.docker.com/reference/cli/docker/#configuration-files) locates at `${HOME}/.docker/`. You can [change the `.docker` directory](https://docs.docker.com/reference/cli/docker/#change-the-docker-directory).
* Mount the Docker configuration directory from the host to the container. You could just mount the `config.json` file using [Docker secret](https://docs.docker.com/engine/swarm/secrets/).
* Set the environment variable `DOCKER_CONFIG` on the *Gantry* container to specify the location of the Docker configuration folder inside the container. You can skip this step when you mount the folder to the default Docker configuration location `/root/.docker/` inside the container.
* Add `--with-registry-auth` to `GANTRY_UPDATE_OPTIONS` manually.

> Note that [`docker buildx imagetools inspect`](https://docs.docker.com/engine/reference/commandline/buildx_imagetools_inspect/) writes data to the Docker configuration folder `${DOCKER_CONFIG}/buildx`, which therefore needs to be writable. If you want to use `buildx` and mount the configuration files read-only, you could just mount the file `config.json` and leave the folder writeable. If you have to mount the entire folder read-only, you can set `GANTRY_MANIFEST_CMD` to `manifest` to avoid writing to the Docker configuration folder. Also see [Which `GANTRY_MANIFEST_CMD` to use](../docs/faq.md#which-gantry_manifest_cmd-to-use).
