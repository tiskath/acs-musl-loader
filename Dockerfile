
FROM --platform=linux/arm64 alpine:3.21

RUN apk add --no-cache \
    build-base \
    linux-headers \
    git

WORKDIR /build

RUN git clone --depth 1 --branch v1.2.5 \
    https://github.com/ifduyue/musl.git .

# เปลี่ยน DNS และ hosts path ให้ตรงกับ ACS
RUN sed -i \
    's|/data/data/com.termux/files/usr/etc/resolv.conf|/data/data/com.tom.rv2ide/files/usr/etc/resolv.conf|g' \
    src/internal/dynlink.c \
    && sed -i \
    's|/data/data/com.termux/files/usr/etc/hosts|/data/data/com.tom.rv2ide/files/usr/etc/hosts|g' \
    src/internal/dynlink.c

# Build ARM64 musl loader
RUN ./configure --prefix=/out --disable-shared \
    && make -j2 \
    && make install \
    && mkdir -p /result \
    && cp /out/lib/ld-musl-aarch64.so.1 \
       /result/ld-musl-aarch64-termux.so \
    && chmod 755 /result/ld-musl-aarch64-termux.so

FROM scratch
COPY --from=0 /result/ld-musl-aarch64-termux.so /
