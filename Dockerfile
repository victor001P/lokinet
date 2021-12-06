FROM ubuntu:bionic

RUN apt update && apt install -y build-essential curl git cmake libssl-dev libsodium-dev wget pkg-config autoconf libtool g++-8 libsqlite3-dev libcap-dev
WORKDIR /usr/src/app

## Boost
ARG BOOST_VERSION=1_70_0
ARG BOOST_VERSION_DOT=1.70.0
ARG BOOST_HASH=430ae8354789de4fd19ee52f3b1f739e1fba576f0aded0897c3c2bc00fb38778
RUN set -ex \
    && curl -s -L -O https://boostorg.jfrog.io/artifactory/main/release/${BOOST_VERSION}/source/boost_${BOOST_VERSION_DOT}.tar.bz2 \
    && tar -xvf boost_${BOOST_VERSION}.tar.bz2 \
    && cd boost_${BOOST_VERSION} \
    && ./bootstrap.sh \
    && ./b2 --build-type=minimal link=static runtime-link=static --with-chrono --with-date_time --with-filesystem --with-program_options --with-regex --with-serialization --with-system --with-thread --with-locale threading=multi threadapi=pthread cflags="-fPIC" cxxstd=14 cxxflags="-fPIC" stage
ENV BOOST_ROOT /usr/local/boost_${BOOST_VERSION}

# OpenSSL
ARG OPENSSL_VERSION=1.1.1c
ARG OPENSSL_HASH=f6fb3079ad15076154eda9413fed42877d668e7069d9b87396d0804fdb3f4c90
RUN set -ex \
    && curl -s -O https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz \
    && echo "${OPENSSL_HASH}  openssl-${OPENSSL_VERSION}.tar.gz" | sha256sum -c \
    && tar -xzf openssl-${OPENSSL_VERSION}.tar.gz \
    && cd openssl-${OPENSSL_VERSION} \
    && ./Configure linux-x86_64 no-shared --static -fPIC \
    && make build_generated \
    && make libcrypto.a \
    && make install
ENV OPENSSL_ROOT_DIR=/usr/local/openssl-${OPENSSL_VERSION}

# Sodium
ARG SODIUM_VERSION=1.0.18-RELEASE
ARG SODIUM_HASH=940ef42797baa0278df6b7fd9e67c7590f87744b
RUN set -ex \
    && git clone https://github.com/jedisct1/libsodium.git -b ${SODIUM_VERSION} --depth=1 \
    && cd libsodium \
    && test `git rev-parse HEAD` = ${SODIUM_HASH} || exit 1 \
    && ./autogen.sh \
    && ./configure --enable-static --disable-shared \
    && make -j$(nproc) \
    && make check \
    && make install

RUN apt-get install -y apt-transport-https ca-certificates gnupg software-properties-common wget
RUN wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | apt-key add -
RUN apt-add-repository 'deb https://apt.kitware.com/ubuntu/ xenial main'

RUN apt-get update

RUN apt-get install -y kitware-archive-keyring
RUN apt-key --keyring /etc/apt/trusted.gpg del C1F34CDD40CD72DA

RUN apt-get install -y cmake

ENV BOOST_ROOT /usr/src/app/boost_${BOOST_VERSION}
ENV CC=gcc-8 CXX=g++-8

COPY . .

RUN set -ex && \
    git submodule update --init --recursive && \
    rm -rf build && mkdir build && cd build && \
    cmake .. -DBUILD_STATIC_DEPS=ON -DBUILD_SHARED_LIBS=OFF -DSTATIC_LINK=ON && \
    make -j$(nproc)

