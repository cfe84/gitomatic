#!/usr/bin/env bash
# Usage: source parse-ini.sh ini-file

if [ -z "$BASH_VERSION" ]; then
	echo "This must be ran in bash"
	exit 1
fi

# Unset anything that might have been set before
unset ${!INI_SECTION_*}

SECTION_REGEXP='^\[([^\]+)\][ \t]*$'
KEYVALUES_REGEXP='^[ 	]*([a-zA-Z0-9_-]+)=(.+)$'

line_number=0
INI_SECTION_COUNT=0
while IFS= read -r line; do
	line_number=$((line_number+1))
	COMMENT=`echo -n "$line" | grep -E '^[ 	]*(#.*)?$'`
	if [ -z "$line" ] || [ ! -z "$COMMENT" ]; then
		continue
	fi
	IS_SECTION=`echo -n "$line" | grep -E "$SECTION_REGEXP"`
	if [ ! -z "$IS_SECTION" ]; then
		SECTION=`echo -n "$line" | sed -E "s/$SECTION_REGEXP/\\1/"`
		if [ "$SECTION" != "filter" ]; then
			INI_SECTION_COUNT=$((INI_SECTION_COUNT+1))
			declare INI_SECTION_${INI_SECTION_COUNT}="$SECTION"
		fi
		continue
	fi
	IS_KV=`echo -n "$line" | grep -E "$KEYVALUES_REGEXP"`
	if [ ! -z "$IS_KV" ]; then
		if [ -z "$SECTION" ]; then
			echo "Missing section name"
			exit 1
		fi
		KEY=`echo -n "$line" | sed -E "s/$KEYVALUES_REGEXP/\\1/"` 
		VALUE=`echo -n "$line" | sed -E "s/$KEYVALUES_REGEXP/\\2/"`
		if [ "$SECTION" == "filter" ]; then
			declare FILTER_${KEY}="$VALUE"
		else
			declare INI_SECTION_${INI_SECTION_COUNT}_${KEY}="$VALUE"
		fi
		continue
	fi
	echo "Unexpected entry at line $line_number: '$line'"
	exit 1
done < "$1"