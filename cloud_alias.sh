#!/bin/bash
set -e

#
# Lists or creates aliases for Solrcloud
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
: ${HOST:=`hostname`}
: ${SOLR_BASE_PORT:=9000}
: ${SOLR:="$HOST:$SOLR_BASE_PORT"}
popd > /dev/null

function usage() {
    echo "Usage: ./cloud_alias.sh [alias [collections]]"
    echo ""
    echo "List all aliases: ./cloud_alias.sh"
    echo "List collections in alias: ./cloud_alias.sh alias"
    echo "Create alias: ./cloud_alias.sh alias collection1,collection2,collection3"
    exit $1
}

check_parameters() {
    true
}

################################################################################
# FUNCTIONS
################################################################################

list_aliases() {
    echo "Aliases:"
    curl -m 30 -s "http://$SOLR/solr/admin/collections?action=LISTALIASES" | jq -r '.aliases'
    echo ""
    echo "Collections:"
    curl -m 30 -s "http://$SOLR/solr/admin/collections?action=LIST" | jq -r '.collections[]'
}

list_alias() {
    local ALIAS="$1"
    echo -n "Collections for alias '$ALIAS': "
    curl -m 30 -s "http://$SOLR/solr/admin/collections?action=LISTALIASES" | jq -r ".aliases.${ALIAS}"
}

create_alias() {
    local ALIAS="$1"
    local COLLECTIONS="$2"
    echo "Creating alias '$ALIAS' for collections '$COLLECTIONS'"
    local RESPONSE=$(curl -m 30 -s "http://$SOLR/solr/admin/collections?action=CREATEALIAS&name=${ALIAS}&collections=${COLLECTIONS}")
    if [[ "0" == $(jq .responseHeader.status <<< "$RESPONSE") ]]; then
        echo "Success"
    else
        >&2 echo "Failure:"
        >&2 echo "$RESPONSE"
        exit 4
    fi
}


###############################################################################
# CODE
###############################################################################

check_parameters "$@"

if [[ "-h" == "$1" ]]; then
    usage 0
elif [[ -z "$1" ]]; then
    list_aliases
elif [[ -z "$2" ]]; then
    list_alias "$1"
elif [[ -z "$3" ]]; then
    create_alias "$1" "$2"
else
    >&2 echo "Error: Too many arguments"
    >&2 echo ""
    usage 3
fi
