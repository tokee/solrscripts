#!/bin/bash

#
# Performs a simple Solr log analysis to find suspicious entries.
# Used to sanity check for long response times and queries that might
# lead to OOM.
#

###############################################################################
# CONFIG
###############################################################################

: ${LOGS:="$@"}
: ${ROWS_MAX:="1000"}
: ${START_MAX:="1000"}
: ${GROUP_LIMIT_MAX:="1000"}
: ${FACET_LIMIT_MAX:="1000"}
: ${FACET_OFFSET_MAX:="1000"}

function usage() {
    cat <<EOF
Usage: ./culprits.sh <logfile> <logfile>*
EOF
    exit $1
}

check_parameters() {
    if [[ -z "$LOGS"  ]]; then
        >&2 echo "Error: No logfiles specified"
        usage 2
    fi
}

################################################################################
# FUNCTIONS
################################################################################


grouped_print() {
    local WARNINGS=0
    local LAST="___________432984r7432984r792"
    while read -r LINE; do
        TOKENS=($LINE)
        IFS="=" read -a PARAM_PAIR <<< "${TOKENS[0]}"
        KEY="${PARAM_PAIR[0]}"
        if [[ "$LAST" != "$KEY" ]]; then
            echo ""
            LAST="$KEY"
        fi
        if [[ "$KEY" == "rows" && "$ROWS_MAX" -lt "${PARAM_PAIR[1]}" ]]; then
            echo "${LINE} ***** SUSPICIOUS: Value ${PARAM_PAIR[1]} > $ROWS_MAX *****"
            WARNINGS=$((WARNINGS+1))
        elif [[ "$KEY" == "start" && "$START_MAX" -lt "${PARAM_PAIR[1]}" ]]; then
            echo "${LINE} ***** SUSPICIOUS: Value ${PARAM_PAIR[1]} > $START_MAX *****"
            WARNINGS=$((WARNINGS+1))
        elif [[ "$KEY" == *group.limit && "$GROUP_LIMIT_MAX" -lt "${PARAM_PAIR[1]}" ]]; then
            echo "${LINE} ***** SUSPICIOUS: Value ${PARAM_PAIR[1]} > $GROUP_LIMIT_MAX *****"
            WARNINGS=$((WARNINGS+1))
        elif [[ "$KEY" == *facet.limit && "$FACET_LIMIT_MAX" -lt "${PARAM_PAIR[1]}" ]]; then
            echo "${LINE} ***** SUSPICIOUS: Value ${PARAM_PAIR[1]} > $FACET_LIMIT_MAX *****"
            WARNINGS=$((WARNINGS+1))
        elif [[ "$KEY" == *facet.offset && "$FACET_OFFSET_MAX" -lt "${PARAM_PAIR[1]}" ]]; then
            echo "${LINE} ***** SUSPICIOUS: Value ${PARAM_PAIR[1]} > $FACET_OFFSET_MAX *****"
            WARNINGS=$((WARNINGS+1))

        elif [[ "$KEY" == *group.size ]]; then
            echo "${LINE} ***** SUSPICIOUS: group.size should probably be group.limit *****"
            WARNINGS=$((WARNINGS+1))
        elif [[ "$KEY" == *facet.size ]]; then
            echo "${LINE} ***** SUSPICIOUS: facet.size should probably be facet.limit *****"
            WARNINGS=$((WARNINGS+1))
            
        else
            echo "${LINE}"
        fi
    done
    echo ""
    echo "- Total unique suspicious entries: $WARNINGS"
}

# Returns the filename of a temporary file holding the stats
base_numeric_stats() {
    local DEST=$(mktemp)
    zcat -f $LOGS | zgrep -o "[a-zA-Z0-9_.-]\+=[0-9]\+" | grep -v "NOW\|QTime\|hits" | \
        ## Sort & uniqueify
        sort | uniq -c | \
        # Swap count and param-pair for ordered output
        sed 's/[^0-9]*\([0-9]\+\) \(.*\)/\2 (\1 instances)/' | \
        # sort by [primary param-name, secondary param-value] for even more ordered output
        sort -t= -k1,1 -k2rn > "$DEST"
    echo "$DEST"
}

numeric_param() {
    local BASE_NUMERIC="$1"
    echo "- Unique numeric params:"
    # Print grouped by param-name
    cat "$BASE_NUMERIC" | grouped_print
}

find_culprits() {
    echo "- Extracting numeric stats"
    local BASE_NUMERIC=$(base_numeric_stats)
    numeric_param "$BASE_NUMERIC"
    rm "$BASE_NUMERIC"
}

###############################################################################
# CODE
###############################################################################

check_parameters "$@"
find_culprits
