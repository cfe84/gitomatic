#!/bin/bash

cd $(dirname "$0")

if [ -z "$EVENTS_DIR" ] || [ -z "$REPO_ROOT" ]; then
  echo "EVENTS_DIR and REPO_ROOT must be set"
  exit 1
fi

mkdir -p "$EVENTS_DIR/logs"

while true; do
    if [ "$OSTYPE" == "darwin24" ]; then
        # macOS does not have inotifywait. Just sleep.
        sleep 1
    else
        inotifywait -e create --format '%f' "$EVENTS_DIR"
    fi
    for event_file in "$EVENTS_DIR"/*; do
        [ -d "$event_file" ] && continue
        echo "Processing event file: $event_file"
        IFS=':' read -r FOLDER HEAD < $event_file
        LOG_FILE="$EVENTS_DIR/logs/$(basename "$event_file").log"
        echo "Repo $REPO_ROOT/$FOLDER - Revision $HEAD" > "$LOG_FILE"
        bash run-pipeline.sh "$REPO_ROOT/$FOLDER" "$HEAD" >> "$LOG_FILE" 2>&1
        rm -f "$event_file"
    done
done