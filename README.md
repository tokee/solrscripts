# solrscripts

Small scripts for processing Solr files

Requirements: bash, grep & sed (should work under Cygwin as no special tricks are used)


## validate_config.sh

Usage: ./validate_config.sh <solrconfig> <schema>

Checks that
* all fields in schema.xml references existing field types
* all copyFields in schema.xml references existing fields
* all fields referenced in solrconfig.xml are defined in schema.xml
* no aliases in solrconfig.sh has the same name as a field in schema.xml

Sample: Executing
````
 ./validate_config.sh sample/nonexisting/solrconfig.xml sample/nonexisting/schema.xml 
````
results in the output
````
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
````

