FROM alpine:3.21.3

LABEL org.opencontainers.image.title=gantry
LABEL org.opencontainers.image.description="Updating docker swarm services"
LABEL org.opencontainers.image.vendor="Shizun Ge"
LABEL org.opencontainers.image.licenses=GPLv3

RUN mkdir -p /gantry

WORKDIR /gantry

# * Add curl to report docker hub rate and for notification.
# * Add tzdata to log timezone correctly.
# * Add coreutils for command `timeout`.
#   The timeout command from coreutils and busybox exhibit different behaviors. Notably, busybox timeout may not reliably report the timeout status of a `docker service update` in some cases, leading to potential inaccuracies.
RUN apk add --update --no-cache curl tzdata coreutils docker-cli docker-cli-buildx

COPY src/* /gantry

ENTRYPOINT ["/gantry/entrypoint.sh"]
