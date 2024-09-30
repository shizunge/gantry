# notification

This example demonstrates how [*Gantry*](https://github.com/shizunge/gantry) sends notification via [apprise](https://github.com/caronc/apprise-api).

Start the stack via the following command.

```
docker stack deploy --detach=true --prune --with-registry-auth --compose-file ./docker-compose.yml notification
```

> NOTE: This stack updates services every minute and it consumes Docker Hub rates.

In this example, besides *Gantry* and *Apprise*, there is a fake SMTP server to receive the notifications, which you can watch at `http://localhost:8025` in your browser.

Use the following command to stop the stack.

```
docker stack remove notification
```
