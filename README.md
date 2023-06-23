## TimescaleDB Docker image with Postgis

This image is build with Postgres 15, Postgis 3 and TimescaleDB 2

## How to use this image

This image is based on the official [Postgres docker image](https://store.docker.com/images/postgres) so the documentation for that image also applies here.

### Starting a Postgres instance
```
$ docker run -d -p 5432:5432 docker pull klajan/timescaledb-postgis:latest
```

### Enviroment Variables
- `TIMESCALEDB_TELEMETRY` - Set to `off` to turn off TimescaleDB Telemetry
- `ON_INIT_INSTALL_ALL_EXTENSIONS` - Set to true to install `postgis_topology`, `fuzzystrmatch` & `postgis_tiger_geocoder` on init
- `NO_TS_TUNE` - Set this to skip timescaledb-tune script (see https://github.com/timescale/timescaledb-docker for more information)