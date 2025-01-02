#!/bin/bash

set -e

# Skip auto update since it is not wanted
if [ -z ${EXTENSION_AUTOUPDATE+x} ]; then
	exit 0
fi
# We check that this is a new container & if the version has changed (just in case this dir is a volume)
FILE="$INITCHECK_FOLDER/.timescaledb_init"
if [ -f $FILE ]; then
	value=$(<$FILE)
	if [ "$TIMESCALE_VERSION" = "$value" ]; then
		exit 0
	fi
fi
echo "$TIMESCALE_VERSION" > $FILE

create_sql=`mktemp`

cat <<EOF >${create_sql}
ALTER EXTENSION timescaledb UPDATE;
EOF

for DB in postgres template1 "$POSTGRES_DB"; do
	if [ "${DB:-postgres}" != 'postgres' ]; then
		echo "Updating TimescaleDB in $DB to version $TIMESCALE_VERSION"
		psql -X -U "${POSTGRES_USER}" "${DB}" -f ${create_sql}
	fi
done