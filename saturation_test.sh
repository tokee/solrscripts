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
export WARMUP_COUNT=10 # First $WARMUP_COUNT queries will not be measured
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
# Function for issuing queries

# Input: query-file
function perform_requests() {
    local QF="$2"
    
    while IFS='' read -r LINE || [[ -n "$line" ]]; do 
        # TODO: Escape query
        local QTIME=`curl "${SOLR}?${BASE_SOLR_PARAM}&q=$LINE" | grep qtime`
    done < "$QF"
}

#######################################################################################
# Create query-files for the threads

#######################################################################################
# Warm up

#######################################################################################
# Start threads and wait for them to finish

#######################################################################################
# Aggregate statistics

TOTAL_QUERY_COUNT=`wc -l $QUERY_FILE`
echo "#threads queries/s s/query"
echo "$THREADS $THROUGHPUT $LATENCY"
