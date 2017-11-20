#!/bin/bash
set -e

#
# Uploads configurations and creates collections in SolrCloud
#

###############################################################################
# CONFIG
###############################################################################

pushd ${BASH_SOURCE%/*} > /dev/null
source general.conf
: ${CLOUD:="$(pwd)/cloud"}
# If true, existing configs with the same ID are overwritten
: ${FORCE_CONFIG:="false"}
popd > /dev/null

################################################################################
# FUNCTIONS
################################################################################

function usage() {
    echo "Usage: ./cloud_sync.sh <`echo \"$VERSIONS\" | sed 's/ / | /g'`> <config_folder> <config_id> [collection]"
    echo ""
    echo "If VERSION is specified in custom.conf, it can be skipped, reducing the call to"
    echo "./cloud_sync.sh <config_folder> <config_id> [collection]"
    exit $1
}

check_parameters() {
    if [[ -z "$VERSION" ]]; then
        # Version is specified in config, so not needed
        VERSION="$1"
        CONFIG_FOLDER="$2"
        CONFIG_NAME="$3"
        COLLECTION="$4"
    else
        CONFIG_FOLDER="$1"
        CONFIG_NAME="$2"
        COLLECTION="$3"
    fi    
    
    if [ "." == ".`echo \" $VERSIONS \" | grep \" $VERSION \"`" ]; then
        >&2 echo "The Solr version $VERSION is unsupported"
        usage 1
    fi
    if [ "." == ".$CONFIG_FOLDER" -o "." == ".$CONFIG_NAME" ]; then
        usage
    fi
    if [ ! -d $CONFIG_FOLDER ]; then
        >&2 echo "The config folder '$CONFIG_FOLDER' does not exist"
        usage 2
    fi
    if [ ! -s $CONFIG_FOLDER/schema.xml ]; then
        >&2 echo "No schema.xml in the config folder '$CONFIG_FOLDER'"
        usage 21
    fi
    if [ ! -d ${CLOUD}/$VERSION ]; then
        >&2 echo "No cloud present at ${CLOUD}/${VERSION}. Please install and start a cloud first with"
        >&2 echo "./cloud_install.sh $VERSION"
        >&2 echo "./cloud_start.sh $VERSION"
        exit 3
    fi

}

locate_solr_scripts() {
    if [ "." == ".`echo \" $LAYOUT2_VERSIONS \" | grep \" $VERSION \"`" ]; then
        : ${SOLR_SCRIPTS:="${CLOUD}/${SHARDS}/solr1/example/scripts/cloud-scripts"}
    else
        : ${SOLR_SCRIPTS:="${CLOUD}/${VERSION}/solr1/server/scripts/cloud-scripts"}
    fi
    if [ ! -d $SOLR_SCRIPTS ]; then
        >&2 echo "Error: The Solr script folder '$SOLR_SCRIPTS' is not visible from `pwd`"
        exit 13
    fi
}

resolve_derived_settings() {
    # Resolve default
    : ${HOST:=`hostname`}
    : ${ZOO_BASE_PORT:=2181}
    : ${ZOOKEEPER:="$HOST:$ZOO_BASE_PORT"}
    
    : ${SOLR_BASE_PORT:=9000}
    : ${SOLR:="$HOST:$SOLR_BASE_PORT"}
    : ${SHARDS:=1}
    : ${REPLICAS:=1}
    
    : ${CONFIG_FOLDER:="config/solr/conf"}
}

upload_config() {
    # Upload the config if it is not already in the cloud
    set +e
    EXISTS="`$SOLR_SCRIPTS/zkcli.sh -zkhost $ZOOKEEPER -cmd list | grep \"/configs/$CONFIG_NAME/\"`" >> /dev/null 2>> /dev/null
    set -e
    if [[ "." == ".$EXISTS" || "true" == "$FORCE_CONFIG" ]]; then
        # Upload the config
        echo "Adding/updating Solr config $CONFIG_NAME from $CONFIG_FOLDER to ZooKeeper at $ZOOKEEPER"
        echo "> $SOLR_SCRIPTS/zkcli.sh -zkhost $ZOOKEEPER -cmd upconfig -confname $CONFIG_NAME -confdir \"$CONFIG_FOLDER\""
        $SOLR_SCRIPTS/zkcli.sh -zkhost $ZOOKEEPER -cmd upconfig -confname $CONFIG_NAME -confdir "$CONFIG_FOLDER"
    else
        echo "Solr config $CONFIG_NAME already exists. Skipping upload"
    fi
}

create_new_collection() {
    echo "Collection $COLLECTION does not exist. Creating new $SHARDS shard collection with $REPLICAS replicas and config $CONFIG_NAME"
    URL="http://$SOLR/solr/admin/collections?action=CREATE&name=${COLLECTION}&numShards=${SHARDS}&maxShardsPerNode=${SHARDS}&replicationFactor=${REPLICAS}&collection.configName=${CONFIG_NAME}"
    echo "request> $URL"
    RESPONSE="`curl -m 60 -s \"$URL\"`"
    if [ ! -z "`echo "$RESPONSE" | grep "<int name=\"status\">0</int>"`" ]; then
        >&2 echo "Failed to create collection ${COLLECTION} with config ${CONFIG_NAME}:"
        >&2 echo "$RESPONSE"
        exit 1
    fi
    
    set +e
    EXISTS=`curl -m 30 -s "http://$SOLR/solr/admin/collections?action=LIST" | grep -o "<str>${COLLECTION}</str>"`
    set -e
    if [ "." == ".$EXISTS" ]; then
        >&2 echo "Although the API call for creating the collection $COLLECTION responded with success, the collection is not available in the cloud. This is likely due to problems with solrconfig.xml or schema.xml in config set ${CONFIG_NAME}."
        exit 2
    fi

    echo "Collection with config $CONFIG_NAME available at http://$SOLR/solr/"
}

update_existing_collection() {
    echo "Collection $COLLECTION already exist. Assigning config $CONFIG_NAME"
    $SOLR_SCRIPTS/zkcli.sh -zkhost $ZOOKEEPER -cmd linkconfig -collection $COLLECTION -confname $CONFIG_NAME

    echo "Reloading collection $COLLECTION"
    RESPONSE=`curl -m 120 -s "http://$SOLR/solr/admin/collections?action=RELOAD&name=$COLLECTION"`
    if [ -z "`echo \"$RESPONSE\" | grep \"<int name=.status.>0</int>\"`" ]; then
        >&2 echo "Failed to reload collection ${COLLECTION}:"
        >&2 echo "$RESPONSE"
        exit 1
    fi
}

###############################################################################
# CODE
###############################################################################

check_parameters "$@"

locate_solr_scripts
resolve_derived_settings

pushd ${CLOUD}/$VERSION > /dev/null

upload_config

# Stop further processing if no collection is specified
if [ -z $COLLECTION ]; then
    echo "Skipping collection creation as no collection is specified"
    exit
fi

# Update existing or create new collection
set +e
EXISTS=`curl -m 30 -s "http://$SOLR/solr/admin/collections?action=LIST" | grep -o "<str>${COLLECTION}</str>"`
set -e
if [ "." == ".$EXISTS" ]; then
    create_new_collection
else
    update_existing_collection
fi

popd > /dev/null
