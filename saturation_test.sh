#!/bin/bash

#
# Tool for finding the saturation point of Solr requests.
# Takes a file with queries and spawns X threads issuing 1/X of those queries
# as fast as they can. At the end, throughput and average latency is reported.
#
# To avoid skewing the results by everithing being cached, consider dropping
# the disk cache between tests and let the script warm up the searcher.
#

# Do not change the setup variables directly in this script.
# Specify them in a file named "saturation_test.settings" instead.
export QUERY_FILE="saturation_test.queries"
export SOLR="http://localhost:8983/solr/collection1"
export BASE_SOLR_PARAMS="&wt=json"
export WARMUPS=10 # First $WARMUPS queries will not be measured
if [ -s "saturation_test.settings" ]; then
    source "saturation_test.settings"
fi

#######################################################################################
# Handle input

function usage() {
    echo "Usage: ./saturation_test.sh #threads [queryfile]"
    exit
}

if [ ! -n "$1" ]; then
    echo "Please provide the number of threads" 1>&2
    usage
fi
THREADS="$1"
if [ -n "$2" ]; then
    QUERY_FILE="$2"
fi
if [ -s "$QUERY_FILE" ]; then
    echo "No queries at \"$QUERY_FILE\"" 1>&2
    usage
fi

#######################################################################################
# Single threaded query handling

# Input:  query-file
# Output: query_count total_measured_time total_qtime
function perform_requests() {
    local QF="$1"
    local START=`date +%s.%N`
    local TOTAL_QTIME=0
    local QCOUNT=0
    while IFS='' read -r LINE; do 
        # TODO: Escape query
        # TODO: Finishe the line
        local QTIME=`curl "${SOLR}?${BASE_SOLR_PARAM}&q=$LINE" | grep qtime`
        local TOTAL_QTIME=$(( TOTAL_QTIME 0 QTIME ))
        local QCOUNT=$(( QCOUNT + 1 ))
    done < "$QF"

    local END=`date +%s.%N`
    local MTIME=$(( END - START ))
    echo "$QCOUNT $MTIME $TOTAL_QTIME"
}

#######################################################################################
# Create query-files for the threads

function create_query_files() {
    rm t_queries.*
    COUNTER=0
    THREAD=1
    while IFS='' read -r LINE || [[ -n "$line" ]]; do
        COUNTER=$(( COUNTER + 1 ))
        if [ "$COUNTER" -le "$WARMUPS" ]; then
            echo "$LINE" >> "t_queries.warmup"
        else
            echo "$LINE" >> "t_queries.$THREAD"
            THREAD=$(( THREAD + 1 ))
            if [ "$THREAD" -gt "$THREADS" ]; then
                THREAD=1
            fi
        fi
    done < "$QUERY_FILE"
}


#######################################################################################
# Warm up

function warmup() {
    # We ignore the result
    local RESULT=`perform_requests "t_queries.warmup"`
}

#######################################################################################
# Start threads and wait for them to finish


#######################################################################################
# Aggregate statistics

TOTAL_QUERY_COUNT=`wc -l $QUERY_FILE`
echo "#threads queries/s s/query"
echo "$THREADS $THROUGHPUT $LATENCY"
