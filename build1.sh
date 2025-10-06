#!/bin/bash
# ===========================================================
#  wget2 Windows 全静态构建脚本（GNUTLS版）
#  作者: rzhy1
#  优化整合版: ChatGPT GPT-5 (2025-10)
# ===========================================================

set -e
STAGE="all"
STRIP_DEPS=false

# 解析参数
for arg in "$@"; do
  case "$arg" in
    deps) STAGE="deps" ;;
    wget2) STAGE="wget2" ;;
    --strip-deps) STRIP_DEPS=true ;;
  esac
done

PREFIX="x86_64-w64-mingw32"
ROOT_DIR="$PWD"
BUILDROOT="$ROOT_DIR/build"
INSTALLDIR="$ROOT_DIR/deps"
PKG_CONFIG_PATH="$INSTALLDIR/lib/pkgconfig"
PKG_CONFIG_LIBDIR="$INSTALLDIR/lib/pkgconfig"

export PKG_CONFIG_PATH PKG_CONFIG_LIBDIR
export CPPFLAGS="-I$INSTALLDIR/include"
export LDFLAGS="-L$INSTALLDIR/lib -static -s -flto=$(nproc)"
export CFLAGS="-march=tigerlake -mtune=tigerlake -Os -pipe -fvisibility=hidden -flto=$(nproc)"
export CXXFLAGS="$CFLAGS"
export PREFIX

STRIP_TOOL="${PREFIX}-strip"

# -----------------------------------------------------------
# 实用函数
# -----------------------------------------------------------
fetch_extract() {
  url="$1"; shift
  name=$(basename "$url")
  wget -q "$url" -O "$name"
  case "$name" in
    *.tar.xz) tar xf "$name" --xz ;;
    *.tar.gz) tar xzf "$name" ;;
    *.tar.bz2) tar xjf "$name" ;;
  esac
}

build_one() {
  echo "⭐ $(date '+%F %T') - build $1"
  "$1"
  echo "✅ $1 done"
}

strip_static_libs() {
  echo "🧹 正在精简依赖库符号信息..."
  find "$INSTALLDIR/lib" -type f -name "*.a" | while read -r f; do
    echo "  → strip $(basename "$f")"
    "$STRIP_TOOL" --strip-debug "$f" 2>/dev/null || true
  done
  echo "✅ 所有静态库已精简"
}

# -----------------------------------------------------------
# 阶段1：依赖构建
# -----------------------------------------------------------
build_deps() {
  mkdir -p "$BUILDROOT" "$INSTALLDIR"
  cd "$BUILDROOT"

  build_zlib_ng() {
    fetch_extract https://github.com/zlib-ng/zlib-ng/archive/refs/tags/2.2.2.tar.gz
    cd zlib-ng-* && ./configure --prefix="$INSTALLDIR" --static --zlib-compat
    make -j$(nproc) && make install && cd ..
  }

  build_zstd() {
    git clone --depth=1 https://github.com/facebook/zstd.git
    cd zstd
    make -j$(nproc) ZSTD_LEGACY_SUPPORT=0 HAVE_THREAD=0 \
         BUILD_SHARED=0 BUILD_STATIC=1 lib-release
    make install PREFIX="$INSTALLDIR"
    cd ..
  }

  build_brotli() {
    git clone --depth=1 https://github.com/google/brotli.git
    cd brotli && mkdir build && cd build
    cmake .. -DCMAKE_SYSTEM_NAME=Windows \
      -DCMAKE_C_COMPILER=${PREFIX}-gcc \
      -DCMAKE_CXX_COMPILER=${PREFIX}-g++ \
      -DCMAKE_INSTALL_PREFIX="$INSTALLDIR" \
      -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release
    make -j$(nproc) install && cd ../..
  }

  build_gmp() {
    fetch_extract https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz
    cd gmp-* && ./configure --host=$PREFIX --disable-shared --prefix="$INSTALLDIR"
    make -j$(nproc) && make install && cd ..
  }

  build_libtasn1() {
    fetch_extract https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.20.0.tar.gz
    cd libtasn1-* && ./configure --host=$PREFIX --disable-shared --prefix="$INSTALLDIR"
    make -j$(nproc) && make install && cd ..
  }

  build_libiconv() {
    fetch_extract https://ftp.gnu.org/gnu/libiconv/libiconv-1.18.tar.gz
    cd libiconv-* && ./configure --host=$PREFIX --disable-shared --enable-static --prefix="$INSTALLDIR"
    make -j$(nproc) && make install && cd ..
  }

  build_libunistring() {
    fetch_extract https://ftp.gnu.org/gnu/libunistring/libunistring-1.4.tar.gz
    cd libunistring-* && ./configure --host=$PREFIX --disable-shared --prefix="$INSTALLDIR"
    make -j$(nproc) && make install && cd ..
  }

  build_libidn2() {
    fetch_extract https://ftp.gnu.org/gnu/libidn/libidn2-2.3.8.tar.gz
    cd libidn2-* && ./configure --host=$PREFIX --disable-shared --prefix="$INSTALLDIR"
    make -j$(nproc) && make install && cd ..
  }

  build_pcre2() {
    fetch_extract https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.46/pcre2-10.46.tar.gz
    cd pcre2-* && ./configure --host=$PREFIX --disable-shared --prefix="$INSTALLDIR"
    make -j$(nproc) && make install && cd ..
  }

  build_nghttp2() {
    fetch_extract https://github.com/nghttp2/nghttp2/releases/download/v1.67.1/nghttp2-1.67.1.tar.gz
    cd nghttp2-* && ./configure --host=$PREFIX --disable-shared --enable-static --prefix="$INSTALLDIR"
    make -j$(nproc) && make install && cd ..
  }

  build_nettle() {
    fetch_extract https://ftp.gnu.org/gnu/nettle/nettle-3.10.2.tar.gz
    cd nettle-* && ./configure --host=$PREFIX --disable-shared --prefix="$INSTALLDIR"
    make -j$(nproc) && make install && cd ..
  }

  build_gnutls() {
    fetch_extract https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.10.tar.xz
    cd gnutls-* && ./configure --host=$PREFIX --disable-shared --enable-static \
      --prefix="$INSTALLDIR" --disable-doc --disable-tools --disable-tests \
      --without-p11-kit --disable-cxx
    make -j$(nproc) && make install && cd ..
  }

  # === 执行依赖构建 ===
  build_one build_zlib_ng
  build_one build_zstd
  build_one build_brotli
  build_one build_gmp
  build_one build_libiconv
  build_one build_libunistring
  build_one build_libidn2
  build_one build_libtasn1
  build_one build_pcre2
  build_one build_nghttp2
  build_one build_nettle
  build_one build_gnutls

  # === 精简阶段 ===
  if $STRIP_DEPS; then
    strip_static_libs
  fi

  # === 清理构建缓存 ===
  echo "🧹 清理临时目录..."
  cd "$ROOT_DIR"
  rm -rf "$BUILDROOT"
  echo "✅ 所有依赖已编译并安装到：$INSTALLDIR"
}

# -----------------------------------------------------------
# 阶段2：wget2 构建
# -----------------------------------------------------------
build_wget2() {
  cd "$ROOT_DIR"
  echo "⭐ $(date '+%F %T') - build wget2"
  git clone --depth=1 https://github.com/rockdaboot/wget2.git
  cd wget2
  git clone --depth=1 https://github.com/coreutils/gnulib.git
  ./bootstrap --skip-po --gnulib-srcdir=gnulib

  ./configure --host=$PREFIX --prefix="$INSTALLDIR" \
    --disable-shared --enable-static \
    --with-libiconv-prefix="$INSTALLDIR" \
    --with-ssl=gnutls \
    --without-bzip2 --without-lzip --without-gpgme \
    --enable-threads=windows

  make -j$(nproc)
  cp src/wget2.exe "$ROOT_DIR/wget2-static-x64.exe"
  ${STRIP_TOOL} --strip-all "$ROOT_DIR/wget2-static-x64.exe" || true

  echo "✅ wget2 构建完成: $ROOT_DIR/wget2-static-x64.exe"
}

# -----------------------------------------------------------
# 执行逻辑
# -----------------------------------------------------------
if [[ "$STAGE" == "deps" ]]; then
  build_deps
elif [[ "$STAGE" == "wget2" ]]; then
  build_wget2
else
  build_deps
  build_wget2
fi
