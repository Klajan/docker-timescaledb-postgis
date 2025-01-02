#!/bin/bash

set -e

# Skip auto update since it is not wanted
if [ -z ${EXTENSION_AUTOUPDATE+x} ]; then
	exit 0
fi
# We check that this is a new container & if the version has changed (just in case this dir is a volume)
FILE="$INITCHECK_FOLDER/.postgis_init"
if [ -f $FILE ]; then
	value=$(<$FILE)
	if [ "$POSTGIS_VERSION" = "$value" ]; then
		exit 0
	fi
fi
echo "$POSTGIS_VERSION" > $FILE

create_sql=`mktemp`

POSTGIS_VERSION="${POSTGIS_VERSION%%+*}"

cat <<EOF >${create_sql}
SELECT PostGIS_Extensions_Upgrade();
EOF

# Load PostGIS into both template_database and $POSTGRES_DB
for DB in template_postgis "$POSTGRES_DB"; do
    if [ "${DB:-postgres}" != 'postgres' ]; then
		echo "Updating PostGIS extensions '$DB' to $POSTGIS_VERSION"
		psql -X -U "${POSTGRES_USER}" "${DB}" -f ${create_sql}
	fi
done
