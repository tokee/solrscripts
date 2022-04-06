#!/bin/bash

#
# Verifies that Solr is up and running with a specified collection
#
# Outputs either total hitCount or "na"
#

###############################################################################
# CONFIG
###############################################################################

if [[ -s "cloud.conf" ]]; then
    source "cloud.conf"     # Local overrides
fi
pushd "${BASH_SOURCE%/*}" > /dev/null
if [[ -s "cloud.conf" ]]; then
    source "cloud.conf"     # Project overrides
fi
source general.conf
: ${CLOUD:="$(pwd)/cloud"}
: ${DEBUG:="false"}
: ${TIMEOUT:="600"}         # 10 minutes
: ${SOLR:=""}               # Default value specified in check_parameters

: ${RETRIES:=30}            # How many times to try before giving up
: ${SLEEP:=10}              # How many seconds to sleep between each retry
popd > /dev/null

function usage() {
    local CLOUDS=$(ls "${CLOUD}" | tr '\n' ' ')
    local VLIST=$(echo "$VERSIONS" | sed 's/ / | /g')

    echo "Usage: ./cloud_verify.sh <$VLIST> <collection>"
    echo ""
    echo "Installed SolrClouds: $CLOUDS"
    exit "$1"
}

check_parameters() {
    if [[ -z "$1" && -z "$VERSION" ]]; then
        echo "No Solr version specified."$'\n'
        usage 2
    elif [[ ! -z "$1" ]]; then
        VERSION="$1"
    fi
    if [[ -z "$2" && -z "$COLLECTION" ]]; then
        echo "No Solr collection specified."$'\n'
        usage 3
    elif [[ ! -z "$2" ]]; then
        COLLECTION="$2"
    fi
    
    : ${SOLR:="${HOST}:${SOLR_BASE_PORT}/solr"}
    URL="${SOLR}/${COLLECTION}/select?q=*:*&rows=0&facet=false&hl=false&wt=json"
}

################################################################################
# FUNCTIONS
################################################################################

debug() {
    if [[ "true" == "$DEBUG" ]]; then
        >&2 echo "$@"
    fi
}

get_document_count() {
    debug "curl> $URL"
    RESULT=$(curl -s -m "$TIMEOUT" "$URL")
    local FOUR=$( grep "HTTP ERROR 404" <<< "$RESULT" )
    if [[ "." != ".$FOUR" ]]; then
        debug "Got http 404 for $URL"
        echo "na"
    elif [[ "." == "$RESULT" ]]; then
        echo "na"
    else
        debug "$RESULT"
        HITS=$( echo "$RESULT" | jq '.response.numFound' )
        #    echo $HITS

        if [[ "." != .$(grep '^[0-9]\+$' <<< "$HITS") ]]; then
            echo "$HITS"
        else
            debug "Not an integer response from .numFound extraction: '$HITS'"
            echo "na"
        fi
    fi
}

multitry() {
    local TRY=1
    local COUNT="na"
    while [[ "$TRY" -le "$RETRIES" ]]; do
        local COUNT=$(get_document_count)
        if [[ "." != .$(grep '^[0-9]\+$' <<< "$COUNT") ]]; then
            break
        fi
        if [[ "$TRY" -lt "$RETRIES" ]]; then
            sleep $SLEEP
        fi
        TRY=$(( TRY+1 ))
    done
    echo "$COUNT"
    if [[ "." == .$(grep '^[0-9]\+$' <<< "$COUNT") ]]; then
        >&2 echo "Unable to get any hits from $URL"
        exit 1
    fi
}

###############################################################################
# CODE
###############################################################################

check_parameters "$@"
multitry
