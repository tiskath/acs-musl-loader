
FROM --platform=linux/arm64 alpine:3.21

# ==========================================
# 1. Install build dependencies
# ==========================================
RUN apk add --no-cache \
    build-base \
    linux-headers \
    git \
    python3 \
    file \
    coreutils

WORKDIR /build

# ==========================================
# 2. Download musl source
# ==========================================
RUN git clone --depth 1 --branch v1.2.5 \
    https://github.com/ifduyue/musl.git .

# ==========================================
# 3. Patch DNS and hosts paths for ACS
# ==========================================
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

    if not path.exists():
        raise SystemExit("SOURCE NOT FOUND: " + filename)

    source = path.read_text()

    if old not in source:
        raise SystemExit("ORIGINAL PATH NOT FOUND: " + filename)

    source = source.replace(old, new)
    path.write_text(source)

    if new not in path.read_text():
        raise SystemExit("PATCH VERIFICATION FAILED: " + filename)

    print("PATCH OK:", filename)

print("ALL ACS PATHS PATCHED")
PY

# ==========================================
# 4. Verify patched source
# ==========================================
RUN grep -n 'com.tom.rv2ide' \
    src/network/resolvconf.c \
    src/network/lookup_name.c

# ==========================================
# 5. Configure musl
# ==========================================
RUN set -eux; \
    echo "===== CONFIGURE ====="; \
    ./configure \
        --prefix=/out \
        --syslibdir=/out/lib \
        --target=aarch64-linux-musl \
        --enable-shared \
        2>&1 | tee /tmp/configure.log; \
    echo "===== CONFIGURE COMPLETE ====="

# ==========================================
# 6. Compile musl
# ==========================================
RUN set -eux; \
    echo "===== MAKE ====="; \
    make -j2 2>&1 | tee /tmp/make.log; \
    echo "===== MAKE COMPLETE ====="

# ==========================================
# 7. Install musl
# ==========================================
RUN set -eux; \
    echo "===== MAKE INSTALL ====="; \
    make install 2>&1 | tee /tmp/install.log; \
    echo "===== INSTALL COMPLETE ====="

# ==========================================
# 8. Inspect installed files
# ==========================================
RUN set -eux; \
    echo "===== SEARCH INSTALLED LIBRARIES ====="; \
    find /out -name 'libc.so*' -o -name 'ld-musl*'; \
    echo "===== LIBRARY DIRECTORY ====="; \
    ls -la /out/lib || true

# ==========================================
# 9. Prepare loader artifact
# ==========================================
RUN set -eux; \
    echo "===== PREPARE LOADER ====="; \
    test -f /out/lib/libc.so; \
    mkdir -p /result; \
    cp -L /out/lib/libc.so \
       /result/ld-musl-aarch64-termux.so; \
    chmod 755 /result/ld-musl-aarch64-termux.so; \
    file /result/ld-musl-aarch64-termux.so

# ==========================================
# 10. Verify ACS DNS paths
# ==========================================
RUN set -eux; \
    echo "===== VERIFY ACS PATHS ====="; \
    grep -aFq \
      '/data/data/com.tom.rv2ide/files/usr/etc/resolv.conf' \
      /result/ld-musl-aarch64-termux.so; \
    grep -aFq \
      '/data/data/com.tom.rv2ide/files/usr/etc/hosts' \
      /result/ld-musl-aarch64-termux.so; \
    echo "ACS PATH VERIFICATION PASSED"

# ==========================================
# 11. Export artifact
# ==========================================
FROM scratch

COPY --from=0 \
    /result/ld-musl-aarch64-termux.so \
    /
    
