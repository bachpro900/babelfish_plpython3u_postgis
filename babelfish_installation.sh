#!/bin/bash

# Install build dependencies for Babelfish for PostgreSQL with PostGIS and plpython3u extensions.
sudo apt update && sudo apt install -y --no-install-recommends\
    build-essential flex libxml2-dev libxml2-utils\
    libxslt-dev libssl-dev libreadline-dev zlib1g-dev\
    libldap2-dev libpam0g-dev gettext uuid uuid-dev\
    cmake lld apt-utils libossp-uuid-dev gnulib bison\
    xsltproc icu-devtools libicu72\
    libicu-dev gawk\
    curl openjdk-17-jre openssl\
    g++ libssl-dev libpq-dev\
    pkg-config libutfcpp-dev\
    gnupg unixodbc-dev net-tools unzip \
    wget python3-dev postgresql-client

# Set environment variables in /etc/prfile and postgresql env. variables.

export USERNAME=babelfish_user
export DATABASE=babelfish_db
export WORKING_DIR=/tmp
export VERSION=4_0_0
export BABELFISH_VERSION=BABEL_${VERSION}__PG_16_1
export PG_SRC=${WORKING_DIR}/${BABELFISH_VERSION}
export POSTGIS_VERSION=3.4.1
export POSTGIS_TAG=postgis-${POSTGIS_VERSION}
export POSTGIS_FILE=${POSTGIS_TAG}.tar.gz
export POSTGIS_SRC=${WORKING_DIR}/postgis/${POSTGIS_TAG}
export BABELFISH_HOME=/opt/babelfish
export PG_CONFIG=${BABELFISH_HOME}/bin/pg_config

export BABELFISH_REPO=babelfish-for-postgresql/babelfish-for-postgresql
export BABELFISH_URL=https://github.com/${BABELFISH_REPO}
export BABELFISH_TAG=${BABELFISH_VERSION}
export BABELFISH_FILE=${BABELFISH_VERSION}.tar.gz

export ANTLR4_VERSION=4.9.3
export ANTLR4_JAVA_BIN=/usr/bin/java
export ANTLR4_RUNTIME_LIBRARIES=/usr/include/antlr4-runtime
export ANTLR_FILE=antlr-${ANTLR4_VERSION}-complete.jar
export ANTLR_EXECUTABLE=/usr/local/lib/${ANTLR_FILE}
export ANTLR_CONTRIB=${PG_SRC}/contrib/babelfishpg_tsql/antlr/thirdparty/antlr
export ANTLR_RUNTIME=${WORKING_DIR}/antlr4

export ANTLR_DOWNLOAD=http://www.antlr.org/download
export ANTLR_CPP_SOURCE=antlr4-cpp-runtime-${ANTLR4_VERSION}-source.zip

export BABELFISH_DATA=/data/babelfish

# Download babelfish sources files
cd $WORKING_DIR
wget ${BABELFISH_URL}/releases/download/${BABELFISH_TAG}/${BABELFISH_FILE}
tar -xvzf ${BABELFISH_FILE}


# Download PostGIS source files
mkdir $WORKING_DIR/postgis
cd $WORKING_DIR/postgis
wget https://download.osgeo.org/postgis/source/${POSTGIS_FILE}
tar -xvzf ${POSTGIS_FILE}


# Compile ANTLR 4
cd $WORKING_DIR
wget ${ANTLR_DOWNLOAD}/${ANTLR_CPP_SOURCE}
unzip -d ${ANTLR_RUNTIME} ${ANTLR_CPP_SOURCE}
sudo cp ${ANTLR_CONTRIB}/${ANTLR_FILE} /usr/local/lib
mkdir ${ANTLR_RUNTIME}/build
cd ${ANTLR_RUNTIME}/build
cmake .. -D \
    ANTLR_JAR_LOCATION=${ANTLR_EXECUTABLE} \
    -DCMAKE_INSTALL_PREFIX=/usr/local -DWITH_DEMO=True
sudo make && sudo make install


# Build modified PostgreSQL for Babelfish
cd ${PG_SRC}
./configure CFLAGS="-ggdb -fcommon" \
    --prefix=/opt/babelfish/ \
    --enable-debug \
    --with-ldap \
    --with-libxml \
    --with-pam \
    --with-uuid=ossp \
    --enable-nls \
    --with-libxslt \
    --with-icu \
    --with-openssl \
    --with-python

sudo make DESTDIR=${BABELFISH_HOME} 2>error.txt && sudo make install
cd ${PG_SRC}/contrib
sudo make && sudo make install


# Compile the ANTLR parser generator
cd ${PG_SRC}/contrib/babelfishpg_tsql/antlr 
cmake -Wno-dev .
make all


# Compile the contrib modules and build Babelfish
cd ${PG_SRC}/contrib/babelfishpg_common
make && sudo make PG_CONFIG=/opt/babelfish/bin/pg_config install

cd ${PG_SRC}/contrib/babelfishpg_money
make && sudo make PG_CONFIG=/opt/babelfish/bin/pg_config install

cd ${PG_SRC}/contrib/babelfishpg_tds
make && sudo make PG_CONFIG=/opt/babelfish/bin/pg_config install

cd ${PG_SRC}/contrib/babelfishpg_tsql
make && sudo make PG_CONFIG=/opt/babelfish/bin/pg_config install


# Compile PostGIS
sudo apt install -y --no-install-recommends \
    libproj-dev libgeos-dev libjson-c-dev libgdal-dev \
    libprotobuf-c-dev protobuf-c-compiler

cd ${POSTGIS_SRC}
./configure
make && sudo make install


sudo mkdir -p ${BABELFISH_DATA}
sudo adduser postgres --home ${BABELFISH_DATA}
sudo chown -R postgres: ${BABELFISH_HOME}
sudo chown -R postgres: ${BABELFISH_DATA}
sudo chmod 750 ${BABELFISH_DATA}
sudo su - postgres


### Initializing the Data directory
${BABELFISH_HOME}/bin/initdb -D ${BABELFISH_DATA}/ -E "UTF8" --lc-collate='C' --lc-ctype='C' --locale-provider='libc'

### Configuring PostgreSQL for Babelfish
cat << EOF >> ${BABELFISH_DATA}/postgresql.conf

#------------------------------------------------------------------------------
# BABELFISH RELATED OPTIONS
# These are going to step over previous duplicated variables.
#------------------------------------------------------------------------------
listen_addresses = '*'
allow_system_table_mods = on
shared_preload_libraries = 'babelfishpg_tds'
babelfishpg_tds.listen_addresses = '*'
EOF

cat <<- EOF >> ${BABELFISH_DATA}/pg_hba.conf
        # Allow all connections
        host    all     all     0.0.0.0/0       md5
        host    all     all     ::0/0               md5
EOF



${BABELFISH_HOME}/bin/pg_ctl -D ${BABELFISH_DATA}/ -l logfile start


${BABELFISH_HOME}/bin/psql -d postgres -U postgres -c "CREATE USER ${USERNAME} WITH SUPERUSER CREATEDB CREATEROLE PASSWORD 'a$@Qo*iUseiZ$' INHERIT;"
${BABELFISH_HOME}/bin/psql -d postgres -U postgres -c "DROP DATABASE IF EXISTS ${DATABASE};"
${BABELFISH_HOME}/bin/psql -d postgres -U postgres -c "CREATE DATABASE ${DATABASE} OWNER ${USERNAME};"


${BABELFISH_HOME}/bin/psql -d ${DATABASE} -U postgres -c "CREATE EXTENSION IF NOT EXISTS "babelfishpg_tds" CASCADE;"
${BABELFISH_HOME}/bin/psql -d ${DATABASE} -U postgres -c "CREATE EXTENSION IF NOT EXISTS "plpython3u" CASCADE;"
${BABELFISH_HOME}/bin/psql -d ${DATABASE} -U postgres -c "CREATE EXTENSION IF NOT EXISTS "postgis" CASCADE;"


${BABELFISH_HOME}/bin/psql -d ${DATABASE} -U postgres -c "GRANT ALL ON SCHEMA sys to ${USERNAME};"
${BABELFISH_HOME}/bin/psql -d ${DATABASE} -U postgres -c "ALTER USER ${USERNAME} CREATEDB;"
${BABELFISH_HOME}/bin/psql -d ${DATABASE} -U postgres -c "ALTER SYSTEM SET babelfishpg_tsql.database_name = ${DATABASE};"
${BABELFISH_HOME}/bin/psql -d ${DATABASE} -U postgres -c "SELECT pg_reload_conf();"


${BABELFISH_HOME}/bin/psql -d ${DATABASE} -U postgres -c "ALTER DATABASE ${DATABASE} SET babelfishpg_tsql.migration_mode = 'multi-db' ;"


${BABELFISH_HOME}/bin/psql -d ${DATABASE} -U postgres -c "ALTER DATABASE bo_production SET "babelfishpg_tsql.escape_hatch_for_replication" TO 'ignore';
ALTER DATABASE bo_production SET "babelfishpg_tsql.escape_hatch_unique_constraint" TO 'ignore';
ALTER DATABASE bo_production SET "babelfishpg_tsql.escape_hatch_nocheck_existing_constraint" TO 'ignore';
ALTER DATABASE bo_production SET "babelfishpg_tsql.escape_hatch_nocheck_add_constraint" TO 'ignore';
ALTER DATABASE bo_production SET "babelfishpg_tsql.escape_hatch_login_misc_options" TO 'ignore';
ALTER DATABASE bo_production SET "babelfishpg_tsql.escape_hatch_ignore_dup_key" TO 'ignore';
ALTER DATABASE bo_production SET "babelfishpg_tsql.escape_hatch_fulltext" TO 'ignore';"


#Finally, initialize the database by calling _sys.initialize_babelfish_:
${BABELFISH_HOME}/bin/psql -d ${DATABASE} -U postgres -c "CALL sys.initialize_babelfish('app_chaine');"





