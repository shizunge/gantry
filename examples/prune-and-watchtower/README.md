# prune and watchtower

This example run `docker system prune` and *watchtower* before updating docker swarm services.

* [`docker system prune`](https://docs.docker.com/engine/reference/commandline/system_prune/) removes all unused containers, networks and images.
* [*watchtower*](https://github.com/containrrr/watchtower) updates standalone docker containers.
* [*gantry*](https://github.com/shizunge/gantry) updates docker swarm services.

