#!/bin/bash

#
# Starts a specific SolrCloud
#
# TODO: Increase 5 second timeout on shutdown to avoid stale write.lock
#

###############################################################################
# CONFIG
###############################################################################

pushd ${BASH_SOURCE%/*} > /dev/null
source general.conf
: ${CLOUD:=`pwd`/cloud}
: ${RETRIES:=6} # default number of retries on start probe before giving up
: ${AUTO_INSTALL:=false}
popd > /dev/null

################################################################################
# FUNCTIONS
################################################################################

usage() {
    echo "Usage: ./cloud_start.sh <`echo \"$VERSIONS\" | sed 's/ / | /g'`>"
    echo ""
    echo "Installed SolrClouds: `ls ${CLOUD} | tr '\n' ' '`"
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
        if [[ "true" != "$AUTO_INSTALL" ]]; then
            >&2 echo "Error: No Solr installed at ${CLOUD}/$VERSION"
            usage 5
        fi
        echo "Attempting install of missing SolrCloud version $VERSION"
        ./cloud_install.sh $VERSION
        if [ ! -d ${CLOUD}/$VERSION ]; then
            >&2 echo "Unable to install Solr version $VERSION"
            >&2 echo "Please run ./cloud_install.sh $VERSION manually and inspect the errors"
            exit 3
        else
            echo "Successfully installed SolrCloud $VERSION"
        fi
    fi
}

start_zoo() {
    for Z in `seq 1 $ZOOS`; do
        if [ ! -d zoo$Z ]; then
            >&2 echo "Expected a ZooKeeper-instalation at `pwd`/zoo$S but found none."
            >&2 echo "Please run ./cloud_install.sh $VERSION"
            continue
        fi
        echo "calling> zoo$Z/bin/zkServer.sh start"
        zoo$Z/bin/zkServer.sh start
    done
}

start_solr() {
    if [ ! "." == ".`echo \" $LAYOUT2_VERSIONS \" | grep \" $VERSION \"`" ]; then
        SOLR_HOME_SUB=server/solr/
    else
        SOLR_HOME_SUB=example/solr/
    fi
    SOLR_PORT=$SOLR_BASE_PORT
    for S in `seq 1 $SOLRS`; do
        if [ ! -d solr$S ]; then
            >&2 echo "Expected a Solr-instalation at `pwd`/solr$S but found none."
            >&2 echo "Please run ./cloud_install.sh $VERSION"
            continue
        fi
        sed -i "s/loops -lt [0-9]\+ /loops -lt $RETRIES /" $(pwd)/solr$S/bin/solr
        SOLR_START_COMMAND="`pwd`/solr$S/bin/solr -m $SOLR_MEM -cloud -s `pwd`/solr$S/$SOLR_HOME_SUB -p $SOLR_PORT -z $HOST:$ZOO_BASE_PORT -h $HOST"
        echo "calling> $SOLR_START_COMMAND"
        LOCAL_SHOME=`pwd`/solr$S/$SOLR_HOME_SUB
        SOLR_START_RESULT=`solr$S/bin/solr -m $SOLR_MEM -cloud -s $LOCAL_SHOME -p $SOLR_PORT -z $HOST:$ZOO_BASE_PORT -h $HOST`
        if [ "." == ".`echo \"$SOLR_START_RESULT\" | grep \"Started Solr server\"`" ]; then
            >&2 echo "Error: Unable to start Solr server using command"
            >&2 echo "$SOLR_START_COMMAND"
            >&2 echo "$SOLR_START_RESULT"
            exit 28
        fi
        SOLR_PORT=$(( SOLR_PORT + 10 ))
    done
}

###############################################################################
# CODE
###############################################################################

check_parameters "$@"

pushd ${CLOUD}/$VERSION > /dev/null
start_zoo
start_solr
popd > /dev/null
