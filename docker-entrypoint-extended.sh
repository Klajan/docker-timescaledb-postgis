#!/bin/bash

source /usr/local/bin/docker-entrypoint.sh

# arguments to this script are assumed to be arguments to the "postgres" server (same as "docker-entrypoint.sh"), and most "docker-entrypoint.sh" functions assume "postgres" is the first argument (see "_main" over there)
if [ "$#" -eq 0 ] || [ "$1" != 'postgres' ]; then
	set -- postgres "$@"
fi
# see also "_main" in "docker-entrypoint.sh"
docker_setup_env
# setup data directories and permissions (when run as root)
docker_create_db_directories

if [ "$(id -u)" = '0' ]; then
	# then restart script as postgres user
	exec gosu postgres "$BASH_SOURCE" "$@"
fi

INIT_FILE="$INITCHECK_FOLDER/.init_done";
should_run_init=0;

if [ ! -f $INIT_FILE ] || [ -z "$DATABASE_ALREADY_EXISTS" ]; then
	should_run_init=1
fi


# Run this only when needed
if [ $should_run_init -ge 1 ]; then
	# only run initialization on an empty data directory
	if [ -z "$DATABASE_ALREADY_EXISTS" ]; then
		docker_verify_minimum_env

		# check dir permissions to reduce likelihood of half-initialized database
		ls /docker-entrypoint-initdb.d/ > /dev/null

		docker_init_database_dir
		pg_setup_hba_conf "$@"

		# PGPASSWORD is required for psql when authentication is required for 'local' connections via pg_hba.conf and is otherwise harmless
		# e.g. when '--auth=md5' or '--auth-local=md5' is used in POSTGRES_INITDB_ARGS
		export PGPASSWORD="${PGPASSWORD:-$POSTGRES_PASSWORD}"
		docker_temp_server_start "$@"

		docker_setup_db
		docker_process_init_files /docker-entrypoint-initdb.d/*

		cat <<-'EOM'

			PostgreSQL init process complete; ready for start up.

		EOM
	else
		docker_temp_server_start "$@"

		cat <<-'EOM'

			PostgreSQL Database directory appears to contain a database; Skipping initialization

		EOM
	fi

	# Now we run our own init scripts
	# these will run even if the db is already initialized

	for file in /always-init.d/*.sh; do
		if [ -x "$file" ]; then
			printf '%s: running %s\n' "$0" "$f"
			"$file"
		fi
	done
	for file in /always-init.d/*.sql; do
		if [ -f "$file" ]; then
			printf '%s: running %s\n' "$0" "$f"
			docker_process_sql -f "$f"; printf
		fi
	done

	docker_temp_server_stop
	unset PGPASSWORD
else
	cat <<-'EOM'

			Container appears to be unchanged; Skipping initialization.

	EOM
fi

touch $INIT_FILE

exec "$@"