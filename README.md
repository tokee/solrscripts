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
