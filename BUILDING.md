## How to Build with Docker buildx
NOTE: armv8 does not work at the moment, there are missing dependencies to building timescale

	docker buildx build --push --build-arg BASE_OS=*debian_distro* --pull --tag *docker_tag* --platform=linux/arm64,linux/amd64 .

### BUILD ARGS
- `PG_VERSION` - Postgres Major Version (default: 15)
- `BASE_OS` - Base OS to use (default: bookworm)
- `TS_VERSION` - Timescale Version to use (default: 2.17.2)
- `POSTGIS_MAJOR` -  Postgis Major version to use (default: 3)
- `TS_TUNE_VERSION` - Version/Tag of Timescale Tune to use (default: v0.18.0)
- `TS_PARALLEL_COPY_VERSION` - Version/Tag of Timescale Parallel Copy to use (default: v0.7.1)
- `TS_TOOLKIT_VERSION` - Timescale Toolkit currently not included