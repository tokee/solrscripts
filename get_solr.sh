#!/bin/bash

#
# Downloads and prepares Solr and ZooKeeper for later install
#

pushd ${BASH_SOURCE%/*} > /dev/null
source general.conf

mkdir -p cache
pushd cache > /dev/null

function download() {
    if [ -s $2 ]; then
        echo "- Already downloaded $2"
        return
    fi
    echo "- Downloading $2"
    wget -q "$1" -O $2
}

function ensuresource() {
    if [ -d lucene-solr ]; then
        echo "- Git repository for lucene-solr aready available"
        return
    fi
    echo "- Cloning $SOLR_REPOSITORY"
    git clone $SOLR_REPOSITORY
}
    
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
download "http://archive.apache.org/dist/lucene/solr/5.5.4/solr-5.5.4.tgz" solr-5.5.4.tgz
download "http://archive.apache.org/dist/lucene/solr/6.6.1/solr-6.6.1.tgz" solr-6.6.1.tgz
download "http://archive.apache.org/dist/lucene/solr/7.0.1/solr-7.0.1.tgz" solr-7.0.1.tgz
download "$ZOO_URL" `basename "$ZOO_URL"`

# Compile time. Version should match https://issues.apache.org/jira/browse/LUCENE-7521
# Meaning around 2016-10-25 14:04
if [ ! -s solr-trunk.tgz ]; then
    ensuresource

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

popd > /dev/null
