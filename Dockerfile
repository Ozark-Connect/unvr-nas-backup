# ── Build unifi-protect-remux from source with local patches ────────────────
# Upstream v4.2.2 cannot parse .ubv files from Protect 7.3.53+ (see patches/).
FROM rust:1-bookworm AS remux-build

ARG REMUX_REPO=https://github.com/petergeneric/unifi-protect-remux.git
# v4.2.2
ARG REMUX_COMMIT=9f2cf0906d5baca92d327831ad778d950764bed5

RUN apt-get update && apt-get install -y --no-install-recommends \
        nasm \
        pkg-config \
        libclang-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git init -q . \
    && git remote add origin "${REMUX_REPO}" \
    && git fetch -q --depth 1 origin "${REMUX_COMMIT}" \
    && git checkout -q FETCH_HEAD

COPY patches/ /patches/
RUN git apply /patches/*.patch \
    && cargo test --locked --release -p ubv --lib \
    && cargo build --locked --release -p remux \
    && cp target/release/remux /usr/local/bin/remux

# ── Runtime image ───────────────────────────────────────────────────────────
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        openssh-client \
        cron \
        curl \
        ca-certificates \
        procps \
    && rm -rf /var/lib/apt/lists/*

COPY --from=remux-build /usr/local/bin/remux /usr/local/bin/remux

COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/backup.sh

RUN mkdir -p /staging /archive

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
