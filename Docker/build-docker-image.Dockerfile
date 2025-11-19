FROM docker:cli-alpine
RUN apk add --no-cache \
    bash \
    && rm -rf /var/cache/apk/*
SHELL ["/bin/bash", "-c"]
WORKDIR /src