FROM golang:buster as tools

ENV TUNE_VERSION v0.14.3
ENV PARALLEL_COPY_VERSION v0.4.0

RUN go install github.com/timescale/timescaledb-tune/cmd/timescaledb-tune@${TUNE_VERSION}
RUN go install github.com/timescale/timescaledb-parallel-copy/cmd/timescaledb-parallel-copy@${PARALLEL_COPY_VERSION}

FROM postgres:15-bullseye as timescale_builder

ENV TIMESCALE_VERSION 2.9.3
ENV DEBIAN_FRONTEND noninteractive
ENV BUILD_PACKAGES="ca-certificates apt-utils curl git gcc make cmake libssl-dev libkrb5-dev postgresql-server-dev-15"

RUN apt-get update && apt-get install -y --no-install-recommends ${BUILD_PACKAGES}
RUN apt-mark auto ${BUILD_PACKAGES}

RUN git clone --branch $TIMESCALE_VERSION --single-branch --depth 1 https://github.com/timescale/timescaledb
WORKDIR "/timescaledb"
RUN ./bootstrap
WORKDIR "/timescaledb/build"
RUN make -j $(nproc)
RUN make install
RUN cat "install_manifest.txt"
WORKDIR "/"

RUN mkdir -p /docker-entrypoint-initdb.d
COPY --chmod=755 ./scripts/install-timescaledb.sh /docker-entrypoint-initdb.d/000_install_timescaledb.sh
RUN curl https://raw.githubusercontent.com/timescale/timescaledb-docker/main/docker-entrypoint-initdb.d/001_timescaledb_tune.sh --output /docker-entrypoint-initdb.d/001_timescaledb_tune.sh \
    && chmod 0755 /docker-entrypoint-initdb.d/001_timescaledb_tune.sh

FROM timescale_builder as postgis_builder

ENV POSTGIS_MAJOR 3

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR \
    postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR-scripts

RUN mkdir -p /docker-entrypoint-initdb.d
COPY --chmod=755 ./scripts/install-postgis.sh /docker-entrypoint-initdb.d/010_init_postgis.sh
COPY --chmod=755 ./scripts/update-postgis.sh /usr/local/bin/update-postgis.sh

FROM postgis_builder as trimmed
RUN rm -rf /timescaledb
RUN apt-get purge -y ${BUILD_PACKAGES}
RUN apt-get -y autoremove
RUN rm -rfv /var/lib/apt/lists/*

FROM postgres:15-bullseye
COPY --from=trimmed / /
COPY --from=tools /go/bin/ /usr/local/bin/
RUN sed -r -i "s/[#]*\s*(shared_preload_libraries)\s*=\s*'(.*)'/\1 = 'timescaledb,\2'/;s/,'/'/" /usr/share/postgresql/$PG_MAJOR/postgresql.conf.sample
