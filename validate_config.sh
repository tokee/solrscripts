#!/bin/bash

#
# Simple validation of field names & references in Solr setup files
#
# Caveat: This does not handle comments in XML properly
#
# Created 2015 by Toke Eskildsen <te@ekot.dk>
# License: Apache 2.0 http://www.apache.org/licenses/LICENSE-2.0
#

function usage() {
    echo "Usage: ./validate_config.sh <solrconfig> <schema>"
    exit
}

CONFIG="$1"
if [ -z $2 ]; then
    SCHEMA=`dirname "$CONFIG"`/schema.xml
else
    SCHEMA="$2"
fi
if [ ! -s "$CONFIG" ]; then
    echo "Error: No solr config '$CONFIG'"
    usage
fi
if [ ! -s "$SCHEMA" ]; then
    echo "Error: No solr schema '$SCHEMA'"
    usage
fi

# Removes all comments
function pipe_xml() {
    cat "$1" | sed 's/<!--.*-->//' | sed '/<!--/,/-->/d' | tr '\n' ' '
}

# Extracts all field names from schema
function get_field_names() {
    pipe_xml "$SCHEMA" | grep -o "<\(dynamic\)\?[fF]ield[^>]\+name=[\"'][^_][^\"']*[\"'][^>]*>" | sed "s/.*name=[\"\']\([^\"\']\+\).*/\1/"
}

# Extracts all fieldtypes from schema
function get_field_types() {
    pipe_xml "$SCHEMA" | grep -o "<fieldType[^>]\+name=\"[^_][^\"']*[\"'][^>]*>" | sed "s/.*name=[\"']\([^\"']\+\).*/\1/"
}

# Checks that schema fields references existing fieldTypes
function check_schema_fields() {
    echo "Checking schema fields and dynamicFields"
    local SFIELDS=`cat "$SCHEMA" | tr '\n' ' ' | grep -o "<\(dynamic\)\?[fF]ield [^>]*>"`
    while read -r SFIELD; do
        local DESIGNATION=`echo "$SFIELD" | sed 's/<\([^ ]\+\).*/\1/'`
        local NAME=`echo "$SFIELD" | sed "s/.*name=[\"']\([^\"']\+\)[\"'].*/\1/"`
        local TYPE=`echo "$SFIELD" | sed "s/.*type=[\"']\([^\"']\+\)[\"'].*/\1/"`
        if [ "." == ".`echo \"$TYPES\" | grep \"$TYPE\"`" ]; then
            echo "   Solr schema entry $DESIGNATION with name '$NAME' referenced fieldType '$TYPE', which is not defined in schema"
            VALERROR=true
        fi
    done <<< "$SFIELDS"
}

# Checks that copyFields in schema references existing fields
function check_schema_copy_fields() {
    echo "Checking schema copyFields"
    local SFIELDS=`pipe_xml "$SCHEMA" | grep -o "<copyField [^>]*>"`
    while read -r SFIELD; do
        local SOURCE=`echo "$SFIELD" | sed "s/.*source=[\"']\([^\"']*\)[\"'].*/\1/"`
        local DEST=`echo "$SFIELD" | sed "s/.*dest=[\"']\([^\"']*\)[\"'].*/\1/"`
        if [ "*" == "$SOURCE" ]; then
            continue
        fi
        if [ "." == ".$SOURCE" ]; then
            echo "   Solr schema copyField from '$SOURCE' to '$DEST' is invalid as the source is empty"
            VALERROR=true
            continue
        fi
        if [ "." == ".$DEST" ]; then
            echo "   Solr schema copyField from '$SOURCE' to '$DEST' is invalid as the destination is empty"
            VALERROR=true
            continue
        fi
        if [ "." == ".`echo \"$FIELDS\" | grep \"$SOURCE\"`" ]; then
            echo "   Solr schema copyField from '$SOURCE' to '$DEST' is invalid as the source is not defined in schema"
            VALERROR=true
        fi
        if [ "." == ".`echo \"$FIELDS\" | grep $DEST`" ]; then
            echo "   Solr schema copyField from '$SOURCE' to '$DEST' is invalid as the destination is not defined in schema"
            VALERROR=true
        fi
    done <<< "$SFIELDS"
}

# Checks that aliases in solr config does not clash with fields in schema
# (alias name must not be a field)
function check_config_aliases() {
    echo "Checking config aliases and groups"
    local ALIASES=`pipe_xml "$CONFIG" | grep -o "<[^>]\+name=[\"']f[.][^.\"']\+[.]qf[\"']" | sed -e "s/.*name=[\"']f[.]\([^\"']\+\)[.]qf[\"'].*/\1/g"`
    while read -r ALIAS; do
        if [ "." != ".`echo \"$FIELDS\" | grep \"^$ALIAS$\"`" ]; then
            echo "   Solr config alias 'f.$ALIAS.qf' is illegal as schema already has field '$ALIAS'"
            VALERROR=true
        fi
    done <<< "$ALIASES"
}

# Checks that all fields used by the parameter exists in $FIELDS from schema.xml
# Input:  parameter-key regexp
# Sample: [^\"]*[.]\?qf
function check_config_fields() {
    local KEY="$1"
    echo "Checking config ${2-$KEY}"

    local PARAMS=`pipe_xml "$CONFIG" | grep -o "<[^>]\+name=[\"']${KEY}[\"'][^>]*>[^<]*</[^>]\+>" | sed -e 's/[ ,]\+/ /g' -e 's/\^[0-9.]\+//g'`
    if [ "." == ".$PARAMS" ]; then
        return
    fi
    while read -r PARAM; do
        local KEY=`echo "$PARAM" | sed "s/<[^>]*name=[\"']\([^\"']\+\)[\"'].*/\1/"`
        local CFIELDS=`echo "$PARAM" | sed 's/[^>]*>\([^<]*\).*/\1/'`
        if [ "." == ".$CFIELDS" ]; then
            echo "   Solr config param '$KEY' had no fields as arguments"
            VALERROR=true
            continue
        fi
        for CFIELD in $CFIELDS; do
            if [ "." == ".`echo \"$FIELDS\" | grep \"^$CFIELD$\"`" ]; then
                echo "   Solr config param '$KEY' referenced field '$CFIELD', which is not defined in schema"
                VALERROR=true
            fi
        done
    done <<< "$PARAMS"
}

# Checks that field names and attributes has the correct versality
# Example: Writing <fieldtype ...> is wrong; it should be fieldType ...>
function check_schema_versality() {
    echo "Checking schema field name versality"
    # Important: Remember the trailing space
    local VALID="analyzer copyField defaultSearchField dynamicField field fields fieldType filter schema solrQueryParser charFilter tokenizer types uniqueKey "
    local LVALID=`echo "$VALID" | tr '[:upper:]' '[:lower:]'`

    local PRESENT_SCHEMA_FIELDS=`cat "$SCHEMA" | grep -o -h "<[a-zA-Z]\+" | sort | uniq | sed 's/<//' | tr '\n' ' '`
    for PRESENT in `echo $PRESENT_SCHEMA_FIELDS`; do
        local MATCH=`echo "$VALID" | grep "$PRESENT "`
        if [ "." == ".$MATCH" ]; then
            LPRESENT=`echo $PRESENT | tr '[:upper:]' '[:lower:]'`
            local LMATCH=`echo "$LVALID" | grep "$LPRESENT "`
            if [ "." == ".$LMATCH" ]; then
                echo "   Unknown tag in schema (might be okay): '$PRESENT'"
            else
                VALERROR=true
                # Wrong versality. Try finding the right tag
                FOUND=false
                for V in $VALID; do
                    LV=`echo $V | tr '[:upper:]' '[:lower:]'`
                    if [ "$LPRESENT" == "$LV" ]; then
                        FOUND=true
                        echo "   Tag '$PRESENT' should be written as '$V'"
                        break
                    fi
                done
                if [ "false" == "$FOUND" ]; then
                    echo "   Internal error: Correct versality of tag '$PRESENT' could not be determined"
                fi
            fi
        fi
    done
}

# echo "Processing config $CONFIG and schema $SCHEMA"

FIELDS=`get_field_names`
if [ "." == ".$FIELDS" ]; then
    echo "Warning: Unable to locate any fields in ${SCHEMA}"
fi
TYPES=`get_field_types`
if [ "." == ".$FIELDS" ]; then
    echo "Warning: Unable to locate any field types in ${SCHEMA}"
fi
VALERROR=false

# solr schema validation
check_schema_fields
check_schema_copy_fields
check_schema_versality

# solr config validation
check_config_aliases
check_config_fields "[^\"']*[.]\?qf"             "query fields: .*qf"
check_config_fields "pf"                         "phrase fields: pf"
check_config_fields "facet[.]field"              "facet fields: facet.field"
check_config_fields "facet[.]range"              "facet range: facet.range"
check_config_fields "[^\"']*[.]fl"               "fields: .*.fl"
check_config_fields "facet[.]pivot"              "pivot faceting: facet.pivot"
check_config_fields "[^\"']*hl[.]alternateField" "highlight alternate field: .*hl.alternateField"


if [ "false" == "$VALERROR" ]; then
    echo "Done with no errors detected"
fi
