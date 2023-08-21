#!/bin/bash

set -e
create_sql=`tmp`

cat <<EOF >${create_sql}
SELECT installed_version FROM pg_available_extensions WHERE name = 'timescaledb';
EOF
cat <<EOF >${create_sql}
SELECT default_version INTO dv, installed_version INTO iv FROM pg_available_extensions WHERE name = 'timescaledb'
IF dv != iv THEN
;
EOF


for DB in postgres template1 "$POSTGRES_DB"; do
	if [ "${DB:-postgres}" != 'postgres' ]; then
		echo "Checking TimescaleDB version in $DB"
		psql -X -U "${POSTGRES_USER}" "${DB}" -f ${create_sql}
	fi
done