ARG PG_VERSION=15
ARG BASE_OS=bookworm
ARG TS_TUNE_VERSION=v0.18.0
ARG TS_PARALLEL_COPY_VERSION=v0.7.1
ARG TS_VERSION=2.17.2
ARG TS_TOOLKIT_VERSION=1.13.1
ARG POSTGIS_MAJOR=3

FROM golang:${BASE_OS} AS go_tools
ARG TS_TUNE_VERSION
ARG TS_PARALLEL_COPY_VERSION

RUN go install github.com/timescale/timescaledb-tune/cmd/timescaledb-tune@${TS_TUNE_VERSION}
RUN go install github.com/timescale/timescaledb-parallel-copy/cmd/timescaledb-parallel-copy@${TS_PARALLEL_COPY_VERSION}

FROM postgres:${PG_VERSION}-${BASE_OS} AS timescale_builder
ARG TS_VERSION
ARG BASE_OS
ENV TIMESCALE_VERSION=$TS_VERSION
ENV DEBIAN_FRONTEND='noninteractive'
ENV BUILD_PACKAGES="curl ca-certificates gnupg apt-utils git gcc make cmake libssl-dev libkrb5-dev postgresql-server-dev-${PG_MAJOR} pkg-config clang"

RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates gnupg
RUN curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg >/dev/null
RUN echo "deb http://apt.postgresql.org/pub/repos/apt ${BASE_OS}-pgdg main" > /etc/apt/sources.list.d/pgdg.list
RUN apt-get update && apt-get install -y --no-install-recommends ${BUILD_PACKAGES}
RUN apt-mark auto ${BUILD_PACKAGES}

RUN git clone --branch $TS_VERSION --single-branch --depth 1 https://github.com/timescale/timescaledb
WORKDIR "/timescaledb"
RUN ./bootstrap \
    && cd build \
    && make -j $(nproc) \
    && make install
RUN cat "/timescaledb/build/install_manifest.txt"
WORKDIR "/"

RUN mkdir -p /docker-entrypoint-initdb.d
COPY --chmod=755 ./scripts/install-timescaledb.sh /docker-entrypoint-initdb.d/000_install_timescaledb.sh
# We can use the timescaledb_tune script from the official timescaledb docker
RUN curl https://raw.githubusercontent.com/timescale/timescaledb-docker/main/docker-entrypoint-initdb.d/001_timescaledb_tune.sh --output /docker-entrypoint-initdb.d/001_timescaledb_tune.sh \
    && chmod 0755 /docker-entrypoint-initdb.d/001_timescaledb_tune.sh
RUN git clone --depth 1 https://github.com/timescale/timescaledb-extras.git

#RUN rm -rf /timescaledb
#RUN apt-get purge -y ${BUILD_PACKAGES} \
#    && apt-get -y autoremove

FROM postgres:${PG_VERSION}-${BASE_OS} AS postgis_install
ARG POSTGIS_MAJOR
ENV POSTGIS_VERSION=$POSTGIS_MAJOR

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

RUN mkdir -p /docker-entrypoint-initdb.d
COPY --chmod=755 ./scripts/install-postgis.sh /docker-entrypoint-initdb.d/010_install_postgis.sh

FROM postgis_install AS final
ARG POSTGIS_MAJOR
ARG TS_TUNE_VERSION
ARG TS_PARALLEL_COPY_VERSION
ARG TS_VERSION
ENV TUNE_VERSION=$TS_TUNE_VERSION
ENV PARALLEL_COPY_VERSION=$TS_PARALLEL_COPY_VERSION
ENV TIMESCALE_VERSION=$TS_VERSION
ENV POSTGIS_VERSION=$POSTGIS_MAJOR
ENV INITCHECK_FOLDER="/.initcheck"

RUN mkdir -p /docker-entrypoint-initdb.d && mkdir -p /timescaledb-extras && mkdir -p /always-init.d && mkdir -p $INITCHECK_FOLDER && chmod a+w $INITCHECK_FOLDER
COPY --from=timescale_builder /docker-entrypoint-initdb.d/ /docker-entrypoint-initdb.d/
COPY --chmod=755 ./scripts/update-postgis.sh /always-init.d/012_update_postgis.sh
COPY --chmod=755 ./scripts/update-timescaledb.sh /always-init.d/011_update_timescaledb.sh
COPY --from=timescale_builder /timescaledb-extras/ /timescaledb-extras/
COPY --from=timescale_builder /usr/share/postgresql/$PG_MAJOR/extension/timescaledb* /usr/share/postgresql/$PG_MAJOR/extension/
COPY --from=timescale_builder /usr/lib/postgresql/$PG_MAJOR/lib/timescaledb* /usr/lib/postgresql/$PG_MAJOR/lib/
COPY --from=go_tools /go/bin/ /usr/local/bin/
RUN sed -r -i "s/[#]*\s*(shared_preload_libraries)\s*=\s*'(.*)'/\1 = 'timescaledb,\2'/;s/,'/'/" /usr/share/postgresql/$PG_MAJOR/postgresql.conf.sample

# since we want to run some scripts on every startup we need our own entrypoint
COPY --chmod=755 ./docker-entrypoint-extended.sh /usr/local/bin/docker-entrypoint-extended.sh

HEALTHCHECK --start-period=10s --interval=10s --timeout=3s --retries=5 \
  CMD pg_isready -U ${POSTGRES_USER} postgres

ENTRYPOINT ["docker-entrypoint-extended.sh"]
CMD ["postgres"]
