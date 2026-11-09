
FROM --platform=linux/arm64 alpine:3.21

# Install build tools
RUN apk add --no-cache \
    build-base \
    linux-headers \
    git \
    python3 \
    file

WORKDIR /build

# Download musl 1.2.5
RUN git clone --depth 1 --branch v1.2.5 \
    https://github.com/ifduyue/musl.git .

# Patch DNS and hosts paths for ACS
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
        raise SystemExit("ERROR: Original path missing: " + filename)

    source = source.replace(old, new)
    path.write_text(source)

    if new not in path.read_text():
        raise SystemExit("ERROR: Patch failed: " + filename)

    print("PATCH OK:", filename)

print("ALL ACS PATHS PATCHED")
PY

# Verify source paths
RUN grep -n 'com.tom.rv2ide' \
    src/network/resolvconf.c \
    src/network/lookup_name.c

# Build musl with shared library enabled
RUN ./configure \
    --prefix=/out \
    --syslibdir=/out/lib \
    --target=aarch64-linux-musl \
    --enable-shared \
    && make -j2 \
    && make install

# Verify libc.so and create loader file
RUN set -eux; \
    echo "===== INSTALLED LIBRARIES ====="; \
    find /out/lib -maxdepth 1 -type f -o -type l; \
    test -f /out/lib/libc.so; \
    file /out/lib/libc.so; \
    mkdir -p /result; \
    cp -L /out/lib/libc.so \
       /result/ld-musl-aarch64-termux.so; \
    chmod 755 /result/ld-musl-aarch64-termux.so; \
    echo "===== VERIFY ACS DNS PATHS ====="; \
    grep -aFq '/data/data/com.tom.rv2ide/files/usr/etc/resolv.conf' \
       /result/ld-musl-aarch64-termux.so; \
    grep -aFq '/data/data/com.tom.rv2ide/files/usr/etc/hosts' \
       /result/ld-musl-aarch64-termux.so; \
    file /result/ld-musl-aarch64-termux.so; \
    echo "ACS LOADER BUILD VERIFIED"

# Export artifact
FROM scratch
COPY --from=0 /result/ld-musl-aarch64-termux.so /
