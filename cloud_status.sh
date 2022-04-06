#!/bin/bash
set -e

#
# Lists collections and configurations in the cloud
#
# Requirements: jq
#

###############################################################################
# CONFIG
###############################################################################

if [[ -s "cloud.conf" ]]; then
    source "cloud.conf"     # Local overrides
fi
pushd ${BASH_SOURCE%/*} > /dev/null
if [[ -s "cloud.conf" ]]; then
    source "cloud.conf"     # Project overrides
fi
source general.conf
: ${CLOUD:="$(pwd)/cloud"}
popd > /dev/null

function usage() {
    echo "Usage: ./cloud_status.sh"
    echo ""
    echo "Specify Solr port with SOLR_BASE_PORT=xxxx ./cloud_status.sh"
    exit $1
}

check_parameters() {
    # Resolve default
    : ${HOST:=`hostname`}
    : ${SOLR_BASE_PORT:=9000}
    : ${SOLR:="$HOST:$SOLR_BASE_PORT"}
}

################################################################################
# FUNCTIONS
################################################################################

# Input: collection
list_collections() {
    set +e
    echo "*** Collections"
    curl -m 30 -s "http://$SOLR/solr/admin/collections?action=LIST" | jq -r .collections[]
    echo ""
    echo "*** Config sets"
    curl -m 30 -s "http://$SOLR/solr/admin/configs?action=LIST" | jq -r .configSets[]
    set -e
}

###############################################################################
# CODE
###############################################################################

check_parameters "$@"
list_collections
