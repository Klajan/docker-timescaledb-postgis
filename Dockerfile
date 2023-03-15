ARG PG_VERSION=15
ARG TUNE_VERSION_DEFAULT=v0.14.3
ARG PARALLEL_COPY_VERSION_DEFAULT=v0.4.0
ARG TIMESCALE_VERSION_DEFAULT=2.10.1
ARG TIMESCALE_TOOLKIT_VERSION_DEFAULT=1.13.1
ARG POSTGIS_MAJOR_DEFAULT=3

FROM golang:buster as go_tools
ARG TUNE_VERSION_DEFAULT
ARG PARALLEL_COPY_VERSION_DEFAULT
ENV TUNE_VERSION $TUNE_VERSION_DEFAULT
ENV PARALLEL_COPY_VERSION $PARALLEL_COPY_VERSION_DEFAULT

RUN go install github.com/timescale/timescaledb-tune/cmd/timescaledb-tune@${TUNE_VERSION}
RUN go install github.com/timescale/timescaledb-parallel-copy/cmd/timescaledb-parallel-copy@${PARALLEL_COPY_VERSION}

FROM postgres:${PG_VERSION}-bullseye as timescale_builder
ARG TIMESCALE_VERSION_DEFAULT
ARG POSTGIS_MAJOR_DEFAULT
ENV TIMESCALE_VERSION $TIMESCALE_VERSION_DEFAULT
ENV POSTGIS_MAJOR $POSTGIS_MAJOR_DEFAULT
ENV DEBIAN_FRONTEND noninteractive
ENV BUILD_PACKAGES="ca-certificates apt-utils curl git gcc make cmake libssl-dev libkrb5-dev postgresql-server-dev-${PG_MAJOR} pkg-config clang"

RUN apt-get update && apt-get install -y --no-install-recommends ${BUILD_PACKAGES}
RUN apt-mark auto ${BUILD_PACKAGES}

RUN git clone --branch $TIMESCALE_VERSION --single-branch --depth 1 https://github.com/timescale/timescaledb
WORKDIR "/timescaledb"
RUN ./bootstrap \
    && cd build \
    && make -j $(nproc) \
    && make install
RUN cat "/timescaledb/build/install_manifest.txt"
WORKDIR "/"

RUN mkdir -p /docker-entrypoint-initdb.d
COPY --chmod=755 ./scripts/install-timescaledb.sh /docker-entrypoint-initdb.d/000_install_timescaledb.sh
RUN curl https://raw.githubusercontent.com/timescale/timescaledb-docker/main/docker-entrypoint-initdb.d/001_timescaledb_tune.sh --output /docker-entrypoint-initdb.d/001_timescaledb_tune.sh \
    && chmod 0755 /docker-entrypoint-initdb.d/001_timescaledb_tune.sh

RUN rm -rf /timescaledb
RUN apt-get purge -y ${BUILD_PACKAGES} \
    && apt-get -y autoremove

FROM postgres:${PG_VERSION}-bullseye as postgis_install
ARG POSTGIS_MAJOR_DEFAULT
ENV POSTGIS_MAJOR $POSTGIS_MAJOR_DEFAULT

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR-scripts \
    postgresql-$PG_MAJOR-postgis-$POSTGIS_MAJOR \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
            /var/cache/debconf/* \
            /usr/share/doc \
            /usr/share/man \
            /usr/share/locale/?? \
            /usr/share/locale/??_?? \
    && find /var/log -type f -exec truncate --size 0 {} \;

FROM postgis_install as final
ARG POSTGIS_MAJOR_DEFAULT
ARG TUNE_VERSION_DEFAULT
ARG PARALLEL_COPY_VERSION_DEFAULT
ARG TIMESCALE_VERSION_DEFAULT
ENV TUNE_VERSION $TUNE_VERSION_DEFAULT
ENV PARALLEL_COPY_VERSION $PARALLEL_COPY_VERSION_DEFAULT
ENV TIMESCALE_VERSION $TIMESCALE_VERSION_DEFAULT
ENV POSTGIS_MAJOR $POSTGIS_MAJOR_DEFAULT

RUN mkdir -p /docker-entrypoint-initdb.d
COPY --from=timescale_builder /docker-entrypoint-initdb.d/ /docker-entrypoint-initdb.d/
COPY --chmod=755 ./scripts/install-postgis.sh /docker-entrypoint-initdb.d/010_init_postgis.sh
COPY --chmod=755 ./scripts/update-postgis.sh /usr/local/bin/update-postgis.sh

COPY --from=timescale_builder /usr/share/postgresql/$PG_MAJOR/extension/timescaledb* /usr/share/postgresql/$PG_MAJOR/extension/
COPY --from=timescale_builder /usr/lib/postgresql/$PG_MAJOR/lib/timescaledb* /usr/lib/postgresql/$PG_MAJOR/lib/
COPY --from=go_tools /go/bin/ /usr/local/bin/
RUN sed -r -i "s/[#]*\s*(shared_preload_libraries)\s*=\s*'(.*)'/\1 = 'timescaledb,\2'/;s/,'/'/" /usr/share/postgresql/$PG_MAJOR/postgresql.conf.sample
