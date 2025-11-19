#!/bin/bash

cd $(dirname "$0")

if [ -z "$EVENTS_DIR" ]; then
  echo "EVENTS_DIR must be set"
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
        REPO="$REPO_ROOT$FOLDER"
        echo "Repo $REPO - Revision $HEAD" > "$LOG_FILE"
        PIPELINES=`./find-pipelines.sh "$REPO" "$HEAD"`
        if [ -z "$PIPELINES" ]; then
            echo "No pipelines found. Exiting." >> "$LOG_FILE"
            rm -f "$event_file"
            continue
        fi
        for pipeline in $PIPELINES; do
            echo -e "\n------------------------------------------\n--- 🏗️ Running pipeline: $pipeline\n------------------------------------------\n" >> "$LOG_FILE"
            bash run-pipeline.sh "$pipeline" "$REPO" "$HEAD" >> "$LOG_FILE" 2>&1
        done
        rm -f "$event_file"
    done
done