# webhook

This example describes how to launch [*Gantry*](https://github.com/shizunge/gantry) via [adnanh/webhook](https://github.com/adnanh/webhook).

## Setup

We start two containers, *Gantry* and [lwlook/webhook](https://hub.docker.com/r/lwlook/webhook) that is a dockerized *adnanh/webhook* image. They communicate via a shared volume. *Gantry* watches a file in the shared volume, while *webhook* changes that file to trigger an update.

[hooks.json](./hooks.json) defines the webhook's behavior. It parses incoming payloads and transforms them into environment variables like `GANTRY_SERVICES_EXCLUDED`, `GANTRY_SERVICES_EXCLUDED_FILTERS` and `GANTRY_SERVICES_FILTERS`. These variables are then used by [run_gantry.sh](./run_gantry.sh) to control *Gantry* behaviors. which means you can update different services by passing different payloads to the webhook. Refer to the [adnanh/webhook](https://github.com/adnanh/webhook) repository for more advanced webhook configurations, including securing the webhook with `trigger-rule`.

[run_gantry.sh](./run_gantry.sh) is responsible for updating `GANTRY_TRIGGER_PATH` that *Gantry* is watching.

## Test

Use the following command to deploy the Docker Compose stack that includes the webhook service.

```
docker stack deploy --detach=true --prune --with-registry-auth --compose-file ./docker-compose.yml webhook
```

Use `curl` to send a `POST` request to the webhook endpoint. This request tells the *Gantry* to only update the service named *webhook_webhook*.

```
curl -v -X POST localhost:9000/hooks/run-gantry -H "Content-Type: application/json"  -d '{"GANTRY_SERVICES_FILTERS":"name=webhook_webhook"}'
```

Check the service logs to confirm if the webhook and update was triggered correctly.

```
docker service logs webhook_webhook
docker service logs webhook_gantry
```

Use the following command to stop the stack.

```
docker stack remove webhook
```
