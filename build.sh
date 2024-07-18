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



echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build wget2⭐⭐⭐⭐⭐⭐" 
git clone https://github.com/rockdaboot/wget2.git || exit 1
cd wget2 || exit 1
./bootstrap --skip-po || exit 1
export LDFLAGS="-Wl,-Bstatic,--whole-archive -lwinpthread -Wl,--no-whole-archive"
export CFLAGS="-O2 -DNGHTTP2_STATICLIB"
./configure --build=x86_64-pc-linux-gnu --host=$PREFIX --with-libiconv-prefix="$INSTALLDIR" --with-ssl=gnutls --disable-shared --enable-static --without-lzma --without-zstd --without-bzip2 --without-lzip  --without-libpsl --without-brotlidec --with-ssl=none --without-gpgme --enable-threads=windows || exit 1
make -j$(nproc) || exit 1
strip $INSTALLDIR/wget2/src/wget2.exe || exit 1
cp -fv "$INSTALLDIR/wget2/src/wget2.exe" "${GITHUB_WORKSPACE}" || exit 1
