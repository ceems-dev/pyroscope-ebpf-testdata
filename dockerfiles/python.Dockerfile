FROM python-base:latest AS base

# 3.13.0a3
ARG PYTHON_VERSION_PATCH=???
# 3.13
ARG PYTHON_VERSION_MINOR=???
RUN cd cpython && git fetch && git checkout v${PYTHON_VERSION_PATCH} && ./configure --enable-shared && make -j 32

FROM scratch
# 3.13.0a3
ARG PYTHON_VERSION_PATCH=???
# 3.13
ARG PYTHON_VERSION_MINOR=???
COPY --from=base /cpython/libpython${PYTHON_VERSION_MINOR}.so.1.0 /libpython${PYTHON_VERSION_MINOR}.so.1.0
