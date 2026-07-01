FROM ubuntu:24.04

RUN apt-get update && apt-get -y install build-essential \
                                         python3-dev \
                                         python3 \
                                         curl \
                                         wget \
                                         bison \
                                         gawk \
                                         git
