
FROM --platform=linux/arm64 alpine:3.21

RUN apk add --no-cache \
    build-base \
    linux-headers \
    git \
    python3

WORKDIR /build

# Download musl v1.2.5
RUN git clone --depth 1 --branch v1.2.5 \
    https://github.com/ifduyue/musl.git .

# Patch the actual musl source files
RUN python3 - <<'PY'
from pathlib import Path

patches = {
    "src/network/resolvconf.c": (
        '"/etc/resolv.conf"',
        '"/data/data/com.tom.rv2ide/files/usr/etc/resolv.conf"'
    ),
    "src/network/lookup_name.c": (
        '"/etc/hosts"',
        '"/data/data/com.tom.rv2ide/files/usr/etc/hosts"'
    )
}

for filename, (old, new) in patches.items():
    path = Path(filename)
    source = path.read_text()

    if old not in source:
        raise SystemExit(
            "ERROR: Original path not found in " + filename
        )

    source = source.replace(old, new)

    if new not in source:
        raise SystemExit(
            "ERROR: Patch verification failed: " + filename
        )

    path.write_text(source)
    print("PATCH OK:", filename)

print("ALL ACS PATHS PATCHED")
PY

# Verify patched source
RUN grep -n 'com.tom.rv2ide' \
    src/network/resolvconf.c \
    src/network/lookup_name.c

# Build musl for ARM64
RUN ./configure \
    --prefix=/out \
    --disable-shared \
    && make -j2 \
    && make install

# Prepare loader
RUN mkdir -p /result \
    && cp /out/lib/ld-musl-aarch64.so.1 \
       /result/ld-musl-aarch64-termux.so \
    && chmod 755 /result/ld-musl-aarch64-termux.so

# Export artifact
FROM scratch
COPY --from=0 /result/ld-musl-aarch64-termux.so /
