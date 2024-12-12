#!/bin/bash
# wget2 build script for Windows environment
# Author: rzhy1
# 2024/6/30

# 设置环境变量
export PREFIX="x86_64-w64-mingw32"
export INSTALLDIR="$HOME/usr/local/$PREFIX"
export PKG_CONFIG_PATH="$INSTALLDIR/lib/pkgconfig:/usr/$PREFIX/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="$INSTALLDIR/lib/pkgconfig"
export PKG_CONFIG="/usr/bin/${PREFIX}-pkg-config"
export CPPFLAGS="-I$INSTALLDIR/include"
export LDFLAGS="-L$INSTALLDIR/lib"
export CFLAGS="-O2 -g"
export WINEPATH="$INSTALLDIR/bin;$INSTALLDIR/lib;/usr/$PREFIX/bin;/usr/$PREFIX/lib"

mkdir -p $INSTALLDIR
cd $INSTALLDIR

build_xz() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build xz⭐⭐⭐⭐⭐⭐" 
  start_time=$(date +%s.%N)
  sudo apt-get purge xz-utils
  git clone -j$(nproc) https://github.com/tukaani-project/xz.git || { echo "Git clone failed"; exit 1; }
  cd xz || { echo "cd xz failed"; exit 1; }
  mkdir build
  cd build
  sudo cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Release -DXZ_NLS=ON -DBUILD_SHARED_LIBS=OFF || { echo "CMake failed"; exit 1; }
  sudo cmake --build . -- -j$(nproc) || { echo "Build failed"; exit 1; }
  sudo cmake --install . || { echo "Install failed"; exit 1; }
  xz --version
  cd ../.. && rm -rf xz
  end_time=$(date +%s.%N)
  duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
   echo "$duration" > "xz_duration.txt"
}

build_zstd() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build zstd⭐⭐⭐⭐⭐⭐" 
  start_time=$(date +%s.%N)
  # 创建 Python 虚拟环境并安装meson
  python3 -m venv /tmp/venv
  source /tmp/venv/bin/activate
  pip3 install meson pytest

  # 编译 zstd
  git clone -j$(nproc) https://github.com/facebook/zstd.git || exit 1
  cd zstd || exit 1
  LDFLAGS=-static \
  meson setup \
    --cross-file=${GITHUB_WORKSPACE}/cross_file.txt \
    --backend=ninja \
    --prefix=$INSTALLDIR \
    --libdir=$INSTALLDIR/lib \
    --bindir=$INSTALLDIR/bin \
    --pkg-config-path="$INSTALLDIR/lib/pkgconfig" \
    -Dbin_programs=true \
    -Dstatic_runtime=true \
    -Ddefault_library=static \
    -Db_lto=true --optimization=2 \
    build/meson builddir-st || exit 1
  sudo rm -f /usr/local/bin/zstd*
  sudo rm -f /usr/local/bin/*zstd
  meson compile -C builddir-st || exit 1
  meson install -C builddir-st || exit 1
  zstd --version
  cd .. && rm -rf zstd
  end_time=$(date +%s.%N)
  duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
   echo "$duration" > "zstd_duration.txt"
}

build_zlib-ng() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build zlib-ng⭐⭐⭐⭐⭐⭐" 
  start_time=$(date +%s.%N)
  git clone -j$(nproc) https://github.com/zlib-ng/zlib-ng || exit 1
  cd zlib-ng || exit 1
  CROSS_PREFIX="x86_64-w64-mingw32-" ARCH="x86_64" CFLAGS="-O2" CC=x86_64-w64-mingw32-gcc ./configure --prefix=$INSTALLDIR --static --64 --zlib-compat || exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  cd .. && rm -rf zlib-ng
  end_time=$(date +%s.%N)
  duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
   echo "$duration" > "zlib-ng_duration.txt"
}

build_gmp() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gmp⭐⭐⭐⭐⭐⭐" 
  start_time=$(date +%s.%N)
  wget -nv -O- https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz | tar x --xz
  cd gmp-* || exit
  ./configure --host=$PREFIX --disable-shared --prefix="$INSTALLDIR"
  make -j$(nproc) || exit 1
  make install || exit 1
  cd .. && rm -rf gmp-*
  end_time=$(date +%s.%N)
  duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
    echo "$duration" > "gmp_duration.txt"
}

build_gnulibmirror() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gnulib-mirror⭐⭐⭐⭐⭐⭐" 
   start_time=$(date +%s.%N)
  git clone --recursive -j$(nproc) https://gitlab.com/gnuwget/gnulib-mirror.git gnulib || exit 1
  export GNULIB_REFDIR=$INSTALLDIR/gnulib
   end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
   echo "$duration" > "gnulibmirror_duration.txt"
}

build_libiconv() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libiconv⭐⭐⭐⭐⭐⭐" 
   start_time=$(date +%s.%N)
  wget -O- https://ftp.gnu.org/gnu/libiconv/libiconv-1.17.tar.gz | tar xz || exit 1
  cd libiconv-* || exit 1
  ./configure --build=x86_64-pc-linux-gnu --host=$PREFIX --disable-shared --enable-static --prefix=$INSTALLDIR || exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  cd .. && rm -rf libiconv-*
    end_time=$(date +%s.%N)
   duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
   echo "$duration" > "libiconv_duration.txt"
}

build_libunistring() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libunistring⭐⭐⭐⭐⭐⭐" 
   start_time=$(date +%s.%N)
  wget -O- https://ftp.gnu.org/gnu/libunistring/libunistring-1.3.tar.gz | tar xz || exit 1
  cd libunistring-* || exit 1
  ./configure CFLAGS="-O3" --build=x86_64-pc-linux-gnu --host=$PREFIX --prefix=$INSTALLDIR --disable-shared --enable-static || exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  cd .. && rm -rf libunistring-*
   end_time=$(date +%s.%N)
   duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
   echo "$duration" > "libunistring_duration.txt"
}

build_libidn2() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libidn2⭐⭐⭐⭐⭐⭐" 
  start_time=$(date +%s.%N)
  wget -O- https://ftp.gnu.org/gnu/libidn/libidn2-2.3.7.tar.gz | tar xz || exit 1
  cd libidn2-* || exit 1
  ./configure --build=x86_64-pc-linux-gnu --host=$PREFIX  --disable-shared --enable-static --disable-doc --disable-gcc-warnings --prefix=$INSTALLDIR || exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  cd .. && rm -rf libidn2-*
   end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
   echo "$duration" > "libidn2_duration.txt"
}

build_libtasn1() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libtasn1⭐⭐⭐⭐⭐⭐"
  start_time=$(date +%s.%N)
  wget -O- https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.19.0.tar.gz | tar xz || exit 1
  cd libtasn1-* || exit 1
  ./configure --host=$PREFIX --disable-shared --disable-doc --prefix="$INSTALLDIR" || exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  cd .. && rm -rf libtasn1-*
  end_time=$(date +%s.%N)
  duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
  echo "$duration" > "libtasn1_duration.txt"
}

build_PCRE2() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build PCRE2⭐⭐⭐⭐⭐⭐" 
   start_time=$(date +%s.%N)
  git clone -j$(nproc) https://github.com/PCRE2Project/pcre2 || exit 1
  cd pcre2 || exit 1
  ./autogen.sh || exit 1
  ./configure --host=$PREFIX --prefix=$INSTALLDIR --disable-shared --enable-static || exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  cd .. && rm -rf pcre2
   end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
  echo "$duration" > "pcre2_duration.txt"
}

build_nghttp2() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build nghttp2⭐⭐⭐⭐⭐⭐" 
   start_time=$(date +%s.%N)
  wget -O- https://github.com/nghttp2/nghttp2/releases/download/v1.64.0/nghttp2-1.64.0.tar.gz | tar xz || exit 1
  cd nghttp2-* || exit 1
  ./configure --build=x86_64-pc-linux-gnu --host=$PREFIX --prefix=$INSTALLDIR --disable-shared --enable-static --disable-python-bindings --disable-examples --disable-app --disable-failmalloc --disable-hpack-tools || exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  cd .. && rm -rf nghttp2-*
   end_time=$(date +%s.%N)
  duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
  echo "$duration" > "nghttp2_duration.txt"
}

build_dlfcn-win32() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build dlfcn-win32⭐⭐⭐⭐⭐⭐" 
  start_time=$(date +%s.%N)
  git clone -j$(nproc) https://github.com/dlfcn-win32/dlfcn-win32.git || exit 1
  cd dlfcn-win32 || exit 1
  ./configure --prefix=$PREFIX --cc=$PREFIX-gcc || exit 1
  make -j$(nproc) || exit 1
  cp -p libdl.a $INSTALLDIR/lib/ || exit 1
  cp -p src/dlfcn.h $INSTALLDIR/include/ || exit 1
  cd .. && rm -rf dlfcn-win32
   end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
   echo "$duration" > "dlfcn-win32_duration.txt"
}

build_libmicrohttpd() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libmicrohttpd⭐⭐⭐⭐⭐⭐" 
  start_time=$(date +%s.%N)
  wget -O- https://ftp.gnu.org/gnu/libmicrohttpd/libmicrohttpd-latest.tar.gz | tar xz || exit 1
  cd libmicrohttpd-* || exit 1
  ./configure --build=x86_64-pc-linux-gnu --host=$PREFIX --prefix=$INSTALLDIR --disable-shared --enable-static \
            --disable-examples --disable-doc --disable-tools || exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  cd .. && rm -rf libmicrohttpd-*
   end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
  echo "$duration" > "libmicrohttpd_duration.txt"
}

build_libpsl() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libpsl⭐⭐⭐⭐⭐⭐" 
   start_time=$(date +%s.%N)
  git clone -j$(nproc) --recursive https://github.com/rockdaboot/libpsl.git || exit 1
  cd libpsl || exit 1
  ./autogen.sh || exit 1
  ./configure --build=x86_64-pc-linux-gnu --host=$PREFIX --disable-shared --enable-static --enable-runtime=libidn2 --enable-builtin --prefix=$INSTALLDIR || exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  cd .. && rm -rf libpsl
    end_time=$(date +%s.%N)
   duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
  echo "$duration" > "libpsl_duration.txt"
}

build_nettle() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build nettle⭐⭐⭐⭐⭐⭐" 
  start_time=$(date +%s.%N)
  git clone -j$(nproc) https://github.com/sailfishos-mirror/nettle.git || exit 1
  cd nettle || exit 1
  bash .bootstrap || exit 1
  ./configure --build=x86_64-pc-linux-gnu --host=$PREFIX --enable-mini-gmp --disable-shared --enable-static --disable-documentation --prefix=$INSTALLDIR || exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  cd .. && rm -rf nettle
  end_time=$(date +%s.%N)
 duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
  echo "$duration" > "nettle_duration.txt"
}

build_gnutls() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gnutls⭐⭐⭐⭐⭐⭐" 
  start_time=$(date +%s.%N)
  wget -O- https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.8.tar.xz | tar x --xz || exit 1
  cd gnutls-* || exit 1
  GMP_LIBS="-L$INSTALLDIR/lib -lgmp" \
  NETTLE_LIBS="-L$INSTALLDIR/lib -lnettle -lgmp" \
  HOGWEED_LIBS="-L$INSTALLDIR/lib -lhogweed -lnettle -lgmp" \
  LIBTASN1_LIBS="-L$INSTALLDIR/lib -ltasn1" \
  LIBIDN2_LIBS="-L$INSTALLDIR/lib -lidn2" \
  GMP_CFLAGS=$CFLAGS \
  LIBTASN1_CFLAGS=$CFLAGS \
  NETTLE_CFLAGS=$CFLAGS \
  HOGWEED_CFLAGS=$CFLAGS \
  LIBIDN2_CFLAGS=$CFLAGS \
  ./configure CFLAGS="-O3" --host=$PREFIX --prefix=$INSTALLDIR --with-included-libtasn1 --with-included-unistring --disable-openssl-compatibility --disable-hardware-acceleration --disable-shared --enable-static --without-p11-kit --disable-doc --disable-tests --disable-full-test-suite --disable-tools --disable-cxx --disable-maintainer-mode --disable-libdane || exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  cd .. && rm -rf gnutls-* 
  end_time=$(date +%s.%N)
  duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
  echo "$duration" > "gnutls_duration.txt"
}

build_wget2() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build wget2⭐⭐⭐⭐⭐⭐" 
  start_time=$(date +%s.%N)
  git clone -j$(nproc) https://github.com/rockdaboot/wget2.git || exit 1
  cd wget2 || exit 1
  ./bootstrap --skip-po || exit 1
  export LDFLAGS="-Wl,-Bstatic,--whole-archive -lwinpthread -Wl,--no-whole-archive"
  export CFLAGS="-O3 -DNGHTTP2_STATICLIB"
  GNUTLS_CFLAGS=$CFLAGS \
  GNUTLS_LIBS="-L$INSTALLDIR/lib -lgnutls -lbcrypt -lncrypt" \
  LIBPSL_CFLAGS=$CFLAGS \
  LIBPSL_LIBS="-L$INSTALLDIR/lib -lpsl" \
  PCRE2_CFLAGS=$CFLAGS \
  PCRE2_LIBS="-L$INSTALLDI/lib -lpcre2-8"  \
  ./configure --build=x86_64-pc-linux-gnu --host=$PREFIX --with-libiconv-prefix="$INSTALLDIR" --with-ssl=gnutls --disable-shared --enable-static --with-lzma  --with-zstd --without-bzip2 --without-lzip --without-brotlidec --without-gpgme --enable-threads=windows || exit 1
  make -j$(nproc) || exit 1
  strip $INSTALLDIR/wget2/src/wget2.exe || exit 1
  cp -fv "$INSTALLDIR/wget2/src/wget2.exe" "${GITHUB_WORKSPACE}" || exit 1
  end_time=$(date +%s.%N)
  duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
  echo "$duration" > "wget2_duration.txt"
}

#build_xz
build_zstd &
build_zlib-ng &
build_gmp &
#build_gnulibmirror &
build_libiconv &
build_libunistring &
build_libidn2 &
#build_libtasn1 &
build_PCRE2 &
build_nghttp2 &
#build_dlfcn-win32
build_libmicrohttpd &
wait
build_libpsl
build_nettle
build_gnutls
build_wget2

duration1=$(cat xz_duration.txt)
duration2=$(cat zstd_duration.txt)
duration3=$(cat zlib-ng_duration.txt)
duration4=$(cat gmp_duration.txt)
duration5=$(cat gnulibmirror_duration.txt)
duration6=$(cat libiconv_duration.txt)
duration7=$(cat libunistring_duration.txt)
duration8=$(cat libidn2_duration.txt)
duration9=$(cat libtasn1_duration.txt)
duration10=$(cat pcre2_duration.txt)
duration11=$(cat nghttp2_duration.txt)
duration12=$(cat dlfcn-win32_duration.txt)
duration13=$(cat libmicrohttpd_duration.txt)
duration14=$(cat libpsl_duration.txt)
duration15=$(cat nettle_duration.txt)
duration16=$(cat gnutls_duration.txt)
duration17=$(cat wget2_duration.txt)

echo "编译 xz 用时：${duration1}s"
echo "编译 zstd 用时：${duration2}s"
echo "编译 zlib-ng 用时：${duration3}s"
echo "编译 gmp 用时：${duration4}s"
echo "编译 gnulibmirror 用时：${duration5}s"
echo "编译 libiconv 用时：${duration6}s"
echo "编译 libunistring 用时：${duration7}s"
echo "编译 libidn2 用时：${duration8}s"
echo "编译 libtasn1 用时：${duration9}s"
echo "编译 PCRE2 用时：${duration10}s"
echo "编译 nghttp2 用时：${duration11}s"
echo "编译 dlfcn-win32 用时：${duration12}s"
echo "编译 libmicrohttpd 用时：${duration13}s"
echo "编译 libpsl 用时：${duration14}s"
echo "编译 nettle 用时：${duration15}s"
echo "编译 gnutls 用时：${duration16}s"
echo "编译 wget2 用时：${duration17}s"
