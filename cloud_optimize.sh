#!/bin/bash

#
# Optimize a SolrCloud collection
#
# Deprecated (read: Never used)

###############################################################################
# CONFIG
###############################################################################

pushd ${BASH_SOURCE%/*} > /dev/null
source general.conf
: ${CLOUD:=`pwd`/cloud}
: ${MAX_SEGMENTS:=1}
popd > /dev/null

# curl -s "http://localhost:9010/solr/admin/cores?action=STATUS&wt=json" | jq '.status | ..[] | .cloud.replica' 2> /dev/null

: ${RETRIES:=6} # default number of retries on start probe before giving up

################################################################################
# FUNCTIONS
################################################################################

function usage() {
    echo "Usage: ./cloud_optimize.sh"
    exit $1
}

CORES=""
SOLR_PORT=$SOLR_BASE_PORT
for S in $(seq 1 $SOLRS); do
    SOLR="http://${HOST}:${SOLR_PORT}/solr"
    URL="${SOLR}/admin/cores?action=STATUS&wt=json"
    echo "Resolving cores with curl> $URL"
    CORES=$( curl -s curl -s "$URL" | jq '.status | ..[] | .cloud.replica' 2> /dev/null | tr -d '"' )
    if [[ "." == ".$CORES" ]]; then
        >&2 echo "No cores found with $URL"
        continue
    fi

    for CORE in $CORES; do
        O_URL="${SOLR}/${CORE}/update?optimize=true&maxSegments=${MAX_SEGMENTS}&waitFlush=true"
        echo "Optimizing $CORE (might take hours) with curl> $O_URL"
        curl "$O_URL"
    done
    
    SOLR_PORT=$(( SOLR_PORT+10 ))
done
