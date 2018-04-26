#!/bin/bash

#
# Performs a diff on fields in two schemas.
#
# Current version only looks at type, class, indexed, stored, docValues & multiValued.
# It would be preferable to also look at analysis changes, but that is quite hard
# to compare properly.
#
# TODO: Also look at omitNorms, positionStep & positionIncrementGap
#

###############################################################################
# CONFIG
###############################################################################

pushd ${BASH_SOURCE%/*} > /dev/null
: ${SCHEMA1:="$1"}
: ${SCHEMA2:="$2"}
popd > /dev/null

function usage() {
    echo "Performs a diff of the fields in two schemas"
    echo ""
    echo "Usage: ./schema_diff.sh schema1 schema2"
    exit $1
}

check_parameters() {
    if [[ -z "$2" ]]; then
        usage
    fi

    if [[ ! -s "$SCHEMA1" ]]; then
        >&2 echo "Error: Schema $SCHEMA1 could not be found"
        usage 2
    fi
    if [[ ! -s "$SCHEMA2" ]]; then
        >&2 echo "Error: Schema $SCHEMA2 could not be found"
        usage 3
    fi
}

################################################################################
# FUNCTIONS
################################################################################

# Removes all comments
function pipe_xml() {
    cat "$1" | sed 's/<!--.*-->//' | sed '/<!--/,/-->/d' | tr '\n' ' '
}

# Input: schema element match-attribute match-value attribute [default]
get_attribute() {
    local SCHEMA="$1"
    local ELEMENT="$2"
    local M_ATTRIBUTE="$3"
    local M_VALUE="$4"
    local ATTRIBUTE="$5"
    local DEFAULT="$6"
    
    local VAL=$(pipe_xml "$SCHEMA" | grep -o "<${ELEMENT} [^>]*${M_ATTRIBUTE}=\"${M_VALUE}\" [^>]*>" | grep " ${ATTRIBUTE}=\"[^\"]*\"" | sed "s/.* ${ATTRIBUTE}=\"\([^\"]*\)\".*/\1/")

    if [[ -z "$VAL" ]]; then
        echo -n "$DEFAULT"
    else
        echo "$VAL"
    fi
}

# Input: schema element attribute
get_attributes() {
    local SCHEMA="$1"
    local ELEMENT="$2"
    local ATTRIBUTE="$3"
    pipe_xml "$SCHEMA" | grep -o "<${ELEMENT} [^>]*${ATTRIBUTE}=\"[^\"]\+\"" | sed "s/.* ${ATTRIBUTE}=\"\([^\"]*\)\".*/\1/" | LC_ALL="c" sort
}

# Input: schema name default
get_type() {
    get_attribute "$1" field name "$2" type "$3"
}

# Input: schema
get_field_names() {
    get_attributes "$1" field name
}

#get_attribute "$SCHEMA1" fieldType name text_general stored "?"
#exit

# Input: schema field attribute [default]
get_override() {
    local SCHEMA="$1"
    local FIELD="$2"
    local ATTRIBUTE="$3"
    local VALUE="$4" # DEFAULT

    local TYPE="$3"
    TYPE=$(get_type "$SCHEMA" "$FIELD_NAME")
    if [[ ! -z "$TYPE" ]]; then
        local VALUE=$(get_attribute "$SCHEMA" fieldType name "$TYPE" "$ATTRIBUTE" "$VALUE")
    fi
    get_attribute "$SCHEMA" field name "$TYPE" "$ATTRIBUTE" "$VALUE"
}

# TODO: Highly inefficient as everything is scanned multiple times
# Input: schema field-name
expand_field() {
    local SCHEMA="$1"
    local FIELD_NAME="$2"

    echo -n "<field name=\"$FIELD_NAME\" "
    echo -n "type=\"$(get_type "$SCHEMA" "$FIELD_NAME" "?")\" "
    # TODO: Check if multi-valued:false and stored:true are the real Solr defaults
    # This might involve a list of known classes
    for ATT in class:? indexed:true stored:true docValues:false multiValued:false; do
        local AT=$(cut -d: -f1 <<< "$ATT")
        local DEF=$(cut -d: -f2 <<< "$ATT")
        echo -n "${AT}=\"$(get_override "$SCHEMA" "$FIELD_NAME" $AT "$DEF")\" "
    done
    echo -n "/>"
}

diff_schemas() {
    FIELDS1=$(get_field_names "$SCHEMA1")
    FIELDS2=$(get_field_names "$SCHEMA2")
    echo $'\n'"Unique fields in $SCHEMA1"
    diff <(echo "$FIELDS1") <(echo "$FIELDS2") | grep "<"

    echo $'\n'"Unique fields in $SCHEMA2"
    diff <(echo "$FIELDS1") <(echo "$FIELDS2") | grep ">"

    echo $'\n'"Fields changed from $SCHEMA1 to $SCHEMA2"
    for FIELD in $(LC_ALL="c" comm -12 <(echo "$FIELDS1") <(echo "$FIELDS2")); do
        local FULL1=$(expand_field "$SCHEMA1" "$FIELD")
        local FULL2=$(expand_field "$SCHEMA2" "$FIELD")
        if [[ "$FULL1" != "$FULL2" ]]; then
            echo "$FULL1"
            echo "$FULL2"
            echo ""
        fi
    done
}


###############################################################################
# CODE
###############################################################################

check_parameters "$@"
diff_schemas
