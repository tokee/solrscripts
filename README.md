# solrscripts

Small scripts for processing Solr files

Requirements: bash (should work under Cygwin as no special tricks are used)


## validate_config.sh

Usage: ./validate_config.sh  <solrconfig> <schema>

* Checks that all fields in schema.xml references existing field types
* Checks that all fields referenced in solrconfig.xml are defined in schema.xml
