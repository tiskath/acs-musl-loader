
FROM --platform=linux/arm64 alpine:3.21

RUN apk add --no-cache \
    build-base \
    linux-headers \
    git \
    python3

WORKDIR /build

# Download musl source
RUN git clone --depth 1 --branch v1.2.5 \
    https://github.com/ifduyue/musl.git .

# Inspect and patch DNS paths for ACS
RUN python3 - <<'PY'
import re

p = "src/internal/dynlink.c"

with open(p, "r") as f:
    s = f.read()

print("===== DNS SOURCE BEFORE PATCH =====")

for i, line in enumerate(s.splitlines(), 1):
    if any(x in line for x in ("resolv.conf", "/etc/hosts", "RESOLV_CONF", "HOSTS_PATH")):
        print(f"{i}: {line}")

# Replace standard musl paths
s = s.replace(
    '"/etc/resolv.conf"',
    '"/data/data/com.tom.rv2ide/files/usr/etc/resolv.conf"'
)

s = s.replace(
    '"/etc/hosts"',
    '"/data/data/com.tom.rv2ide/files/usr/etc/hosts"'
)

with open(p, "w") as f:
    f.write(s)

print("===== DNS SOURCE AFTER PATCH =====")

for i, line in enumerate(s.splitlines(), 1):
    if any(x in line for x in ("resolv.conf", "/etc/hosts", "RESOLV_CONF", "HOSTS_PATH")):
        print(f"{i}: {line}")

if "/data/data/com.tom.rv2ide/files/usr/etc/resolv.conf" not in s:
    raise SystemExit("ERROR: ACS resolv.conf path was not patched")

if "/data/data/com.tom.rv2ide/files/usr/etc/hosts" not in s:
    raise SystemExit("ERROR: ACS hosts path was not patched")

print("ACS DNS PATCH VERIFIED")
PY

# Build musl
RUN ./configure \
    --prefix=/out \
    --target=aarch64-linux-musl \
    --disable-shared \
    && make -j2 \
    && make install

# Prepare output
RUN mkdir -p /result \
    && cp /out/lib/ld-musl-aarch64.so.1 \
       /result/ld-musl-aarch64-termux.so \
    && chmod 755 /result/ld-musl-aarch64-termux.so

# Final artifact image
FROM scratch
COPY --from=0 /result/ld-musl-aarch64-termux.so /
