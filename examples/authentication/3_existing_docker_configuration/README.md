# Using an existing Docker client configuration

## 1. Share Docker configuration between host and *Gantry* container

Before starting *Gantry*, you need firstly to login to `registry.example.com` on the host.

```
docker login --password "${password_place_holder}" --username "${username_place_holder}" "registry.example.com"
```

> NOTE: `sudo docker login` stores credentials to `/root/.docker`, while `docker login` stores credentials to `${HOME}/.docker`.

Then replace `${DOCKER_CONFIG_ON_HOST}` in the [compose file](docker-compose.yml) with `/home/my_host_user/.docker`.

Then start *Gantry*.

## 2. Use different Docker configurations on the host and in the *Gantry* container.

Instead of using the default Docker configuration, you can explicitly specify a configuration location. As a result, we can use different configurations on host and inside the container.

```
docker --config /my/config/path/ login --password "${password_place_holder}" --username "${username_place_holder}" "registry.example.com"
```

In this case, replace `${DOCKER_CONFIG_ON_HOST}` in the [compose file](docker-compose.yml) with `/my/config/path` correspondingly.

Then start *Gantry*.
