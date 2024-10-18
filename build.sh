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
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build xz结束⭐⭐⭐⭐⭐⭐" 
}

build_zstd() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build zstd⭐⭐⭐⭐⭐⭐" 
  # 创建 Python 虚拟环境并安装meson
  #python3 -m venv /tmp/venv
  #source /tmp/venv/bin/activate
  #pip3 install meson pytest

  # 创建交叉编译文件
  #cat <<EOF > cross_file.txt
  #[binaries]
  #c = 'x86_64-w64-mingw32-gcc'
  #cpp = 'x86_64-w64-mingw32-g++'
  #ar = 'x86_64-w64-mingw32-ar'
  #strip = 'x86_64-w64-mingw32-strip'
  #exe_wrapper = 'wine64'
  #[host_machine]
  #system = 'windows'
  #cpu_family = 'x86_64'
  #cpu = 'x86_64'
  #endian = 'little'
#EOF

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
    #  -Dzlib=disabled -Dlzma=disabled -Dlz4=disabled \
  sudo rm -f /usr/local/bin/zstd*
  sudo rm -f /usr/local/bin/*zstd
  meson compile -C builddir-st || exit 1
  meson install -C builddir-st || exit 1
  zstd --version
  cd .. && rm -rf zstd
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build zstd结束⭐⭐⭐⭐⭐⭐" 
}

build_zlib-ng() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build zlib-ng⭐⭐⭐⭐⭐⭐" 
  git clone -j$(nproc) https://github.com/zlib-ng/zlib-ng || exit 1
  cd zlib-ng || exit 1
  CROSS_PREFIX="x86_64-w64-mingw32-" ARCH="x86_64" CFLAGS="-O2" CC=x86_64-w64-mingw32-gcc ./configure --prefix=$INSTALLDIR --static --64 --zlib-compat || exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  cd .. && rm -rf zlib-ng
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build zlib-ng结束⭐⭐⭐⭐⭐⭐" 
}

build_gmp() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gmp⭐⭐⭐⭐⭐⭐" 
  wget -nv -O- https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz | tar x --xz
  cd gmp-* || exit
  ./configure --host=$PREFIX --disable-shared --prefix="$INSTALLDIR"
  make -j$(nproc) || exit 1
  make install || exit 1
  cd .. && rm -rf gmp-*
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gmp结束⭐⭐⭐⭐⭐⭐" 
}

build_gnulibmirror() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gnulib-mirror⭐⭐⭐⭐⭐⭐" 
  git clone --recursive -j$(nproc) https://gitlab.com/gnuwget/gnulib-mirror.git gnulib || exit 1
  export GNULIB_REFDIR=$INSTALLDIR/gnulib
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gnulib-mirror结束⭐⭐⭐⭐⭐⭐" 
}

build_libiconv() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libiconv⭐⭐⭐⭐⭐⭐" 
  wget -O- https://ftp.gnu.org/gnu/libiconv/libiconv-1.17.tar.gz | tar xz || exit 1
  cd libiconv-* || exit 1
  ./configure --build=x86_64-pc-linux-gnu --host=$PREFIX --disable-shared --enable-static --prefix=$INSTALLDIR || exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  cd .. && rm -rf libiconv-*
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libiconv结束⭐⭐⭐⭐⭐⭐" 
}

build_libunistring() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libunistring⭐⭐⭐⭐⭐⭐" 
  wget -O- https://ftp.gnu.org/gnu/libunistring/libunistring-1.3.tar.gz | tar xz || exit 1
  cd libunistring-* || exit 1
  ./configure CFLAGS="-O3" --build=x86_64-pc-linux-gnu --host=$PREFIX --prefix=$INSTALLDIR --disable-shared --enable-static| exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  cd .. && rm -rf libunistring-*
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libunistring结束⭐⭐⭐⭐⭐⭐" 
}

build_libidn2() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libidn2⭐⭐⭐⭐⭐⭐" 
  wget -O- https://ftp.gnu.org/gnu/libidn/libidn2-2.3.7.tar.gz | tar xz || exit 1
  cd libidn2-* || exit 1
  ./configure --build=x86_64-pc-linux-gnu --host=$PREFIX --with-included-libunistring --disable-shared --enable-static --disable-doc --disable-gcc-warnings --prefix=$INSTALLDIR || exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  cd .. && rm -rf libidn2-*
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libidn2结束⭐⭐⭐⭐⭐⭐" 
}

build_libtasn1() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libtasn1⭐⭐⭐⭐⭐⭐"
  wget -O- https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.19.0.tar.gz | tar xz || exit 1
  cd libtasn1-* || exit 1
  ./configure --host=$PREFIX --disable-shared --disable-doc --prefix="$INSTALLDIR" || exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  cd .. && rm -rf libtasn1-*
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libtasn1结束⭐⭐⭐⭐⭐⭐"
}

build_PCRE2() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build PCRE2⭐⭐⭐⭐⭐⭐" 
  git clone -j$(nproc) https://github.com/PCRE2Project/pcre2 || exit 1
  cd pcre2 || exit 1
  ./autogen.sh || exit 1
  ./configure --host=$PREFIX --prefix=$INSTALLDIR --disable-shared --enable-static || exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  cd .. && rm -rf pcre2
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build PCRE2结束⭐⭐⭐⭐⭐⭐" 
}

build_nghttp2() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build nghttp2⭐⭐⭐⭐⭐⭐" 
  wget -O- https://github.com/nghttp2/nghttp2/releases/download/v1.63.0/nghttp2-1.63.0.tar.gz | tar xz || exit 1
  cd nghttp2-* || exit 1
  ./configure --build=x86_64-pc-linux-gnu --host=$PREFIX --prefix=$INSTALLDIR --disable-shared --enable-static --disable-python-bindings --disable-examples --disable-app --disable-failmalloc --disable-hpack-tools || exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  cd .. && rm -rf nghttp2-*
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build nghttp2结束⭐⭐⭐⭐⭐⭐" 
}

build_dlfcn-win32() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build dlfcn-win32⭐⭐⭐⭐⭐⭐" 
  git clone -j$(nproc) --depth=1 https://github.com/dlfcn-win32/dlfcn-win32.git || exit 1
  cd dlfcn-win32 || exit 1
  ./configure --prefix=$PREFIX --cc=$PREFIX-gcc || exit 1
  make -j$(nproc) || exit 1
  cp -p libdl.a $INSTALLDIR/lib/ || exit 1
  cp -p src/dlfcn.h $INSTALLDIR/include/ || exit 1
  cd .. && rm -rf dlfcn-win32
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build dlfcn-win32结束⭐⭐⭐⭐⭐⭐" 
}

build_libmicrohttpd() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libmicrohttpd⭐⭐⭐⭐⭐⭐" 
  wget -O- https://ftp.gnu.org/gnu/libmicrohttpd/libmicrohttpd-latest.tar.gz | tar xz || exit 1
  cd libmicrohttpd-* || exit 1
  ./configure --build=x86_64-pc-linux-gnu --host=$PREFIX --prefix=$INSTALLDIR --disable-shared --enable-static \
            --disable-examples --disable-doc --disable-tools || exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  cd .. && rm -rf libmicrohttpd-*
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libmicrohttpd结束⭐⭐⭐⭐⭐⭐" 
}

build_libpsl() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libpsl⭐⭐⭐⭐⭐⭐" 
  git clone -j$(nproc) --recursive https://github.com/rockdaboot/libpsl.git || exit 1
  cd libpsl || exit 1
  ./autogen.sh || exit 1
  ./configure --build=x86_64-pc-linux-gnu --host=$PREFIX --disable-shared --enable-static --enable-runtime=libidn2 --enable-builtin --prefix=$INSTALLDIR || exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  cd .. && rm -rf libpsl
}

build_nettle() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build nettle⭐⭐⭐⭐⭐⭐" 
  git clone -j$(nproc) https://github.com/sailfishos-mirror/nettle.git || exit 1
  cd nettle || exit 1
  bash .bootstrap || exit 1
  ./configure --build=x86_64-pc-linux-gnu --host=$PREFIX --enable-mini-gmp --disable-shared --enable-static --disable-documentation --prefix=$INSTALLDIR || exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  cd .. && rm -rf nettle
}

build_gnutls() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gnutls⭐⭐⭐⭐⭐⭐" 
  wget -O- https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.3.tar.xz | tar x --xz || exit 1
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
}

build_wget2() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build wget2⭐⭐⭐⭐⭐⭐" 
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
#build_dlfcn-win32 &
build_libmicrohttpd &
wait
build_libpsl
build_nettle
build_gnutls
build_wget2
