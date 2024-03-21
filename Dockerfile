ARG JAVA_VERSION=21

FROM eclipse-temurin:${JAVA_VERSION}-alpine AS base

LABEL maintainer="piegsa@gmail.com"

RUN apk update && \
    apk add --no-cache bash pwgen wget

# Update below according to htps://jena.apache.org/download/
#ENV FUSEKI_WAR_SHA512 a5b724ae1cc088888d6055d46957a96b1717a1ac9d42438cfec72c8f6cc9f8eefd1a13fe159423d48075e166fa0ec745309ffddb72735cc36ee27715bcb4f0dc
ENV FUSEKI_SHA512 a4be52cc5f7f8767e362f893f28721f2887a3544ed779cd58fe0b32733575d97411b5a3bc2243995d6408e545bdefc5ab41c00b2c5d074df1dc0ca5063db5f83
ENV FUSEKI_VERSION 4.10.0
ENV JENA_SHA512 c1097988fda802d157d031ba79007fd949a8ca2556bb383134021f48b44ade511ba6e2690ac4b1548c57df0476267f18ffce94101a87e094c0a161a78766d341
ENV JENA_VERSION 4.10.0

ENV MIRROR https://dlcdn.apache.org
ENV ARCHIVE http://archive.apache.org/dist

# Config and data
ENV FUSEKI_BASE /fuseki-base

# Fuseki installation
ENV FUSEKI_HOME /jena-fuseki

ENV JENA_HOME /jena
ENV JENA_BIN $JENA_HOME/bin

WORKDIR /tmp
# sha512 checksum
RUN echo "$FUSEKI_SHA512  fuseki.tar.gz" > fuseki.tar.gz.sha512
# Download/check/unpack/move Fuseki in one go (to reduce image size)
RUN wget -O fuseki.tar.gz $MIRROR/jena/binaries/apache-jena-fuseki-$FUSEKI_VERSION.tar.gz || \
    wget -O fuseki.tar.gz $ARCHIVE/jena/binaries/apache-jena-fuseki-$FUSEKI_VERSION.tar.gz && \
    sha512sum -c fuseki.tar.gz.sha512 && \
    tar zxf fuseki.tar.gz && \
    mv apache-jena-fuseki* $FUSEKI_HOME && \
    rm fuseki.tar.gz* && \
    cd $FUSEKI_HOME && rm -rf fuseki.war

## sha512 checksum
#RUN echo "$FUSEKI_WAR_SHA512  fuseki.war" > fuseki.war.sha512
## Download/check/unpack/move Fuseki in one go (to reduce image size)
#RUN wget -O fuseki.war $MIRROR/jena/binaries/jena-fuseki-war-$FUSEKI_VERSION.war || \
#    wget -O fuseki.war $ARCHIVE/jena/binaries/jena-fuseki-war-$FUSEKI_VERSION.war || \
#    sha512sum -c fuseki.war.sha512 &&  \
    
# Get tdbloader2 from Jena
# sha512 checksum
RUN echo "$JENA_SHA512  jena.tar.gz" > jena.tar.gz.sha512
# Download/check/unpack/move Jena in one go (to reduce image size)
RUN wget -O jena.tar.gz $MIRROR/jena/binaries/apache-jena-$JENA_VERSION.tar.gz || \
    wget -O jena.tar.gz $ARCHIVE/jena/binaries/apache-jena-$JENA_VERSION.tar.gz && \
    sha512sum -c jena.tar.gz.sha512 && \
    tar zxf jena.tar.gz && \
	mkdir -p $JENA_BIN && \
	mv apache-jena*/lib $JENA_HOME && \
	mv apache-jena*/bin/tdbloader2* $JENA_BIN && \
    rm -rf apache-jena* && \
    rm jena.tar.gz*

# As "localhost" is often inaccessible within Docker container,
# we'll enable basic-auth with a random admin password
# (which we'll generate on start-up)
COPY shiro.ini /jena-fuseki/shiro.ini
COPY docker-entrypoint.sh /
RUN chmod 755 /docker-entrypoint.sh

#COPY jetty.xml /jena-fuseki/jetty.xml

# SeCo extensions
COPY silk-arq-1.0.0-SNAPSHOT-with-dependencies.jar /javalibs/

# Fuseki config
ENV ASSEMBLER $FUSEKI_BASE/configuration/assembler.ttl
COPY assembler.ttl $ASSEMBLER
ENV CONFIG $FUSEKI_BASE/config.ttl
COPY fuseki-config.ttl $CONFIG
RUN mkdir -p $FUSEKI_BASE/databases

# Set permissions to allow fuseki to run as an arbitrary user
RUN chgrp -R 0 $FUSEKI_BASE \
    && chmod -R g+rwX $FUSEKI_BASE

# Tools for loading data
ENV JAVA_CMD java -cp "$FUSEKI_HOME/fuseki-server.jar:/javalibs/*"
ENV TDBLOADER $JAVA_CMD tdb.tdbloader --desc=$ASSEMBLER
ENV TDBLOADER2 $JENA_BIN/tdbloader2 --loc=$FUSEKI_BASE/databases/tdb
ENV TDB2TDBLOADER $JAVA_CMD tdb2.tdbloader --desc=$ASSEMBLER
ENV TEXTINDEXER $JAVA_CMD jena.textindexer --desc=$ASSEMBLER
ENV TDBSTATS $JAVA_CMD tdb.tdbstats --desc=$ASSEMBLER
ENV TDB2TDBSTATS $JAVA_CMD tdb2.tdbstats --desc=$ASSEMBLER

WORKDIR /jena-fuseki
EXPOSE 3030
USER 9008

ENTRYPOINT ["/docker-entrypoint.sh"]
