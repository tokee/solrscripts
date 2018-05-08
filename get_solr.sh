#!/bin/bash

#
# Downloads and prepares Solr and ZooKeeper for later install
#

pushd ${BASH_SOURCE%/*} > /dev/null
source general.conf
# Optionally only download a specific Solr
: ${SPECIFIC_SOLR:="$1"}

mkdir -p cache
pushd cache > /dev/null

download() {
    if [ -s $2 ]; then
        echo "- Already downloaded $2"
        return
    fi
    echo "- Downloading $2"
    wget -q "$1" -O $2
    if [ ! -s $2 ]; then
        >&2 echo "Error: Unable to download $1"
        ## Same request as before, but without the quiet option, so that the user sees the error
        wget "$1" -O $2
        if [ ! -s $2 ]; then
            exit 5
        fi
        echo "- Retrying caused the resource to be downloaded. Pixie involvement suspected"
    fi
}

ensure_source() {
    if [[ "." == .$(grep trunk <<< "$VERSIONS") ]]; then
        return
    fi
    if [ -d lucene-solr ]; then
        echo "- Git repository for lucene-solr aready available"
        return
    fi
    echo "- Cloning $SOLR_REPOSITORY (might take several minutes)"
    git clone $SOLR_REPOSITORY
}

compile_trunk() {
    if [[ "." == .$(grep trunk <<< "$VERSIONS") ]]; then
        return
    fi
    
    # Compile time. Version should match https://issues.apache.org/jira/browse/LUCENE-7521
    # Meaning around 2016-10-25 14:04
    if [ ! -s solr-trunk.tgz ]; then
        ensure_source
        
        echo "- Building Solr trunk (takes several minutes)"
        pushd lucene-solr > /dev/null
        git reset --hard
        git checkout $SOLR_TRUNK_HASH
        pushd solr > /dev/null
        ant clean > build.log
        ant package >> build.log
        popd > /dev/null
        popd > /dev/null
        if [ ! -s lucene-solr/solr/package/solr-7.0.0-SNAPSHOT.tgz ]; then
            2&> echo "Error: Unable to build solr-7.0.0-SNAPSHOT.tgz"
            exit 2
        fi
        cp lucene-solr/solr/package/solr-7.0.0-SNAPSHOT.tgz solr-trunk.tgz
    fi

    if [ ! -s solr-trunk-7521.tgz ]; then
        pushd lucene-solr > /dev/null
        git reset --hard
        git checkout $SOLR_TRUNK_HASH
        echo "- Downloading and applying LUCENE-7521 patch"
        curl -s "$PATCH7521" > LUCENE-7521.patch
        patch -p1 < LUCENE-7521.patch
        
        echo "- Building Solr trunk with LUCENE-7521 patch"
        pushd solr > /dev/null
        ant clean > build.log
        ant package >> build.log
        popd > /dev/null
        popd > /dev/null
        if [ ! -s lucene-solr/solr/package/solr-7.0.0-SNAPSHOT.tgz ]; then
            2&> echo "Error: Unable to build solr-7.0.0-SNAPSHOT.tgz"
            exit 2
        fi
        cp lucene-solr/solr/package/solr-7.0.0-SNAPSHOT.tgz solr-trunk-7521.tgz
    fi
}

# "4.10.4 4.10.4-sparse 5.5.5 6.6.2 7.1.0 7.2.1 7.3.0 trunk"
resolve_multi() {
    for S in $1; do
        
        if [[ "4.10.4-sparse" == "$S" ]]; then
            # Authenticated redirect to AWS that is not automated yet
            if [ ! -s sparse-4.10.war ]; then
                download "https://github.com/tokee/lucene-solr/releases/download/sparse_4.10_20150730-alpha/solr-4.10-SNAPSHOT-heuristic-SOLR-5894-20150730-1235.war" sparse-4.10.war
                
                if [ ! -s sparse-4.10.war ]; then
                    echo "Please download solr-4.10-SNAPSHOT-heuristic-SOLR-5894-20150730-1235.war from https://github.com/tokee/lucene-solr/releases/ and save it in the cache folder with the name sparse-4.10.war"
                    exit 1
                fi
            else
                echo "- Already downloaded sparse-4.10.war"
            fi
            download "http://archive.apache.org/dist/lucene/solr/4.10.4/solr-4.10.4.tgz" solr-4.10.4.tgz
        elif [[ "trunk" == "$S" ]]; then
            compile_trunk
        else
            download "http://archive.apache.org/dist/lucene/solr/${S}/solr-${S}.tgz" solr-${S}.tgz
        fi
    done
}

download "$ZOO_URL" `basename "$ZOO_URL"`
if [[ ! -z "$SPECIFIC_SOLR" ]]; then
    echo "Downloading specified Solr '$SPECIFIC_SOLR'"
    resolve_multi "$SPECIFIC_SOLR"
else
    echo "Downloading all supported Solrs '$VERSIONS trunk'"
    resolve_multi "$VERSIONS trunk"
fi

popd > /dev/null
