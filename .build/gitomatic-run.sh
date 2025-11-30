#!/bin/bash

if [ -n "$GITOMATIC_PREVENT_RUN" ]; then
    echo "GITOMATIC_PREVENT_RUN=$GITOMATIC_PREVENT_RUN => not starting"
    exit 0
fi

echo -e "\n========\nStarting gitomatic container\n========\n"

if [ -z "$EVENTS_DIR" ]; then
    echo "EVENTS_DIR variable not set. Aborting"
    exit 1
fi

if [ -z "$REPO_ROOT" ]; then
    echo "REPO_ROOT variable not set. Aborting"
    exit 1
fi

echo "Stop and remove existing gitomatic container if any"

docker stop gitomatic && docker rm gitomatic

echo "Run gitomatic container"
docker run -d \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v $EVENTS_DIR:/events \
    -v $REPO_ROOT:/repos \
    -v /tmp:/tmp \
    -e EVENTS_DIR=/events \
    -e REPO_ROOT=/repos \
    -e DOCKER_API_VERSION=1.41.0 \
    --name gitomatic \
    --restart unless-stopped \
    gitomatic

echo -e "\n========\ngitomatic container started\n========\n"
