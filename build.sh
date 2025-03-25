#!/bin/bash
# 优化版 wget2 Windows 交叉编译脚本
# 特性：
# 1. 模块化设计，支持并行构建
# 2. 完善的错误处理和日志记录
# 3. 自动清理临时文件
# 4. 构建时间统计
# 使用方法：./build-wget2.sh

set -euo pipefail

# ======================= 配置部分 =======================
export PREFIX="x86_64-w64-mingw32"
export INSTALLDIR="$HOME/usr/local/$PREFIX"
export NPROC=$(nproc)
export BUILD_LOG="$INSTALLDIR/build.log"
export TEMP_DIR="/tmp/wget2-build"

# 工具链配置
export CC="${PREFIX}-gcc"
export CXX="${PREFIX}-g++"
export LD="${PREFIX}-ld.lld"
export AR="${PREFIX}-ar"
export RANLIB="${PREFIX}-ranlib"
export PKG_CONFIG="${PREFIX}-pkg-config"
export WINEPATH="$INSTALLDIR/bin;$INSTALLDIR/lib"

# 编译标志
export CFLAGS="-march=tigerlake -mtune=tigerlake -Os -pipe -flto=${NPROC} -g0"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-L$INSTALLDIR/lib -static -flto=${NPROC} -s"
export CPPFLAGS="-I$INSTALLDIR/include"
export PKG_CONFIG_PATH="$INSTALLDIR/lib/pkgconfig:/usr/$PREFIX/lib/pkgconfig"

# 创建必要目录
mkdir -p "$INSTALLDIR" "$TEMP_DIR"
exec > >(tee -a "$BUILD_LOG") 2>&1

# ======================= 工具函数 =======================
cleanup() {
    echo "🛠️ 清理临时文件..."
    rm -rf "$TEMP_DIR"/*
}

log_duration() {
    local name=$1
    local start=$2
    local end=$(date +%s.%N)
    local duration=$(printf "%.1f" $(echo "$end - $start" | bc))
    echo "$duration" > "$INSTALLDIR/${name}_duration.txt"
    echo "⏱️ $name 构建耗时: ${duration}s"
}

download_and_extract() {
    local url=$1 dirname=$2
    local tarball=$(basename "$url")
    
    echo "⬇️ 下载 $tarball..."
    if ! curl -fL "$url" -o "$TEMP_DIR/$tarball"; then
        echo "❌ 下载失败: $url"
        return 1
    fi

    echo "📦 解压 $tarball..."
    case "$tarball" in
        *.tar.gz|*.tgz) tar -xzf "$TEMP_DIR/$tarball" -C "$TEMP_DIR" ;;
        *.tar.xz) tar -xJf "$TEMP_DIR/$tarball" -C "$TEMP_DIR" ;;
        *.tar.bz2) tar -xjf "$TEMP_DIR/$tarball" -C "$TEMP_DIR" ;;
        *) echo "❌ 未知压缩格式: $tarball"; return 1 ;;
    esac

    cd "$TEMP_DIR/$dirname" || return 1
}

build_autotools_project() {
    local name=$1 url=$2 dirname=$3
    shift 3
    local configure_opts=("$@")
    local start_time=$(date +%s.%N)

    echo "🚀 开始构建 $name..."
    
    if ! download_and_extract "$url" "$dirname"; then
        return 1
    fi

    [ -f ./autogen.sh ] && ./autogen.sh
    [ -f ./bootstrap ] && ./bootstrap

    echo "⚙️ 配置选项: ${configure_opts[*]}"
    ./configure \
        --host="$PREFIX" \
        --prefix="$INSTALLDIR" \
        --disable-shared \
        --enable-static \
        "${configure_opts[@]}" || return 1

    make -j"$NPROC" || return 1
    make install || return 1

    log_duration "$name" "$start_time"
    cd "$TEMP_DIR" && rm -rf "$dirname"
}

build_git_project() {
    local name=$1 repo=$2
    shift 2
    local configure_opts=("$@")
    local start_time=$(date +%s.%N)

    echo "🚀 开始构建 $name (Git版本)..."
    git clone --depth=1 "$repo" "$TEMP_DIR/$name" || return 1
    cd "$TEMP_DIR/$name" || return 1

    [ -f ./autogen.sh ] && ./autogen.sh
    [ -f ./bootstrap ] && ./bootstrap

    ./configure \
        --host="$PREFIX" \
        --prefix="$INSTALLDIR" \
        --disable-shared \
        --enable-static \
        "${configure_opts[@]}" || return 1

    make -j"$NPROC" || return 1
    make install || return 1

    log_duration "$name" "$start_time"
    cd "$TEMP_DIR" && rm -rf "$name"
}

# ======================= 具体构建步骤 =======================
build_zstd() {
    local start_time=$(date +%s.%N)
    echo "🚀 开始构建 zstd..."
    
    python3 -m venv "$TEMP_DIR/zstd-venv"
    source "$TEMP_DIR/zstd-venv/bin/activate"
    pip install --no-cache-dir meson ninja

    git clone --depth=1 https://github.com/facebook/zstd.git "$TEMP_DIR/zstd" || return 1
    cd "$TEMP_DIR/zstd/build/meson" || return 1

    meson setup \
        --cross-file="${GITHUB_WORKSPACE}/cross_file.txt" \
        --prefix="$INSTALLDIR" \
        --libdir="$INSTALLDIR/lib" \
        -Dbin_programs=false \
        -Dstatic_runtime=true \
        -Ddefault_library=static \
        -Db_lto=true \
        --optimization=2 \
        builddir || return 1

    meson compile -C builddir || return 1
    meson install -C builddir || return 1

    log_duration "zstd" "$start_time"
    rm -rf "$TEMP_DIR/zstd" "$TEMP_DIR/zstd-venv"
}

build_zlib_ng() {
    build_git_project "zlib-ng" "https://github.com/zlib-ng/zlib-ng" \
        CROSS_PREFIX="${PREFIX}-" \
        ARCH="x86_64" \
        CC="${CC}" \
        --static \
        --64 \
        --zlib-compat
}

build_gmp() {
    build_autotools_project "gmp" \
        "https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz" \
        "gmp-6.3.0"
}

build_libiconv() {
    build_autotools_project "libiconv" \
        "https://ftp.gnu.org/gnu/libiconv/libiconv-1.17.tar.gz" \
        "libiconv-1.17" \
        --disable-nls
}

build_libunistring() {
    build_autotools_project "libunistring" \
        "https://ftp.gnu.org/gnu/libunistring/libunistring-1.2.tar.gz" \
        "libunistring-1.2" \
        CFLAGS="-Os"
}

build_libidn2() {
    build_autotools_project "libidn2" \
        "https://ftp.gnu.org/gnu/libidn/libidn2-2.3.8.tar.gz" \
        "libidn2-2.3.8" \
        --disable-doc \
        --disable-gcc-warnings
}

build_libtasn1() {
    build_autotools_project "libtasn1" \
        "https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.19.0.tar.gz" \
        "libtasn1-4.19.0" \
        --disable-doc
}

build_PCRE2() {
    build_git_project "pcre2" "https://github.com/PCRE2Project/pcre2"
}

build_nghttp2() {
    build_autotools_project "nghttp2" \
        "https://github.com/nghttp2/nghttp2/releases/download/v1.58.0/nghttp2-1.58.0.tar.gz" \
        "nghttp2-1.58.0" \
        --disable-examples \
        --disable-app \
        --disable-hpack-tools
}

build_libmicrohttpd() {
    build_autotools_project "libmicrohttpd" \
        "https://ftp.gnu.org/gnu/libmicrohttpd/libmicrohttpd-1.0.1.tar.gz" \
        "libmicrohttpd-1.0.1" \
        --disable-examples \
        --disable-doc \
        --disable-tools
}

build_libpsl() {
    build_git_project "libpsl" "https://github.com/rockdaboot/libpsl" \
        --enable-runtime=libidn2 \
        --enable-builtin
}

build_nettle() {
    build_git_project "nettle" "https://github.com/sailfishos-mirror/nettle" \
        --disable-documentation
}

build_gnutls() {
    local start_time=$(date +%s.%N)
    echo "🚀 开始构建 gnutls..."
    
    build_autotools_project "gnutls" \
        "https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.1.tar.xz" \
        "gnutls-3.8.1" \
        --disable-openssl-compatibility \
        --disable-hardware-acceleration \
        --without-p11-kit \
        --disable-doc \
        --disable-tests \
        --disable-tools \
        --disable-cxx \
        --disable-libdane \
        GMP_LIBS="-L$INSTALLDIR/lib -lgmp" \
        NETTLE_LIBS="-L$INSTALLDIR/lib -lnettle -lgmp" \
        HOGWEED_LIBS="-L$INSTALLDIR/lib -lhogweed -lnettle -lgmp" \
        LIBTASN1_LIBS="-L$INSTALLDIR/lib -ltasn1" \
        LIBIDN2_LIBS="-L$INSTALLDIR/lib -lidn2"

    log_duration "gnutls" "$start_time"
}

build_wget2() {
    local start_time=$(date +%s.%N)
    echo "🚀 开始构建 wget2..."
    
    build_git_project "wget2" "https://github.com/rockdaboot/wget2" \
        --with-libiconv-prefix="$INSTALLDIR" \
        --with-ssl=gnutls \
        --without-lzma \
        --with-zstd \
        --without-brotlidec \
        --without-bzip2 \
        --without-lzip \
        --without-gpgme \
        --enable-threads=windows

    # 特殊处理
    ${PREFIX}-strip "$INSTALLDIR/bin/wget2.exe"
    cp -fv "$INSTALLDIR/bin/wget2.exe" "${GITHUB_WORKSPACE:-.}/"

    log_duration "wget2" "$start_time"
}

# ======================= 主流程 =======================
main() {
    echo "🛠️ 开始构建 wget2 for Windows (${PREFIX})"
    echo "📦 安装目录: $INSTALLDIR"
    echo "💻 使用 $NPROC 个CPU核心"
    echo "📝 日志文件: $BUILD_LOG"

    # 第一阶段: 基础库
    build_zstd
    build_zlib_ng
    build_gmp

    # 第二阶段: 文本处理库
    build_libiconv
    build_libunistring
    build_libidn2
    build_libtasn1

    # 第三阶段: 网络库
    build_PCRE2
    build_nghttp2
    build_libmicrohttpd
    build_libpsl

    # 第四阶段: 加密库
    build_nettle
    build_gnutls

    # 最终构建
    build_wget2

    # 打印统计信息
    echo "⏱️ 构建时间统计:"
    cat "$INSTALLDIR"/*_duration.txt | while read -r line; do
        echo "  - $line"
    done | sort -nr -k2

    echo "🎉 wget2 构建成功! 输出文件: ${GITHUB_WORKSPACE:-.}/wget2.exe"
}

# 执行主函数并确保清理
trap cleanup EXIT
main
