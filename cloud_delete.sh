#!/bin/bash

#
# Deletes a SolrCloud collection
#
# TODO: Figure out which cloud is running and stop it, so that version need not be specified
#

###############################################################################
# CONFIG
###############################################################################

pushd ${BASH_SOURCE%/*} > /dev/null
source general.conf
: ${CLOUD:=`pwd`/cloud}
: ${SOLR:="$HOST:$SOLR_BASE_PORT/solr"}
popd > /dev/null

################################################################################
# FUNCTIONS
################################################################################

function usage() {
    echo "Usage: ./cloud_delete.sh collection"
    exit $1
}

check_parameters() {
    if [ ! -d ${CLOUD}/$VERSION ]; then
        >&2 echo "The Solr version $VERSION is not installed."
        >&2 echo "Please run ./install_cloud.sh $VERSION"
        usage 3
    fi
    COLLECTION="$1"
    if [[ "." == ".$COLLECTION" ]]; then
        echo "No collection specified. Available collections are"
        curl -s "$SOLR/admin/collections?action=LIST" | grep -o "<arr name=.collections.*</arr>" | grep -o "<str>[^<]*</str>" | sed 's/<\/*str>//g'
        echo ""
        usage 4
    fi
}

###############################################################################
# CODE
###############################################################################

check_parameters "$@"

DELETE_URL="$SOLR/admin/collections?action=DELETE&name=${COLLECTION}"
echo "Calling $DELETE_URL"
curl "$DELETE_URL"
