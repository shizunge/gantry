FROM alpine:3.23.4

LABEL org.opencontainers.image.title=gantry
LABEL org.opencontainers.image.description="Updating docker swarm services"
LABEL org.opencontainers.image.vendor="Shizun Ge"
LABEL org.opencontainers.image.licenses=GPLv3

RUN mkdir -p /gantry

WORKDIR /gantry

# * Add curl to report docker hub rate and for notification.
# * Add tzdata to log timezone correctly.
# * Add coreutils for command `timeout`.
# * Add inotify-tools for command `inotifywait`.
#   The timeout command from coreutils and busybox exhibit different behaviors. Notably, busybox timeout may not reliably report the timeout status of a `docker service update` in some cases, leading to potential inaccuracies.
RUN apk add --update --no-cache docker-cli docker-cli-buildx curl tzdata coreutils inotify-tools

COPY src/* /gantry

ENTRYPOINT ["/gantry/entrypoint.sh"]
