#!/bin/bash

#
# Stops a specific SolrCloud
#
# TODO: Figure out which cloud is running and stop it, so that version need not be specified
# TODO: In case of hard stop, remove write.lock
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
: ${CLOUD:=`pwd`/cloud}
popd > /dev/null

function usage() {
    echo "Usage: ./cloud_start.sh <`echo \"$VERSIONS\" | sed 's/ / | /g'`>"
    echo ""
    echo "Installed SolrClouds: `ls cloud | tr '\n' ' '`"
    exit $1
}

check_parameters() {
    if [[ -z "$1" && -z "$VERSION" ]]; then
        echo "No Solr version specified."$'\n'
        usage
    elif [[ ! -z "$1" ]]; then
        VERSION="$1"
    fi
    
    if [ "." == ".`echo \" $VERSIONS \" | grep \" $VERSION \"`" ]; then
        >&2 echo "The Solr version $VERSION is unsupported"
        usage 1
    fi
    if [ ! -d ${CLOUD}/$VERSION ]; then
        >&2 echo "The Solr version $VERSION is not installed."
        >&2 echo "Please run ./install_cloud.sh $VERSION"
        exit 3
    fi
}

################################################################################
# FUNCTIONS
################################################################################

stop_zoo() {
    # Be sure to shut down the ZooKeepers last
    for Z in `seq 1 $ZOOS`; do
        if [ ! -d zoo$Z ]; then
            >&2 echo "Expected a ZooKeeper-instalation at `pwd`/zoo$S but found none."
            >&2 echo "Please run ./cloud_install.sh $VERSION"
            return
        fi
        zoo$Z/bin/zkServer.sh stop
    done
}

stop_solr() {
    SOLR_PORT=$SOLR_BASE_PORT
    for S in `seq 1 $SOLRS`; do
        if [ ! -d solr$S ]; then
            >&2 echo "Expected a Solr-instalation at `pwd`/solr$S but found none."
            >&2 echo "Please run ./cloud_install.sh $VERSION"
        else
            solr$S/bin/solr stop -p $SOLR_PORT
            SOLR_PORT=$(( SOLR_PORT + 10 ))
        fi
    done
}

###############################################################################
# CODE
###############################################################################

check_parameters "$@"

pushd ${CLOUD}/$VERSION > /dev/null
stop_solr
stop_zoo
popd > /dev/null

