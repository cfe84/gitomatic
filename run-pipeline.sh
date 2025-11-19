#!/bin/bash

cd $(dirname "$0")
WD=`pwd`

REPO="$1"
HEAD="$2"

cd "$REPO"
CONTAINS_PIPELINE=`git ls-tree $HEAD .build/pipeline.ini`

if [ -z "$CONTAINS_PIPELINE" ]; then
	echo "No pipeline definition. Leaving."
	exit 0
fi

echo "Starting pipeline at `date` $PWD"
SECONDS=0

TMP_FOLDER=`mktemp -d`
trap "echo -e \"\n===== Cleaning up temp folder ===== \n\";rm -rf $TMP_FOLDER/*" EXIT
ARTIFACTS_FOLDER="$TMP_FOLDER/artifacts"
CLONE_FOLDER="$TMP_FOLDER/src"
PIPELINE_DEFINITION="$TMP_FOLDER/src/.build/pipeline.ini"

mkdir -p "$ARTIFACTS_FOLDER"

echo -e "\n===== Cloning $REPO@$HEAD =====\n"
git clone --revision "$HEAD" "file://$REPO" "$CLONE_FOLDER"

echo -e "\n===== Loading build definition =====\n"
source "$WD/parse-ini.sh" "$PIPELINE_DEFINITION"

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

	echo -e "\n===== $SECTION_NAME ($STEP/$INI_SECTION_COUNT) =====\n"

	COMMAND="docker run --rm -v \"$CLONE_FOLDER:/src\" "

  IFS=';' read -ra pairs <<< "$ARTIFACTS"
  for pair in "${pairs[@]}"; do
    IFS=':' read -r NAME MOUNTING_POINT <<< "$pair"
		ART_FOLDER="$ARTIFACTS_FOLDER/$NAME"
		mkdir -p "$ART_FOLDER"
    COMMAND="$COMMAND -v \"$ART_FOLDER:$MOUNTING_POINT\""
  done

	COMMAND="$COMMAND \"$IMAGE\" \"$SCRIPT\""
	echo $COMMAND
	eval $COMMAND
	if [ $? -ne 0 ]; then
		echo -e "\n !!! Command failed. Terminating pipeline !!! \n"
		exit 1
	fi

	STEP=$((STEP+1))
done

echo -e "\n===== Build succeeded =====\n"
echo "Finished at `date` in $SECONDS seconds"
