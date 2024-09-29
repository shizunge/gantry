# notification

This example demonstrates how [*Gantry*](https://github.com/shizunge/gantry) sends notification via [apprise](https://github.com/caronc/apprise-api).

Start the stack via the following command.

```
docker stack deploy --detach=true --prune --with-registry-auth --compose-file ./docker-compose.yml notification
```

Then you can open `http://localhost:8025` in your browser to watch notifications.

> NOTE: This stack updates services every minute and it consumes Docker Hub rates.
