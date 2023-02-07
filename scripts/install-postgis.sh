#!/bin/bash

set -e
create_sql=`tmp`

cat <<EOF >${create_sql}
CREATE DATABASE template_postgis IS_TEMPLATE true;
EOF

# Create the 'template_postgis' template db
psql -U "${POSTGRES_USER}" -f ${create_sql}

cat <<EOF >${create_sql}
CREATE EXTENSION IF NOT EXISTS postgis;
EOF

if [ "${ON_INIT_INSTALL_ALL_EXTENSIONS:-false}" == 'true']; then
cat <<EOF >>${create_sql}
CREATE EXTENSION IF NOT EXISTS postgis_topology;
\c
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;
EOF
fi

# Load PostGIS into both template_database and $POSTGRES_DB
for DB in template_postgis "$POSTGRES_DB"; do
	if [ "${DB:-postgres}" != 'postgres' ]; then
		echo "Loading PostGIS extensions into $DB"
		psql -U "${POSTGRES_USER}" "${DB}" -f ${create_sql}
	fi
done
