FROM glibc-base:latest AS base

# 2.27
ARG GLIBC_VERSION=???
RUN wget https://mirror.ibcp.fr/pub/gnu/glibc/${GLIBC_VERSION}.tar.gz && tar -xzf ${GLIBC_VERSION}.tar.gz && cd ${GLIBC_VERSION} && mkdir -p build && cd build && ../configure --disable-werror --prefix=$(pwd)/out && make -j $(nproc)

FROM scratch
# 2.27
ARG GLIBC_VERSION=???
COPY --from=base /${GLIBC_VERSION}/build/libc.so.6 /libc.so.6
