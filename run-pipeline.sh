#!/bin/bash

cd $(dirname "$0")
WD=`pwd`

PIPELINE="$1"
REPO="$2"
REF="$3"
OLDREV="$4"
NEWREV="$5"

cd "$REPO"

echo "🕕 Starting pipeline at `date` $PWD"
SECONDS=0

TMP_FOLDER=`mktemp -d`
echo -e "📂 Using temp folder: $TMP_FOLDER\n"

trap "echo -e \"\n🧹 Cleaning up temp folder\n\";rm -rf $TMP_FOLDER/*" EXIT
ARTIFACTS_FOLDER="$TMP_FOLDER/artifacts"
CLONE_FOLDER="$TMP_FOLDER/src"
PIPELINE_DEFINITION="$TMP_FOLDER/pipeline.ini"
SRC_ENV_FILE="$REPO/build/env"
ENV_FILE="$TMP_FOLDER/env"

mkdir -p "$ARTIFACTS_FOLDER"

echo -e "\n===== 📄 Loading build definition =====\n"
git show "$REF:$PIPELINE" > "$PIPELINE_DEFINITION"
source "$WD/parse-ini.sh" "$PIPELINE_DEFINITION"

if [ -n "${FILTER_refs}" ]; then
    if [[ "$REF" != ${FILTER_refs} ]]; then
        echo "🗑️ Ref '$REF' does not match filter '${FILTER_refs}'. Exiting pipeline."
        exit 0
    fi
    echo -e "👍 Ref '$REF' matches filter '${FILTER_refs}'."
fi

if [ -n "${FILTER_files}" ]; then
    FILES_CHANGED=`git diff --name-only $OLDREV $NEWREV | grep "${FILTER_files}" | tr '\n' ' '`
    if [ -z "$FILES_CHANGED" ]; then
        echo "🛑 No changed files match filter '${FILTER_files}'. Exiting pipeline."
        exit 0
    fi
    echo -e "👍 Changed files matching filter '${FILTER_files}': $FILES_CHANGED\n"
fi
echo "🚀 Running pipeline! Loaded ${INI_SECTION_COUNT} steps."

echo -e "\n===== 💾 Cloning $REPO @ $REF =====\n"
git clone --revision "$REF" "file://$REPO" "$CLONE_FOLDER"

if [ -f "$SRC_ENV_FILE" ]; then
    echo -e "\n===== 📂 Copying environment file =====\n"
    cp "$SRC_ENV_FILE" "$ENV_FILE"
fi

STEP=1

while [ $STEP -le $INI_SECTION_COUNT ]; do
	SECTION=INI_SECTION_${STEP}
	SECTION_NAME=${!SECTION}
	TASK_VAR=${SECTION}_task
    TASK=${!TASK_VAR}
	IMAGE_VAR=${SECTION}_image
	IMAGE=${!IMAGE_VAR}
    ADDITIONAL_REPO_VAR=${SECTION}_repo
    ADDITIONAL_REPO=${!ADDITIONAL_REPO_VAR}

	echo -e "\n===== ⚙️ $SECTION_NAME ($STEP/$INI_SECTION_COUNT) =====\n"

    if [ -n "$TASK" ]; then
        TASK="$WD/tasks/$TASK"
        if [ "$ALLOW_TASKS" != "true" ]; then
            echo "🚨 ALLOW_TASKS is not set to true. Pipeline is instructing to run $TASK but I cannot run local tasks. Terminating pipeline."
            exit 1
        fi
        if [ ! -f "$TASK" ]; then
            echo "🚨 Task file '$TASK' not found. Terminating pipeline."
            exit 1
        else
            echo "💡 Found task file: $TASK"
        fi
        PARAMETERS_VAR=${SECTION}_parameters
        PARAMETERS=${!PARAMETERS_VAR}
        echo -e "\n--- 🚀 Running task: $TASK ---\n"
        "$TASK" $PARAMETERS
    elif [ -n "$ADDITIONAL_REPO" ]; then
        ARTIFACT_VAR="${SECTION}_artifact"
        ARTIFACT="${!ARTIFACT_VAR}"
        ADDITIONAL_REPO_CLONE_PATH="$ARTIFACTS_FOLDER/$ARTIFACT"
        REVISION_VAR="${SECTION}_revision"
        REVISION=${!REVISION_VAR}
        if [ -n "$REVISION" ]; then
            REVISION="--revision \"$REVISION\""
        fi
        echo -e "\n--- 📦 Cloning additional repo $ARTIFACT: $ADDITIONAL_REPO ---\n"
        git clone "file://$REPO_ROOT/$ADDITIONAL_REPO" $REVISION "$ADDITIONAL_REPO_CLONE_PATH"
        if [ $? -ne 0 ]; then
            echo -e "\n 🚨 Cloning additional repo failed. Terminating pipeline 🚨 \n"
            exit 1
        else
            echo -e "\n--- ✅ Additional repo $ADDITIONAL_REPO cloned successfully ---\n"
        fi
    elif [ -n "$IMAGE" ]; then
        echo -e "\n--- 🐳 Running image: $IMAGE ---\n"
    	ARTIFACTS_VAR=${SECTION}_artifacts
        ARTIFACTS=${!ARTIFACTS_VAR}
        SCRIPT_VAR=${SECTION}_script
        SCRIPT=${!SCRIPT_VAR}
        ENV_VAR=${SECTION}_env
        ENV=${!ENV_VAR}
        WORKDIR_VAR=${SECTION}_workdir
        WORKDIR=${!WORKDIR_VAR}
        ENTRYPOINT_VAR=${SECTION}_entrypoint
        ENTRYPOINT=${!ENTRYPOINT_VAR}

        COMMAND="docker run --rm -v \"$CLONE_FOLDER:/src\" -e REF=\"$REF\" -e REPO=\"$REPO\" "

        IFS=';' read -ra pairs <<< "$ARTIFACTS"
        for pair in "${pairs[@]}"; do
            IFS=':' read -r NAME MOUNTING_POINT <<< "$pair"
            ART_FOLDER="$ARTIFACTS_FOLDER/$NAME"
            mkdir -p "$ART_FOLDER"
            COMMAND="$COMMAND -v \"$ART_FOLDER:$MOUNTING_POINT\""
            echo "- Mounting artifact '$NAME' at '$MOUNTING_POINT'"
        done

        if [ -n "$WORKDIR" ]; then
            echo "- Setting working directory to: $WORKDIR"
            COMMAND="$COMMAND -w \"$WORKDIR\""
        fi

        if [ -f "$ENV_FILE" ]; then
            echo "- Using env file: $ENV_FILE"
            COMMAND="$COMMAND --env-file \"$ENV_FILE\""
        fi

        if [ -f "$ENTRYPOINT" ]; then
            echo "- Using custom entrypoint: $ENTRYPOINT"
            COMMAND="$COMMAND --entrypoint \"$ENTRYPOINT\""
        fi

        if [ -n "$ENV" ]; then
            # env_vars are separated by \n literals.
            ENV=$(printf "%b" "$ENV")
            IFS=$'\n' read -r -d '' -a env_vars <<< "$ENV"$'\0'
            for env_var in "${env_vars[@]}"; do
                echo "- Setting env var: $env_var"
                COMMAND="$COMMAND -e $env_var"
            done
        fi

        if [ "$IMAGE" == "build-docker-image" ]; then
            echo "- Mounting Docker socket"
            COMMAND="$COMMAND -v /var/run/docker.sock:/var/run/docker.sock "
        fi

        COMMAND="$COMMAND \"$IMAGE\""
        if [ -n "$SCRIPT" ]; then
            echo "- Using custom script for image $IMAGE"
            COMMAND="$COMMAND \"$SCRIPT\""
        else
            echo "- No script defined for image $IMAGE. Using default entrypoint."
        fi

        echo $COMMAND
        eval $COMMAND
    else
        echo "🚨 Neither task nor image defined for section '$SECTION_NAME'. Terminating pipeline"
        exit 1
    fi
    if [ $? -ne 0 ]; then
        echo -e "\n 🚨 Command failed. Terminating pipeline 🚨 \n"
        exit 1
    else
        echo -e "\n--- ✅ Step $SECTION_NAME completed successfully ---\n"
    fi

	STEP=$((STEP+1))
done

echo -e "\n===== ✅ Build succeeded =====\n"
echo "🕑 Finished at `date` in $SECONDS seconds"
