#!/bin/bash

REPO="$1"
HEAD="$2"

cd "$REPO"

git remote -v | grep '(push)' | while read -r line ; do
    REMOTE_NAME=$(echo $line | awk '{print $1}')
    REMOTE_URL=$(echo $line | awk '{print $2}')
    
    echo -e "\n===== 🚚 Pushing to remote '$REMOTE_NAME' ($REMOTE_URL) =====\n"
    git push "$REMOTE_NAME" "$HEAD" --force
done
