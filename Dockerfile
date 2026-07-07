# Reproduces the OnigUChar redefinition error on ruby master.
#
# Pinned by digest to the exact rubylang/ruby:master image that the failed
# Rails nightly build 4522 used:
#   ruby 4.1.0dev (2026-07-06T16:40:46Z master 53443163ec) on Ubuntu 24.04
#
# `docker build .` is the reproduction: the final RUN fails while compiling
# a C file that includes <ruby.h> and then an ICU header.
FROM rubylang/ruby:master@sha256:7174ce49398bcf026e28b3946430cb253dbe1c9cc7d576065ba43067f813548a

RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc make libicu-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /repro
COPY repro.c extconf.rb ./

RUN ruby extconf.rb && make
