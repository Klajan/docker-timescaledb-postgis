#!/bin/bash

set -e
create_sql=`tmp`

POSTGIS_VERSION="${POSTGIS_VERSION%%+*}"

cat <<EOF >${create_sql}
SELECT PostGIS_Extensions_Upgrade();
EOF

# Load PostGIS into both template_database and $POSTGRES_DB
for DB in template_postgis "$POSTGRES_DB"; do
    if [ "${DB:-postgres}" != 'postgres' ]; then
		 echo "Updating PostGIS extensions '$DB' to $POSTGIS_VERSION"
		psql -U "${POSTGRES_USER}" "${DB}" -f ${create_sql}
	fi
done
