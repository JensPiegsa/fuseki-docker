#!/bin/bash

set -e

if [ ! -f "$FUSEKI_BASE/shiro.ini" ] ; then
  # First time
  echo "###################################"
  echo "Initializing Apache Jena Fuseki"
  echo ""
  cp "$FUSEKI_HOME/shiro.ini" "$FUSEKI_BASE/shiro.ini"
  if [ -z "$ADMIN_PASSWORD" ] ; then
    ADMIN_PASSWORD=$(pwgen -s 15)
    echo "Randomly generated admin password:"
    echo ""
    echo "admin=$ADMIN_PASSWORD"
  fi
  echo ""
  echo "###################################"
fi

# $ADMIN_PASSWORD can always override
if [ -n "$ADMIN_PASSWORD" ] ; then
  sed -i "s/^admin=.*/admin=$ADMIN_PASSWORD/" "$FUSEKI_BASE/shiro.ini"
fi

if [ -n "$USER_PASSWORD" ] ; then
  sed -i "s/^user=.*/user=$USER_PASSWORD/" "$FUSEKI_BASE/shiro.ini"
fi

test "${ENABLE_DATA_WRITE}" = true && sed -i 's/\(fuseki:serviceReadGraphStore\)/#\1/' $ASSEMBLER && sed -i 's/#\s*\(fuseki:serviceReadWriteGraphStore\)/\1/' $ASSEMBLER
test "${ENABLE_UPDATE}" = true && sed -i 's/#\s*\(fuseki:serviceUpdate\)/\1/' $ASSEMBLER
test "${ENABLE_UPLOAD}" = true && sed -i 's/#\s*\(fuseki:serviceUpload\)/\1/' $ASSEMBLER
test "${QUERY_TIMEOUT}" && sed -i "s/\(ja:cxtName\s*\"arq:queryTimeout\"\s*;\s*ja:cxtValue\s*\)\"[0-9]*\"/\1\"$QUERY_TIMEOUT\"/" $CONFIG

command=("java" "-cp" "*:/javalibs/*")

if [ -n "$JAVA_ARGS" ] ; then
  command+=("$JAVA_ARGS")
fi

command+=("org.apache.jena.fuseki.cmd.FusekiCmd")

#command+=("--jetty-config=jetty.xml")

# Append any additional arguments
command+=("$@")

echo "Executing: ${command[*]}"

exec "${command[@]}"