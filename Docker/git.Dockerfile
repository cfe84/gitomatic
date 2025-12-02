FROM alpine
RUN apk add --no-cache git bash
SHELL ["/bin/bash", "-c"]
WORKDIR /src