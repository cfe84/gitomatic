#!/bin/bash

cd $(dirname "$0")
WD=`pwd`

PIPELINE="$1"
REPO="$2"
REF="$3"

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
        echo "❌ Ref '$REF' does not match filter '${FILTER_refs}'. Exiting pipeline."
        exit 0
    fi
    echo -e "✔️ Ref '$REF' matches filter '${FILTER_refs}'."
fi

if [ -n "${FILTER_files}" ]; then
    echo "git diff --name-only $REF~1 $REF | grep \"${FILTER_files}\" | tr '\n' ' '"
    FILES_CHANGED=`git diff --name-only $REF~1 $REF | grep "${FILTER_files}" | tr '\n' ' '`
    if [ -z "$FILES_CHANGED" ]; then
        echo "❌ No changed files match filter '${FILTER_files}'. Exiting pipeline."
        exit 0
    fi
    echo -e "✔️ Changed files matching filter '${FILTER_files}': $FILES_CHANGED\n"
fi
echo "Loaded ${INI_SECTION_COUNT} steps."

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
	IMAGE_VAR=${SECTION}_image
	IMAGE=${!IMAGE_VAR}
	ARTIFACTS_VAR=${SECTION}_artifacts
	ARTIFACTS=${!ARTIFACTS_VAR}
	SCRIPT_VAR=${SECTION}_script
	SCRIPT=${!SCRIPT_VAR}

	echo -e "\n===== ⚙️ $SECTION_NAME ($STEP/$INI_SECTION_COUNT) =====\n"

    if [ ! -f "$CLONE_FOLDER/$SCRIPT" ]; then
        echo -e "\n 🚨 Script $SCRIPT not found. Terminating pipeline 🚨 \n"
        exit 1
    fi

	COMMAND="docker run --rm -v \"$CLONE_FOLDER:/src\" -e REF=\"$REF\" -e REPO=\"$REPO\" "

    IFS=';' read -ra pairs <<< "$ARTIFACTS"
    for pair in "${pairs[@]}"; do
        IFS=':' read -r NAME MOUNTING_POINT <<< "$pair"
		ART_FOLDER="$ARTIFACTS_FOLDER/$NAME"
		mkdir -p "$ART_FOLDER"
        COMMAND="$COMMAND -v \"$ART_FOLDER:$MOUNTING_POINT\""
    done

    if [ -f "$ENV_FILE" ]; then
        COMMAND="$COMMAND --env-file \"$ENV_FILE\""
    fi

    if [ "$IMAGE" == "build-docker-image" ]; then
        COMMAND="$COMMAND -v /var/run/docker.sock:/var/run/docker.sock"
    fi

	COMMAND="$COMMAND \"$IMAGE\" \"$SCRIPT\""
	echo $COMMAND
	eval $COMMAND
	if [ $? -ne 0 ]; then
		echo -e "\n 🚨 Command failed. Terminating pipeline 🚨 \n"
		exit 1
	fi

	STEP=$((STEP+1))
done

echo -e "\n===== ✅ Build succeeded =====\n"
echo "🕑 Finished at `date` in $SECONDS seconds"
