Wget2 for Windows

| library       | Version  | Source              |
|---------------| ---------------------|-----------------------|
| gnulib-mirror | Git    | [https://git.savannah.gnu.org/git/gnulib.git](https://git.savannah.gnu.org/git/gnulib.git)  |
| libiconv      | 1.18   | [https://ftp.gnu.org/gnu/libiconv/libiconv-1.18.tar.gz](https://ftp.gnu.org/gnu/libiconv/libiconv-1.18.tar.gz)  |
| libunistring  | 1.4.1  | [https://ftp.gnu.org/gnu/libunistring/libunistring-1.4.1.tar.gz](https://ftp.gnu.org/gnu/libunistring/libunistring-1.4.1.tar.gz) |
| libidn2       | 2.3.8  | [https://mirrors.ustc.edu.cn/gnu/libidn/libidn2-2.3.8.tar.gz](https://mirrors.ustc.edu.cn/gnu/libidn/libidn2-2.3.8.tar.gz) |
| libpsl        | Git    | [https://github.com/rockdaboot/libpsl.git](https://github.com/rockdaboot/libpsl.git)  |
| nettle        | 3.10.2 | [https://ftp.gnu.org/gnu/nettle/nettle-3.10.2.tar.gz](https://ftp.gnu.org/gnu/nettle/nettle-3.10.2.tar.gz)  |
| libtasn1      | 4.21.0 | [https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.21.0.tar.gz](https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.21.0.tar.gz) |
| gnutls        | 3.8.13 | [https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.13.tar.xz](https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.13.tar.xz)  |
| zlib-ng       | Git    | [https://github.com/zlib-ng/zlib-ng](https://github.com/zlib-ng/zlib-ng)  |
| PCRE2         | Git    | [https://github.com/PCRE2Project/pcre2](https://github.com/PCRE2Project/pcre2) |
| nghttp2       | 1.67.1 | [https://github.com/nghttp2/nghttp2/releases/download/v1.67.1/nghttp2-1.67.1.tar.gz](https://github.com/nghttp2/nghttp2/releases/download/v1.67.1/nghttp2-1.67.1.tar.gz) |
| dlfcn-win32   | Git    | [https://github.com/dlfcn-win32/dlfcn-win32.git](https://github.com/dlfcn-win32/dlfcn-win32.git)  |
| libmicrohttpd | 1.0.1  | [https://ftp.gnu.org/gnu/libmicrohttpd/libmicrohttpd-latest.tar.gz](https://ftp.gnu.org/gnu/libmicrohttpd/libmicrohttpd-latest.tar.gz)  |



Ubuntu 26.04

sudo apt update

sudo apt install -y cmake make make-guile build-essential ninja-build bc autoconf automake libtool autopoint gettext texinfo flex bison lzip dash git

sudo apt install -y gtk-doc-tools help2man python3 nettle-dev libp11-kit-dev libtspi-dev libunistring-dev libtasn1-bin libtasn1-6-dev libidn2-0-dev gawk gperf

sudo apt install -y libtss2-dev libunbound-dev dns-root-data bison gtk-doc-tools texinfo texlive texlive-plain-generic texlive-extra-utils

sudo apt install -y mingw-w64 mingw-w64-tools


./github-proxy.sh


./build.sh



<img width="1716" height="924" alt="image" src="https://github.com/user-attachments/assets/1727ed36-164f-4649-97e2-c67836ad7aa0" />


