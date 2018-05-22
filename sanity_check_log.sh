#!/bin/bash

#
# Checks a log for scary requests (high row count, large facet, group count...)
#
# TODO: Collapse equal reuests
#

###############################################################################
# CONFIG
###############################################################################

if [[ -s "cloud.conf" ]]; then
    source "cloud.conf"     # Local overrides
fi
pushd ${BASH_SOURCE%/*} > /dev/null
: ${LOGS:=""}
popd > /dev/null

usage() {
    echo "Usage: ./sanity_check_log.sh logfile*"
    echo ""
    exit $1
}

check_parameters() {
    if [[ -z "$1" && -z "$LOGS" ]]; then
        echo "No Solr logs specified."$'\n'
        usage
    elif [[ ! -z "$1" ]]; then
        LOGS="$@"
    fi
}

################################################################################
# FUNCTIONS
################################################################################

get_queries() {
    local LOG="$1"
    cat "$LOG"
}

validate_all() {
    for LOG in "$1"; do
        get_requests "$LOG" 
    done
}

###############################################################################
# CODE
###############################################################################

check_parameters "$@"
validate_all "$LOGS"
