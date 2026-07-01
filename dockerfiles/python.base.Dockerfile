FROM ubuntu:22.04

RUN apt-get update && apt-get -y install build-essential \
                                         libz-dev \
                                         libreadline-dev \
                                         libncursesw5-dev \
                                         libssl-dev \
                                         libgdbm-dev \
                                         libsqlite3-dev \
                                         libbz2-dev \
                                         liblzma-dev \
                                         curl \
                                         git

RUN git clone https://github.com/python/cpython.git
