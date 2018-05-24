#!/bin/bash

#
# Checks a log for scary requests (high row count, large facet, group count...)
#
# TODO: Collapse equal requests
# TODO: Find patterns in 0-hit requests
# TODO: Extract queries > x time

###############################################################################
# CONFIG
###############################################################################

if [[ -s "cloud.conf" ]]; then
    source "cloud.conf"     # Local overrides
fi
pushd ${BASH_SOURCE%/*} > /dev/null
: ${LOGS:="$@"}
: ${TOPX_DUPLICATES:="6"}
: ${TOPX_SLOW:="6"}
: ${DEFAULT_STRING_LIMIT:="200"}
: ${MAX_TIMEOUTS:="5"}
: ${MAX_SERVER_ERRORS:="5"}
popd > /dev/null

usage() {
    echo "Usage: ./sanity_check_log.sh logfile*"
    echo ""
    exit $1
}

check_parameters() {
    # TODO: The override-if-no-value above should make this unneccessary
    if [[ -z "$1" && -z "$LOGS" ]]; then
        echo "No Solr logs specified."$'\n'
        usage
    elif [[ ! -z "$1" ]]; then
        LOGS="$@"
    fi
}

################################################################################
# FUNCTIONS
################################################################################

all_select() {
    cat $LOGS | grep 'path=/select params='
}

all_with_hits() {
    cat $LOGS | grep 'path=/select params=' | grep ' hits=[0-9]'
}

all_with_1plus_hits() {
    cat $LOGS | grep 'path=/select params=' | grep ' hits=[1-9]'
}

all_with_zero_hits() {
    cat $LOGS | grep 'path=/select params=' | grep ' hits=0'
}

queries_only() {
    grep -o "[^a-z]q=[^&]\+&" | sed 's/.q=\(.*\)&/\1/'
}

# Output: WITH_HITS, ZERO_HITS, ONE_PLUS_HITS
base_stats() {
    WITH_HITS=0
    ZERO_HITS=0
    ONE_PLUS_HITS=0
    while IFS=$'\n' read -r LINE || [[ -n "$line" ]]; do
        WITH_HITS=$((WITH_HITS+1))
        if [[ "$LINE" =~ \ hits=0.* ]]; then
            ZERO_HITS=$((ZERO_HITS+1))
        else
            ONE_PLUS_HITS=$((ONE_PLUS_HITS+1))
        fi
    done <<< "$(all_with_hits)"

    echo "*** Base stats"
    echo "* Entries with hits: $WITH_HITS"
    echo "* Entries with zero hits: $ZERO_HITS"
    echo "* Entries with 1+ hits: $ONE_PLUS_HITS"
}

# Input: String [limit]
limit() {
    local S="$1"
    : ${L:="$2"}
    : ${L:="$DEFAULT_STRING_LIMIT"}
    if [[ ${#S} -le "$L" ]]; then
        echo "$S"
    else
        echo "${S:0:$L}..."
    fi
}

slowest() {
    all_with_hits  | sed -e 's/.* INFO  .*params=//' -e 's/^\(.*\QTime=\)\([0-9]\+\)\(.*\)$/\2 \1\2\3/' | sort -rn | head -n $TOPX_SLOW
     #| sed 's/^[0-9]* \(.*\)$/\1/'
}

# Output: UNIQUE_ZERO_HIT_QUERIES, MOST_POPULAR_COUNT, MOST_POPULAR
queries() {
    UNIQUE_ZERO_HIT_QUERIES=$(all_with_zero_hits | queries_only | sort | uniq | wc -l)
    local T=$(mktemp)
    all_with_hits | queries_only | sort | uniq -c | sort -rn > $T
    MOST_POPULAR=$(head -n 1 $T | sed 's/^ *[0-9]\+ \(.*\)$/\1/')
    MOST_POPULAR_COUNT=$(head -n 1 $T | sed 's/ *\([0-9]\+\) .*/\1/')
    
    echo "*** Queries"
    echo "* Unique queries with zero hits: $UNIQUE_ZERO_HIT_QUERIES"

    echo "* Top-$TOPX_DUPLICATES most popular queries:"
    while IFS=$'\n' read -r LINE || [[ -n "$line" ]]; do
        local Q=$(sed 's/^ *[0-9]\+ \(.*\)$/\1/' <<< "$LINE")
        local QC=$(sed 's/ *\([0-9]\+\) .*/\1/' <<< "$LINE")
        echo "  ${QC}: $(limit "$Q")"
    done <<< "$(head -n $TOPX_DUPLICATES $T)"

    slowest > $T
    
    echo "* Top-$TOPX_SLOW slowest queries"
    while IFS=$'\n' read -r LINE || [[ -n "$line" ]]; do
        local TQ=$(sed 's/ {.*[^a-z]q=\([^&]\+\)&.*/ \1/' <<< "$LINE")
        echo "  $(limit "$TQ")"
    done <<< "$(head -n $TOPX_DUPLICATES $T)"
    
    echo "* Top-$TOPX_SLOW slowest full requests"
    while IFS=$'\n' read -r LINE || [[ -n "$line" ]]; do
        echo "  $LINE"
    done <<< "$(head -n $TOPX_DUPLICATES $T)"
    
    rm $T
}

timeouts() {
    echo "*** Timeouts (max ${MAX_TIMEOUTS})"
    cat $LOGS | grep "ERROR.*Timeout occured while waiting response from server at" | head -n $MAX_TIMEOUTS
}

server_errors() {
    echo "*** Server errors (max ${MAX_SERVER_ERRORS})"
    cat $LOGS | grep " status=500 " | head -n $MAX_SERVER_ERRORS
}

all_steps() {
    base_stats
    queries
    timeouts
    server_errors
}

###############################################################################
# CODE
###############################################################################

check_parameters "$@"
all_steps "$LOGS"
