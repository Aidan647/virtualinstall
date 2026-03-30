# syntax=docker/dockerfile:1.7
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked,id=shared-apt \
    --mount=type=cache,target=/var/lib/apt,sharing=locked,id=shared-apt \
    apt-get update \
    && apt-get install -y --no-install-recommends \
        apt \
        ca-certificates \
        dpkg

WORKDIR /work

COPY docker-build.sh /usr/local/bin/docker-build.sh
RUN chmod +x /usr/local/bin/docker-build.sh

ENTRYPOINT ["/usr/local/bin/docker-build.sh"]
