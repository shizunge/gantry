FROM alpinelinux/docker-cli:latest

LABEL org.opencontainers.image.title=gantry
LABEL org.opencontainers.image.description="Updating docker swarm services"
LABEL org.opencontainers.image.vendor="Shizun Ge"
LABEL org.opencontainers.image.licenses=GPLv3

RUN mkdir -p /gantry

WORKDIR /gantry

RUN apk add --update --no-cache curl tzdata

COPY src/* /gantry

ENTRYPOINT ["/gantry/entrypoint.sh"]
