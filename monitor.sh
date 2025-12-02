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
        IFS=':' read -r FOLDER HEAD OLDREV NEWREV < $event_file
        rm -f "$event_file"

        REPO="$REPO_ROOT$FOLDER"
        IS_BARE=`git --git-dir="$REPO" rev-parse --is-bare-repository | grep true`
        if $IS_BARE; then
            LOG_FOLDER="$REPO/build/logs"
        else
            LOG_FOLDER="$EVENTS_DIR/logs"
        fi
        mkdir -p "$LOG_FOLDER"
        LOG_FILE="$LOG_FOLDER/$(basename "$event_file").log"
        echo -e "\n##########################################################################################################################################################\n\nRepo $REPO - Revision $HEAD - `date`" > "$LOG_FILE"
        PIPELINES=`./find-pipelines.sh "$REPO" "$HEAD"`
        if [ -z "$PIPELINES" ]; then
            echo "No pipelines found in $REPO. Exiting." >> "$LOG_FILE"
            rm -f "$event_file"
            continue
        fi
        for pipeline in $PIPELINES; do
            echo -e "\n------------------------------------------\n--- 🏗️ Running pipeline: $pipeline\n------------------------------------------\n" >> "$LOG_FILE"
            bash run-pipeline.sh "$pipeline" "$REPO" "$HEAD" "$OLDREV" "$NEWREV" >> "$LOG_FILE" 2>&1

            echo -e "\n------------------------------------------\n--- 🏗️ End of pipeline: $pipeline\n------------------------------------------\n\n\n\n\n\n" >> "$LOG_FILE"
        done
    done
done
