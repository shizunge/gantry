# webhook

This example describes how to launch [*Gantry*](https://github.com/shizunge/gantry) via [adnanh/webhook](https://github.com/adnanh/webhook).

## Setup

We leverage a dockerized webhook image [lwlook/webhook](https://hub.docker.com/r/lwlook/webhook) which is based on the offical Docker image. This allows us to launch the *Gantry* service with simple docker commands.

[hooks.json](./hooks.json) defines the webhook's behavior. It parses incoming payloads and transforms them into environment variables like `GANTRY_SERVICES_EXCLUDED`, `GANTRY_SERVICES_EXCLUDED_FILTERS` and `GANTRY_SERVICES_FILTERS`. These variables are then used by [run_gantry.sh](./run_gantry.sh) to control *Gantry* behaviors. which means you can update different services by passing different payloads to the webhook. Refer to the [adnanh/webhook](https://github.com/adnanh/webhook) repository for more advanced webhook configurations, including securing the webhook with `trigger-rule`.

[run_gantry.sh](./run_gantry.sh) is responsible for launching the *Gantry* service.

## Test

Use the following command to deploy the Docker Compose stack that includes the webhook service.

```
docker stack deploy --detach=true --prune --with-registry-auth --compose-file ./docker-compose.yml webhook
```

Use `curl` to send a `POST` request to the webhook endpoint. This request tells the *Gantry* to only update the service named *webhook_webhook*.

```
curl -X POST localhost:9000/hooks/run-gantry -H "Content-Type: application/json"  -d '{"GANTRY_SERVICES_FILTERS":"name=webhook_webhook"}'
```

Check the webhook service logs to confirm if the webhook was triggered correctly.

```
docker service logs webhook_webhook
```

Use the following command to stop the stack.

```
docker stack remove webhook
```
