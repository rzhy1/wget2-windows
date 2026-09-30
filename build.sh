#!/bin/bash
# wget2 build script for Windows environment
# Author: rzhy1
# 2024/6/30

# 设置环境变量
export PREFIX="x86_64-w64-mingw32"
export INSTALLDIR="$HOME/usr/local/$PREFIX"
# exe 交付目录：未设置时默认取脚本自身所在目录（Windows 侧即 D:\wget2）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export GITHUB_WORKSPACE="${GITHUB_WORKSPACE:-$SCRIPT_DIR}"
export PKG_CONFIG_PATH="$INSTALLDIR/lib/pkgconfig:/usr/$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"
export PKG_CONFIG_LIBDIR="$INSTALLDIR/lib/pkgconfig"
export PKG_CONFIG="/usr/bin/${PREFIX}-pkg-config"
export CPPFLAGS="-I$INSTALLDIR/include"
export LDFLAGS="-L$INSTALLDIR/lib -static"
export CFLAGS="-march=x86-64-v3 -mtune=raptorlake -O2 -g0 -fvisibility=hidden"
export CXXFLAGS="$CFLAGS"
export WINEPATH="$INSTALLDIR/bin;$INSTALLDIR/lib;/usr/$PREFIX/bin;/usr/$PREFIX/lib"
export LD=x86_64-w64-mingw32-ld.lld
export CC_FOR_BUILD=gcc    # 交叉编译 build 系统辅助程序用原生 gcc（gmp 必需，否则 Cannot determine executable suffix）
ln -s $(which lld-link) /usr/bin/x86_64-w64-mingw32-ld.lld
# 当前路径是：/__w/wget2-windows/wget2-windows
# INSTALLDIR是：/github/home/usr/local/x86_64-w64-mingw32

# ========== 镜像测速选择函数（纯 Shell）==========
select_fastest_gnu_mirror() {
    # 候选镜像列表（按推荐顺序，阿里云为首要默认）
    local candidates=(
        "https://mirrors.aliyun.com/gnu"
        "https://mirrors.tuna.tsinghua.edu.cn/gnu"
        "https://mirrors.huaweicloud.com/gnu"
        "https://mirrors.ustc.edu.cn/gnu"
        "https://mirrors.tencent.com/gnu"
        "https://ftp.gnu.org/gnu"
        "https://ftp.jaist.ac.jp/pub/GNU"
        "http://mirrors.kernel.org/gnu"
    )

    # 默认最快镜像设为阿里云（保证总有输出）
    local fastest_url="${candidates[0]}"
    local fastest_time=999999
    local mirror http_code tmp_time curl_output

    echo "[测速] 正在测试 GNU 镜像响应速度..." >&2

    for mirror in "${candidates[@]}"; do
        # ---------- 优先使用 curl（最准确）----------
        if command -v curl >/dev/null 2>&1; then
            # 获取 HTTP 状态码和总耗时（单位：秒）
            curl_output=$(curl -o /dev/null -s -w '%{http_code} %{time_total}' \
                --connect-timeout 3 --max-time 5 "${mirror}/" 2>/dev/null)
            http_code=$(echo "$curl_output" | awk '{print $1}')
            tmp_time=$(echo "$curl_output" | awk '{print $2}')

            # 严格校验：状态码为 2xx/3xx，且耗时是有效正数
            if echo "$http_code" | grep -qE '^[0-9]+$' && \
               [ "$http_code" -ge 200 ] && [ "$http_code" -lt 400 ] && \
               echo "$tmp_time" | grep -qE '^[0-9]+(\.[0-9]+)?$' && \
               awk -v t="$tmp_time" 'BEGIN{exit !(t > 0)}' 2>/dev/null; then
                
                printf "  %-45s %.3f 秒 (HTTP %s)\n" "$mirror" "$tmp_time" "$http_code" >&2
                
                # 比较浮点时间（纯 awk，无 bc 依赖）
                if awk -v t1="$tmp_time" -v t2="$fastest_time" 'BEGIN{exit !(t1 < t2)}' 2>/dev/null; then
                    fastest_time=$tmp_time
                    fastest_url=$mirror
                fi
            else
                printf "  %-45s 失败 (HTTP %s)\n" "$mirror" "$http_code" >&2
            fi

        # ---------- 备选：wget（仅简单检测）----------
        elif command -v wget >/dev/null 2>&1; then
            if wget --spider --timeout=3 --tries=1 -O /dev/null "${mirror}/" 2>&1 | \
               grep -qE "HTTP/.* 200|HTTP/.* 301"; then
                # wget 无法精确获取耗时，统一标记为 1.0 秒（仅作连通性判断）
                tmp_time=1.0
                printf "  %-45s 可用 (wget)\n" "$mirror" >&2
                # 简单比较：只要比当前最快小就选（实际是 1.0 vs 999999）
                if awk -v t1="$tmp_time" -v t2="$fastest_time" 'BEGIN{exit !(t1 < t2)}' 2>/dev/null; then
                    fastest_time=$tmp_time
                    fastest_url=$mirror
                fi
            else
                printf "  %-45s 失败 (wget)\n" "$mirror" >&2
            fi
        else
            echo "[错误] 系统中既没有 curl 也没有 wget，无法测速！" >&2
            break
        fi
    done

    echo >&2
    echo "[选择] 最快镜像: ${fastest_url} (${fastest_time}s)" >&2

    # ★★★ 唯一输出到 stdout 的内容，供变量捕获 ★★★
    echo "$fastest_url"
}
GNU_MIRROR=$(select_fastest_gnu_mirror)
export GNU_MIRROR
echo "使用镜像源: $GNU_MIRROR" >&2

mkdir -p $INSTALLDIR
cd $INSTALLDIR
build_brotli() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build brotli⭐⭐⭐⭐⭐⭐"
  local start_time=$(date +%s.%N)
  git clone --depth=1 https://github.com/google/brotli.git || exit 1
  cd brotli || exit 1
  mkdir build && cd build
  cmake .. \
    -DCMAKE_SYSTEM_NAME=Windows \
    -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
    -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ \
    -DCMAKE_INSTALL_PREFIX=$INSTALLDIR \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS="-I${PWD}/../c/include" \
    -DCMAKE_CXX_FLAGS="-I${PWD}/../c/include" || exit 1
  make -j$(nproc) install || exit 1
  sed -i 's/^Libs: .*/& -lbrotlicommon/' "$INSTALLDIR/lib/pkgconfig/libbrotlidec.pc"
  cd ../..
  local end_time=$(date +%s.%N)
  local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
  echo "$duration" > "$INSTALLDIR/brotli_duration.txt"
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - pkg-config --cflags --libs libbrotlienc libbrotlidec libbrotlicommo结果如下⭐⭐⭐⭐⭐⭐" 
  pkg-config --cflags --libs libbrotlienc libbrotlidec libbrotlicommon
  echo "显示libbrotlidec.pc内容"
  cat $INSTALLDIR/lib/pkgconfig/libbrotlidec.pc
}

build_xz() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build xz⭐⭐⭐⭐⭐⭐" 
  local start_time=$(date +%s.%N)
  apt-get purge xz-utils
  git clone --depth=1 https://github.com/tukaani-project/xz.git || { echo "Git clone failed"; exit 1; }
  cd xz || { echo "cd xz failed"; exit 1; }
  mkdir build
  cd build
  cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Release -DXZ_NLS=ON -DBUILD_SHARED_LIBS=OFF || { echo "CMake failed"; exit 1; }
  cmake --build . -- -j$(nproc) || { echo "Build failed"; exit 1; }
  cmake --install . || { echo "Install failed"; exit 1; }
  xz --version
  cd ../..
  local end_time=$(date +%s.%N)
  local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
  echo "$duration" > "$INSTALLDIR/xz_duration.txt"
}

build_zstd() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build zstd⭐⭐⭐⭐⭐⭐" 
  local start_time=$(date +%s.%N)
  # 创建 Python 虚拟环境并安装meson
  rm -rf /tmp/venv
  python3 -m venv /tmp/venv
  source /tmp/venv/bin/activate
  pip3 install --no-cache-dir meson pytest

  # 编译 zstd
  git clone --depth=1 https://github.com/facebook/zstd.git || exit 1
  cd zstd || exit 1
  meson setup \
    --cross-file=${GITHUB_WORKSPACE}/cross_file.txt \
    --backend=ninja \
    --prefix=$INSTALLDIR \
    --libdir=$INSTALLDIR/lib \
    --bindir=$INSTALLDIR/bin \
    --pkg-config-path="$INSTALLDIR/lib/pkgconfig" \
    -Dbin_programs=false \
    -Dstatic_runtime=true \
    -Ddefault_library=static \
    -Db_lto=true --optimization=2 \
    build/meson builddir-st || exit 1
  rm -f /usr/local/bin/zstd*
  rm -f /usr/local/bin/*zstd
  meson compile -C builddir-st || exit 1
  meson install -C builddir-st || exit 1
  cd .. && rm -rf zstd
  local end_time=$(date +%s.%N)
  local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
  echo "$duration" > "$INSTALLDIR/zstd_duration.txt"
}

build_zstd_with_no_meson() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build zstd⭐⭐⭐⭐⭐⭐" 
  local start_time=$(date +%s.%N)
  # 编译 zstd：官方 Makefile + mingw 交叉工具链
  # （meson 若无 cross-file 会误用原生 gcc 产出 ELF 对象，mingw 链接器无法使用，故不用 meson）
  git clone --depth=1 https://github.com/facebook/zstd.git || exit 1
  cd zstd || exit 1
  make -C lib libzstd.a -j$(nproc) \
    CC=x86_64-w64-mingw32-gcc \
    AR=x86_64-w64-mingw32-ar \
    RANLIB=x86_64-w64-mingw32-ranlib \
    CFLAGS="$CFLAGS" \
    ZSTD_LEGACY_SUPPORT=0 || exit 1
  # 安装静态库、头文件、pkg-config
  install -d "$INSTALLDIR/lib" "$INSTALLDIR/include" "$INSTALLDIR/lib/pkgconfig"
  cp -fv lib/libzstd.a "$INSTALLDIR/lib/" || exit 1
  # 安装头文件：zstd.h 会 #include "zstd_errors.h"（位于 lib/zstd_errors.h，不在 lib/common/），
  #   故整目录安装 lib/*.h 与 lib/common/*.h，确保 gnutls/wget2 编译时能找到
  cp -fv lib/*.h "$INSTALLDIR/include/" 2>/dev/null || true
  cp -fv lib/common/*.h "$INSTALLDIR/include/" 2>/dev/null || true
  cat > "$INSTALLDIR/lib/pkgconfig/libzstd.pc" <<'PC'
prefix=@INSTALLDIR@
libdir=${prefix}/lib
includedir=${prefix}/include

Name: zstd
Description: Zstandard compression library
Version: 1.6.0
Libs: -L${libdir} -lzstd
Cflags: -I${includedir}
PC
  sed -i "s|@INSTALLDIR@|$INSTALLDIR|g" "$INSTALLDIR/lib/pkgconfig/libzstd.pc"
  rm -f /usr/local/bin/zstd*
  cd ..
  local end_time=$(date +%s.%N)
  local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
  echo "$duration" > "$INSTALLDIR/zstd_duration.txt"
}

build_zlib-ng() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build zlib-ng⭐⭐⭐⭐⭐⭐" 
  local start_time=$(date +%s.%N)
  git clone --depth=1 https://github.com/zlib-ng/zlib-ng || exit 1
  cd zlib-ng || exit 1
  CROSS_PREFIX="x86_64-w64-mingw32-" ARCH="x86_64" CFLAGS="-Os" CC=x86_64-w64-mingw32-gcc ./configure --prefix=$INSTALLDIR --static --64 --zlib-compat || exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  cd ..
  local end_time=$(date +%s.%N)
  local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
  echo "$duration" > "$INSTALLDIR/zlib-ng_duration.txt"
}

build_gmp() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gmp⭐⭐⭐⭐⭐⭐" 
  local start_time=$(date +%s.%N)
  wget -nv -O- ${GNU_MIRROR}/gmp/gmp-6.3.0.tar.xz | tar x --xz
  cd gmp-* || exit
  sed -i 's/void g();/void g(int a,int b,int c,int d,int e,int f);/' configure
  ./configure --host=$PREFIX --disable-shared --prefix="$INSTALLDIR"
  make -j$(nproc) || exit 1
  make install || exit 1
  cd ..
  local end_time=$(date +%s.%N)
  local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
  echo "$duration" > "$INSTALLDIR/gmp_duration.txt"
}

build_gnulibmirror() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gnulib-mirror⭐⭐⭐⭐⭐⭐" 
  local start_time=$(date +%s.%N)
  git clone --recursive --depth=1 https://gitlab.com/gnuwget/gnulib-mirror.git gnulib || exit 1
  export GNULIB_REFDIR=$INSTALLDIR/gnulib
  local end_time=$(date +%s.%N)
  local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
  echo "$duration" > "$INSTALLDIR/gnulibmirror_duration.txt"
}

build_libiconv() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libiconv⭐⭐⭐⭐⭐⭐" 
  local start_time=$(date +%s.%N)
  wget -O- ${GNU_MIRROR}/libiconv/libiconv-1.19.tar.gz | tar xz || exit 1
  cd libiconv-* || exit 1
  ./configure --build=x86_64-pc-linux-gnu --host=$PREFIX --disable-shared --enable-static --disable-nls --disable-silent-rules --prefix=$INSTALLDIR || exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  cd ..
  local end_time=$(date +%s.%N)
  local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
  echo "$duration" > "$INSTALLDIR/libiconv_duration.txt"
}

build_libunistring() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libunistring⭐⭐⭐⭐⭐⭐" 
  local start_time=$(date +%s.%N)
  wget -O- ${GNU_MIRROR}/libunistring/libunistring-1.4.2.tar.gz | tar xz || exit 1
  cd libunistring-* || exit 1
  ac_cv_func_nanosleep=yes ./configure CFLAGS="-Os" --build=x86_64-pc-linux-gnu --host=$PREFIX --prefix=$INSTALLDIR --disable-shared --enable-static --disable-doc --disable-silent-rules || exit 1
  make -C lib -j$(nproc) || exit 1
  make -C lib install || exit 1
  cd ..
  local end_time=$(date +%s.%N)
  local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
  echo "$duration" > "$INSTALLDIR/libunistring_duration.txt"
}

build_libidn2() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libidn2⭐⭐⭐⭐⭐⭐" 
  local start_time=$(date +%s.%N)
  wget -O- ${GNU_MIRROR}/libidn/libidn2-2.3.8.tar.gz | tar xz || exit 1
  cd libidn2-* || exit 1
  ./configure --build=x86_64-pc-linux-gnu --host=$PREFIX  --disable-shared --enable-static --disable-doc --disable-gcc-warnings --prefix=$INSTALLDIR || exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  cd ..
  local end_time=$(date +%s.%N)
  local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
  echo "$duration" > "$INSTALLDIR/libidn2_duration.txt"
}

build_libtasn1() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libtasn1⭐⭐⭐⭐⭐⭐"
  local start_time=$(date +%s.%N)
  wget -O- ${GNU_MIRROR}/libtasn1/libtasn1-4.21.0.tar.gz | tar xz || exit 1
  cd libtasn1-* || exit 1
  ./configure --host=$PREFIX --disable-shared --disable-doc --prefix="$INSTALLDIR" || exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  cd ..
  local end_time=$(date +%s.%N)
  local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
  echo "$duration" > "$INSTALLDIR/libtasn1_duration.txt"
}

build_PCRE2() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build PCRE2⭐⭐⭐⭐⭐⭐" 
  local start_time=$(date +%s.%N)
  git clone --depth=1 https://github.com/PCRE2Project/pcre2 || exit 1
  cd pcre2 || exit 1
  ./autogen.sh || exit 1
  ./configure --host=$PREFIX --prefix=$INSTALLDIR --disable-shared --enable-static || exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  cd ..
  local end_time=$(date +%s.%N)
  local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
  echo "$duration" > "$INSTALLDIR/pcre2_duration.txt"
}

wget_github() {
  local raw=$1 k v p best= bestp=
  while IFS=' ' read -r k v; do
    p=${k#url.}
    p=${p%.insteadof}
    p=${p%.insteadOf}
    [[ $raw == "$v"* ]] || continue
    ((${#v} > ${#best})) && { best=$v; bestp=$p; }
  done < <(git config --global --get-regexp '^url\..*\.insteadof$' 2>/dev/null)

  if [[ -n $bestp ]]; then
    # 关键改动：替换匹配前缀，而不是拼接完整 URL
    wget -t 10 -O- "${bestp}${raw#"$best"}" | tar xz || exit 1
  else
    wget -t 10 -O- "$raw" | tar xz || exit 1
  fi
}

build_nghttp2() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build nghttp2⭐⭐⭐⭐⭐⭐" 
  local start_time=$(date +%s.%N)
  #wget -t 10 -O- https://github.com/nghttp2/nghttp2/releases/download/v1.68.1/nghttp2-1.68.1.tar.gz | tar xz || exit 1
  wget_github https://github.com/nghttp2/nghttp2/releases/download/v1.68.1/nghttp2-1.68.1.tar.gz
  cd nghttp2-* || exit 1
  ./configure --build=x86_64-pc-linux-gnu --host=$PREFIX --prefix=$INSTALLDIR --disable-shared --enable-static --disable-examples --disable-app --disable-failmalloc --disable-hpack-tools || exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  cd ..
  local end_time=$(date +%s.%N)
  duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
  echo "$duration" > "$INSTALLDIR/nghttp2_duration.txt"
}

build_dlfcn-win32() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build dlfcn-win32⭐⭐⭐⭐⭐⭐" 
  local start_time=$(date +%s.%N)
  git clone --depth=1 https://github.com/dlfcn-win32/dlfcn-win32.git || exit 1
  cd dlfcn-win32 || exit 1
  ./configure --prefix=$PREFIX --cc=$PREFIX-gcc || exit 1
  make -j$(nproc) || exit 1
  cp -p libdl.a $INSTALLDIR/lib/ || exit 1
  cp -p src/dlfcn.h $INSTALLDIR/include/ || exit 1
  cd ..
  local end_time=$(date +%s.%N)
  local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
  echo "$duration" > "$INSTALLDIR/dlfcn-win32_duration.txt"
}

build_libmicrohttpd() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libmicrohttpd⭐⭐⭐⭐⭐⭐" 
  local start_time=$(date +%s.%N)
  wget -O- ${GNU_MIRROR}/libmicrohttpd/libmicrohttpd-latest.tar.gz | tar xz || exit 1
  cd libmicrohttpd-* || exit 1
  ./configure --build=x86_64-pc-linux-gnu --host=$PREFIX --prefix=$INSTALLDIR --disable-shared --enable-static \
            --disable-examples --disable-doc --disable-tools --disable-silent-rules || exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  cd ..
  local end_time=$(date +%s.%N)
  local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
  echo "$duration" > "$INSTALLDIR/libmicrohttpd_duration.txt"
}

build_libpsl() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build libpsl⭐⭐⭐⭐⭐⭐" 
  local start_time=$(date +%s.%N)
  git clone --depth=1 --recursive https://github.com/rockdaboot/libpsl.git || exit 1
  cd libpsl || exit 1
  ./autogen.sh || exit 1
  ./configure --build=x86_64-pc-linux-gnu --host=$PREFIX --disable-shared --enable-static --enable-runtime=libidn2 --enable-builtin --prefix=$INSTALLDIR || exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  cd ..
  local end_time=$(date +%s.%N)
  local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
  echo "$duration" > "$INSTALLDIR/libpsl_duration.txt"
}

build_nettle() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build nettle⭐⭐⭐⭐⭐⭐"
  local start_time=$(date +%s.%N)
  #git clone  https://github.com/sailfishos-mirror/nettle.git || exit 1
  wget -O- ${GNU_MIRROR}/nettle/nettle-3.10.2.tar.gz | tar xz || exit 1
  cd nettle-* || exit 1
  bash .bootstrap || exit 1
  ./configure --host="$PREFIX" --disable-shared --enable-static --disable-documentation --prefix="$INSTALLDIR" --libdir="$INSTALLDIR/lib" || exit 1
  make -j"$(nproc)" || exit 1
  make install || exit 1
  cd ..
  local end_time=$(date +%s.%N)
  local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
  echo "$duration" > "$INSTALLDIR/nettle_duration.txt"
}

build_gnutls() {
  echo "⭐⭐⭐⭐⭐⭐$(date '+%Y/%m/%d %a %H:%M:%S.%N') - build gnutls⭐⭐⭐⭐⭐⭐" 
  local start_time=$(date +%s.%N)
  wget -O- https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.13.tar.xz | tar x --xz || exit 1
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
  LIBS="-lwinpthread" \
  ac_cv_func_nanosleep='yes' \
  gl_cv_func_nanosleep='yes' \
  ./configure CFLAGS="$CFLAGS" --host=$PREFIX --prefix=$INSTALLDIR --with-included-unistring --disable-openssl-compatibility --disable-hardware-acceleration --disable-shared --enable-static --without-p11-kit --disable-doc --disable-tests --disable-full-test-suite --disable-tools --disable-cxx --disable-maintainer-mode --disable-libdane || exit 1
  make -j$(nproc) || exit 1
  make install || exit 1
  # 修补安装的 gnutls.h：让 _SYM_EXPORT 尊重 GNUTLS_STATIC（wget2 静态链接不再产生 __imp_gnutls_* 导入符号）
  sed -i 's|#if !defined(GNUTLS_INTERNAL_BUILD) && defined(_WIN32)|#if !defined(GNUTLS_INTERNAL_BUILD) \&\& !defined(GNUTLS_STATIC) \&\& defined(_WIN32)|' "$INSTALLDIR/include/gnutls/gnutls.h"
  cd ..
  local end_time=$(date +%s.%N)
  local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
  echo "$duration" > "$INSTALLDIR/gnutls_duration.txt"
}

build_wget2() {
    echo "⭐⭐⭐⭐⭐⭐ $(date '+%Y/%m/%d %a %H:%M:%S.%N') - build wget2 ⭐⭐⭐⭐⭐⭐"
    local start_time=$(date +%s.%N)

    # ---------- 1. 拉取源码 ----------
    git clone --depth=1 https://github.com/rockdaboot/wget2.git || exit 1
    cd wget2 || exit 1

    if [ -d "gnulib" ]; then
        rm -rf gnulib
    fi
    git clone --depth=1 https://github.com/coreutils/gnulib.git

    # ---------- 2. 构建前源码预处理 ----------
    # 预留 MAINTAINERCLEANFILES，规避 automake 相关报错
    sed -i '1i MAINTAINERCLEANFILES =' lib/Makefile.am

    # 删除旧 config.guess/config.sub，避免 libtoolize 报 "newer" 错误
    rm -f build-aux/config.guess build-aux/config.sub

    # 用 gnulib 重新生成构建系统
    ./bootstrap --skip-po --gnulib-srcdir=gnulib || exit 1

    # hashfile.c 补 gnutls 头文件，解决 gnutls_hash_hd_t 未定义（必需）
    sed -i '/#include "private.h"/a #include <gnutls/gnutls.h>\n#include <gnutls/crypto.h>' libwget/hashfile.c

    # ---------- 3. 编译/链接环境变量 ----------
    # -lwinpthread 静态打包线程库
    export LDFLAGS="$LDFLAGS -L$INSTALLDIR/lib -Wl,-Bstatic,--whole-archive -lwinpthread -Wl,--no-whole-archive"
    # -DNGHTTP2_STATICLIB 静态 nghttp2；-D_WIN32_WINNT=0x0501 完整 winsock API；-DGNUTLS_STATIC 静态 gnutls；-Wno-attributes 消 dllimport 警告
    export CPPFLAGS="-I$INSTALLDIR/include -DNGHTTP2_STATICLIB -D_WIN32_WINNT=0x0501 -DGNUTLS_STATIC -Wno-attributes"
    export CFLAGS="$CFLAGS"

    # ---------- 4. configure ----------
    # 关键 gl_cv_* 缓存变量直接作为 configure 参数传入，确保生效：
    #   gl_cv_w32_getaddrinfo=yes → HAVE_GETADDRINFO=1（走 Windows 原生 getaddrinfo，避免 getnameinfo 类型冲突）
    #   gl_cv_func_wsastartup=yes  → WINDOWS_SOCKETS=1（WSAStartup 真正初始化 + socket I/O 正常）
    # LIBS 显式带上压缩库：examples/ 链接的是静态 convenience 库 libwget.a，其 -lzstd 依赖不会自动带入，
    #   必须放进 LIBS 才会进入所有链接目标（否则 examples 报 ZSTD_* undefined）
    export LIBS="-lzstd -lbrotlidec -lbrotlicommon -lz -lws2_32 -liphlpapi"
    ./configure \
        --build=x86_64-pc-linux-gnu \
        --host="$PREFIX" \
        --with-libiconv-prefix="$INSTALLDIR" \
        --with-ssl=gnutls \
        --disable-shared --enable-static \
        --without-lzma --with-zstd \
        --without-bzip2 --without-lzip --without-gpgme \
        --enable-threads=windows \
        gl_cv_w32_getaddrinfo=yes \
        gl_cv_func_wsastartup=yes \
        || exit 1

    # 修复 gnulib 生成的畸形 flag -lws2_32-lws2_32（缺空格，会让链接报 cannot find -lws2_32-lws2_32）
    grep -rl 'ws2_32-lws2_32' --include='*.la' --include='Makefile' . 2>/dev/null | while read f; do
        sed -i 's/-lws2_32-lws2_32/-lws2_32/g' "$f"
    done

    # ---------- 5. 修补测试辅助库 libtest（必需：mingw 缺 F_GETFL/F_SETFL，不改则 make all 编译 libtest 失败） ----------
    sed -i '/#include <config.h>/a #ifdef _WIN32\n#include <winsock2.h>\n#endif' tests/libtest.c
    sed -i 's/int flags = fcntl(client_fd, F_GETFL, 0);/#ifdef _WIN32\n\t\tunsigned long mode = 1;\n\t\tioctlsocket(client_fd, FIONBIO, \&mode);\n#else\n\t\tint flags = fcntl(client_fd, F_GETFL, 0);/' tests/libtest.c
    sed -i '/fcntl(client_fd, F_SETFL, flags | O_NONBLOCK);/a #endif' tests/libtest.c

    # ---------- 6. 编译 ----------
    make -j"$(nproc)" || exit 1

    # ---------- 7. 定位并交付 exe（libtool 交叉编译，真正的 exe 可能在 src/.libs/ 下） ----------
    WGET2_BIN="src/.libs/wget2.exe"
    [ ! -f "$WGET2_BIN" ] && WGET2_BIN="src/wget2.exe"
    [ ! -f "$WGET2_BIN" ] && { echo "ERROR: wget2.exe not found!"; exit 1; }
    strip "$WGET2_BIN" || exit 1
    cp -fv "$WGET2_BIN" "${GITHUB_WORKSPACE}" || exit 1

    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc | xargs printf "%.1f")
    echo "✅ Build completed, elapsed: ${duration}s"
    echo "$duration" > "$INSTALLDIR/wget2_duration.txt"
}

build_brotli
#build_zstd
build_zstd_with_no_meson
build_zlib-ng
build_gmp
wait
build_libunistring
build_libtasn1
wait
build_libiconv
build_libidn2
wait
build_PCRE2
build_nghttp2
build_libmicrohttpd
wait
build_libpsl
build_nettle
build_gnutls
build_wget2

#duration1=$(cat $INSTALLDIR/xz_duration.txt)
duration2=$(cat $INSTALLDIR/zstd_duration.txt)
duration3=$(cat $INSTALLDIR/zlib-ng_duration.txt)
duration4=$(cat $INSTALLDIR/gmp_duration.txt)
#duration5=$(cat $INSTALLDIR/gnulibmirror_duration.txt)
duration6=$(cat $INSTALLDIR/libiconv_duration.txt)
duration7=$(cat $INSTALLDIR/libunistring_duration.txt)
duration8=$(cat $INSTALLDIR/libidn2_duration.txt)
duration9=$(cat $INSTALLDIR/libtasn1_duration.txt)
duration10=$(cat $INSTALLDIR/pcre2_duration.txt)
duration11=$(cat $INSTALLDIR/nghttp2_duration.txt)
#duration12=$(cat $INSTALLDIR/dlfcn-win32_duration.txt)
duration13=$(cat $INSTALLDIR/libmicrohttpd_duration.txt)
duration14=$(cat $INSTALLDIR/libpsl_duration.txt)
duration15=$(cat $INSTALLDIR/nettle_duration.txt)
duration16=$(cat $INSTALLDIR/gnutls_duration.txt)
duration17=$(cat $INSTALLDIR/wget2_duration.txt)

#echo "编译 xz 用时：${duration1}s"
echo "编译 zstd 用时：${duration2}s"
echo "编译 zlib-ng 用时：${duration3}s"
echo "编译 gmp 用时：${duration4}s"
#echo "编译 gnulibmirror 用时：${duration5}s"
echo "编译 libiconv 用时：${duration6}s"
echo "编译 libunistring 用时：${duration7}s"
echo "编译 libidn2 用时：${duration8}s"
echo "编译 libtasn1 用时：${duration9}s"
echo "编译 PCRE2 用时：${duration10}s"
echo "编译 nghttp2 用时：${duration11}s"
#echo "编译 dlfcn-win32 用时：${duration12}s"
echo "编译 libmicrohttpd 用时：${duration13}s"
echo "编译 libpsl 用时：${duration14}s"
echo "编译 nettle 用时：${duration15}s"
echo "编译 gnutls 用时：${duration16}s"
echo "编译 wget2 用时：${duration17}s"
