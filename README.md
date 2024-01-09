# solrscripts

Small scripts for processing Solr files

Requirements: bash, grep & sed (should work under Cygwin as no special tricks are used)

Configuration is in ./general.conf

## schema_diff.sh

Compares the fields and their primary values between two schemas. Usable for knowing what
has changed between different versions of Solr setups.

Usage: ./schema_diff.sh <schema1> <schema2>

Sample: Executing
```
./schema_diff.sh sample/nonexisting/schema.xml sample/nonexisting/schema_changed.xml 
```
results in the output
```
Unique fields in sample/nonexisting/schema.xml
< _src_

Unique fields in sample/nonexisting/schema_changed.xml
> manu_custom

Fields changed from sample/nonexisting/schema.xml to sample/nonexisting/schema_changed.xml
<field name="content_type" type="string" class="solr.StrField" indexed="true" stored="true" docValues="false" multiValued="true" />
<field name="content_type" type="string" class="solr.StrField" indexed="true" stored="true" docValues="false" multiValued="false" />

<field name="links" type="string" class="solr.StrField" indexed="true" stored="true" docValues="false" multiValued="true" />
<field name="links" type="string" class="solr.StrField" indexed="true" stored="false" docValues="true" multiValued="true" />

<field name="resourcename" type="text_general" class="solr.TextField" indexed="true" stored="true" docValues="false" multiValued="false" />
<field name="resourcename" type="text_general" class="solr.TextField" indexed="false" stored="true" docValues="false" multiValued="false" />
```


## validate_config.sh

Usage: ./validate_config.sh <solrconfig> <schema>

Checks that
* all fields in schema.xml references existing field types
* all copyFields in schema.xml references existing fields
* all fields referenced in solrconfig.xml are defined in schema.xml
* no aliases in solrconfig.sh has the same name as a field in schema.xml

Sample: Executing
```
 ./validate_config.sh sample/nonexisting/solrconfig.xml sample/nonexisting/schema.xml 
```
results in the output
```
Checking schema fields and dynamicFields
   Solr schema entry field with name 'price' referenced fieldType 'nonfloat', which is not defined in schema
   Solr schema entry field with name 'store' referenced fieldType 'nonlocation', which is not defined in schema
   Solr schema entry dynamicField with name '*_f' referenced fieldType 'nonfloat', which is not defined in schema
Checking schema copyFields
   Solr schema copyField from 'nonincludes' to 'text' is invalid as the source is not defined in schema
   Solr schema copyField from 'price' to 'price_c' is invalid as the destination is not defined in schema
   Solr schema copyField from 'author' to 'nontext' is invalid as the destination is not defined in schema
   Solr schema copyField from 'nonresourcename' to 'nontext' is invalid as the source is not defined in schema
   Solr schema copyField from 'nonresourcename' to 'nontext' is invalid as the destination is not defined in schema
   Solr schema copyField from 'author' to 'author_s' is invalid as the destination is not defined in schema
Checking aliases
   Solr config alias 'f.manu.qf' is illegal as schema already has field 'manu'
Checking .*qf
   Solr config param 'qf' referenced field 'nonkeywords', which is not defined in schema
   Solr config param 'mlt.qf' referenced field 'nonresourcename', which is not defined in schema
Checking pf
Checking facet.field
   Solr config param 'facet.field' referenced field 'noncontent_type', which is not defined in schema
   Solr config param 'facet.field' referenced field 'author_s', which is not defined in schema
Checking facet.range
   Solr config param 'facet.range' referenced field 'nonpopularity', which is not defined in schema
   Solr config param 'facet.range' referenced field 'manufacturedate_dt', which is not defined in schema
Checking .*.fl
   Solr config param 'mlt.fl' referenced field 'nonresourcename', which is not defined in schema
   Solr config param 'hl.fl' referenced field 'nonname', which is not defined in schema
Checking facet.pivot
   Solr config param 'facet.pivot' referenced field 'noninStock', which is not defined in schema
Checking .*hl.alternateField
   Solr config param 'f.title.hl.alternateField' referenced field 'nontitle', which is not defined in schema
```

## get_solr.sh

Downloads and prepares Solr and ZooKeeper for later install

## saturation_test.sh

### Tool for finding the saturation point of Solr requests.

Takes a file with queries and spawns X threads issuing 1/X of those queries as fast as they can. 
At the end, throughput and average latency is reported.

To avoid skewing the results by everithing being cached, consider dropping
the disk cache between tests and let the script warm up the searcher.
## get_solr.sh
### Downloads and prepares Solr and ZooKeeper for later install


## cloud_*.sh

Scripts for installing & controlling SolrClouds.


## cloud_alias.sh

Lists or creates aliases for Solrcloud

Usage: ./cloud_alias.sh [alias [collections]]
 
*  List all aliases: ./cloud_alias.sh
*  List collections in alias: ./cloud_alias.sh alias
*  Create alias: ./cloud_alias.sh alias collection1,collection2,collection3

## cloud_delete.sh

Deletes a SolrCloud collection

Usage: ./cloud_delete.sh collection

TODO: Figure out which cloud is running and stop it, so that version need not be specified

## cloud_install.sh

Installs a specific SolrCloud

Usage: ./cloud_install.sh <`echo \"$VERSIONS\" | sed 's/ / | /g'`>

## cloud_optimize.sh

Optimize a SolrCloud collection

Deprecated (read: Never used)

## cloud_start.sh

Starts a specific SolrCloud

Usage: ./cloud_start.sh <`echo \"$VERSIONS\" | sed 's/ / | /g'`>

TODO: Increase 5 second timeout on shutdown to avoid stale write.lock

## cloud_status.sh

Lists collections and configurations in the cloud

Usage: `./cloud_status.sh`

Specify Solr port with `SOLR_BASE_PORT=xxxx ./cloud_status.sh`
    
Requirements: jq

## cloud_stop.sh

Stops a specific SolrCloud

Usage: `./cloud_start.sh <`echo \"$VERSIONS\" | sed 's/ / | /g'`>`

TODO: 
* Figure out which cloud is running and stop it, so that version need not be specified
* In case of hard stop, remove write.lock

## cloud_sync.sh

Uploads configurations and creates collections in SolrCloud

Usage: `./cloud_sync.sh <`echo \"$VERSIONS\" | sed 's/ / | /g'`> <config_folder> <config_id> [collection]`

If VERSION is specified in custom.conf, it can be skipped, reducing the call to
   `./cloud_sync.sh <config_folder> <config_id> [collection]`

## cloud_verify.sh

Verifies that Solr is up and running with a specified collection

Reports either total hitCount or "na"

Usage: `./cloud_verify.sh <$VLIST> <collection>`

## TODO: Expand this description.
