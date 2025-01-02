#!/bin/bash

set -e
create_sql=`mktemp`

if [ -z "${POSTGRESQL_CONF_DIR:-}" ]; then
	POSTGRESQL_CONF_DIR=${PGDATA}
fi

cat <<EOF >${create_sql}
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
EOF

TS_TELEMETRY_LEVEL='basic'
if [ "${TIMESCALEDB_TELEMETRY:-}" == "off" ]; then
	TS_TELEMETRY_LEVEL='off'
	# We delete the job as well to ensure that we do not spam the
	# log with other messages related to the Telemetry job.
	cat <<EOF >>${create_sql}
SELECT alter_job(1,scheduled:=false);
EOF
fi

echo "timescaledb.telemetry_level=${TS_TELEMETRY_LEVEL}" >> ${POSTGRESQL_CONF_DIR}/postgresql.conf

# create timescaledb extension in databases
for DB in postgres template1 "$POSTGRES_DB"; do
	if [ "${DB:-postgres}" != 'postgres' ]; then
		echo "Installing TimescaleDB into $DB"
		psql -U "${POSTGRES_USER}" "${DB}" -f ${create_sql}
	fi
done
