#!/bin/sh
set -e
set -x

#FUNCTIONS
link_files () {  
  find /opt/sysroot$2 -mindepth 1 -depth -type d -printf "%P\n" | while read dir; do mkdir -p "/opt/sysroot$1/$dir"; done
  find /opt/sysroot$2 -not -type d -printf "%P\n" | while read file; do ln -s "$2/$file" "/opt/sysroot$1/$file"; done
}

#FETCH NEEDED TOOLS
apt-get install -y gawk bison wget patch build-essential bc libncurses5-dev flex texinfo unzip help2man libtool-bin python3 git nano kmod pkg-config autogen autopoint gettext libnl-cli-3-dev libssl-dev libelf-dev

#CREATE DIR STRUCTURE
rm -fr /opt/sysroot/*
cp -rv /opt/PowerOS/sysroot/* /opt/sysroot

#GET WIFI RULES DATABASE
cd /opt
git clone git://git.kernel.org/pub/scm/linux/kernel/git/linville/wireless-regdb.git

#KERNEL
cd /opt
export WIFIVERSION=
wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.2.3.tar.xz
mkdir /opt/kernel
tar xfv /opt/linux-5.2.3.tar.xz -C /opt/kernel
cd /opt/kernel/linux-5.2.3
#patch -p1 < /opt/PowerOS/patches/linux-3.18-log2.patch
#patch -p1 < /opt/PowerOS/patches/linux-3.18-hide-legacy-dirs.patch
#cp include/linux/compiler-gcc5.h include/linux/compiler-gcc8.h
cp /opt/PowerOS/config/config.kernel ./.config
cp /opt/wireless-regdb/db.txt ./net/wireless
make oldconfig
make prepare
make -j$(nproc)

make INSTALL_MOD_PATH="/tmp/modules" modules_install
rm -f /tmp/modules/lib/modules/*/{source,build}
mkdir -p /opt/sysroot/Programs/kernel-amd64/5.2.3/modules
cp -rv /tmp/modules/lib/modules/5.2.3/* /opt/sysroot/Programs/kernel-amd64/5.2.3/modules
ln -s 5.2.3 /opt/sysroot/Programs/kernel-amd64/current
ln -s /Programs/kernel-amd64/5.2.3/modules /opt/sysroot/System/Kernel/Modules/5.2.3
rm -rf /tmp/modules

mkdir -p /opt/sysroot/Programs/kernel-amd64/5.2.3/image
cp /opt/kernel/linux-5.2.3/arch/x86/boot/bzImage /opt/sysroot/Programs/kernel-amd64/5.2.3/image
ln -s /Programs/kernel-amd64/current/image /opt/sysroot/System/Kernel/Image

make headers_check
make INSTALL_HDR_PATH="/tmp/headers" headers_install
mkdir -p /opt/sysroot/Programs/kernel-amd64/5.2.3/headers
cp -rv /tmp/headers/include/* /opt/sysroot/Programs/kernel-amd64/5.2.3/headers
rm -fr /tmp/headers
find /opt/sysroot/Programs/kernel-amd64/5.2.3/headers \( -name .install -o -name ..install.cmd \) -delete

link_files /System/Index/Includes /Programs/kernel-amd64/5.2.3/headers

#BUSYBOX:
cd /opt
wget https://busybox.net/downloads/busybox-1.30.1.tar.bz2
tar xfv busybox-1.30.1.tar.bz2
cd busybox-1.30.1
cp /opt/PowerOS/config/config.busybox .config
make -j$(nproc)
make install
mkdir -p /opt/sysroot/Programs/busybox/1.30.1/bin
ln -s 1.30.1 /opt/sysroot/Programs/busybox/current
cp /tmp/busybox/bin/busybox /opt/sysroot/Programs/busybox/1.30.1/bin
find /tmp/busybox/bin/* -type l -execdir ln -s /Programs/busybox/1.30.1/bin/busybox /opt/sysroot/System/Index/Binaries/{} ';'
find /tmp/busybox/sbin/* -type l -execdir ln -s /Programs/busybox/1.30.1/bin/busybox /opt/sysroot/System/Index/Binaries/{} ';'
rm -fr /tmp/busybox

#GLIBC
cd /opt
wget https://mirrors.dotsrc.org/gnu/glibc/glibc-2.29.tar.xz
tar xfv glibc-2.29.tar.xz
cd glibc-2.29
mkdir build
cd build

../configure \
  CFLAGS="-O2 -s" \
  --prefix= \
  --includedir=/include \
  --libexecdir=/libexec \
  --with-__thread \
  --with-tls \
  --with-fp \
  --with-headers=/opt/sysroot/Programs/kernel-amd64/5.2.3/headers \
  --without-cvs \
  --without-gd \
  --enable-kernel=4.19.0 \
  --enable-stack-protector=strong \
  --enable-shared \
  --enable-add-ons=no \
  --enable-obsolete-rpc \
  --disable-profile \
  --disable-debug \
  --disable-sanity-checks \
  --disable-static \
  --disable-werror

make -j$(nproc)
make install DESTDIR=/opt/sysroot/Programs/glibc/2.29
rm -rf /opt/sysroot/Programs/glibc/2.29/{libexec,share,var}
ln -s 2.29 /opt/sysroot/Programs/glibc/current
cp /opt/sysroot/Programs/glibc/2.29/etc/* /opt/sysroot/System/Settings
rm -rf /opt/sysroot/Programs/glibc/2.29/etc

link_files /System/Index/Binaries /Programs/glibc/2.29/bin
link_files /System/Index/Includes /Programs/glibc/2.29/include
link_files /System/Index/Libraries /Programs/glibc/2.29/lib
link_files /System/Index/Binaries /Programs/glibc/2.29/sbin

#BINUTILS
cd /opt
wget https://mirrors.dotsrc.org/gnu/binutils/binutils-2.32.tar.xz
tar xfv binutils-2.32.tar.xz
cd binutils-2.32

./configure \
  CFLAGS="-O2 -s" \
  --prefix=/ \
  --with-sysroot=/ \
  --with-float=hard \
  --disable-werror \
  --disable-multilib \
  --disable-sim \
  --disable-gdb \
  --disable-nls \
  --disable-static \
  --enable-ld=default \
  --enable-gold=yes \
  --enable-threads \
  --enable-plugins
  
make tooldir=/ -j$(nproc)
make tooldir=/ install DESTDIR=/opt/sysroot/Programs/binutils/2.32
rm -rf /opt/sysroot/Programs/binutils/2.32/{share,lib/ldscripts}
ln -s 2.32 /opt/sysroot/Programs/binutils/current

link_files /System/Index/Binaries /Programs/binutils/2.32/bin
link_files /System/Index/Includes /Programs/binutils/2.32/include
link_files /System/Index/Libraries /Programs/binutils/2.32/lib

#GCC
cd /opt
wget http://ftp.tsukuba.wide.ad.jp/software/gcc/releases/gcc-8.3.0/gcc-8.3.0.tar.xz
tar xfv gcc-8.3.0.tar.xz
cd gcc-8.3.0
./contrib/download_prerequisites
mkdir build
cd build

../configure \
  CFLAGS="-O2 -s" \
  --with-sysroot=/ \
  --prefix=/ \
  --enable-threads=posix \
  --enable-languages=c,c++ \
  --enable-__cxa_atexit \
  --disable-libmudflap \
  --disable-bootstrap \
  --disable-libssp \
  --disable-libgomp \
  --disable-libstdcxx-pch \
  --disable-nls \
  --disable-multilib \
  --disable-libquadmath \
  --disable-libquadmath-support \
  --disable-libsanitizer \
  --disable-libmpx \
  --disable-gold \
  --enable-long-long \
  --disable-static

make -j$(nproc)
make install DESTDIR=/opt/sysroot/Programs/gcc/8.3.0
rm -rf /opt/sysroot/Programs/gcc/8.3.0/share
ln -s 8.3.0 /opt/sysroot/Programs/gcc/current
ln -s arm-linux-gnueabihf-gcc /opt/sysroot/Programs/gcc/8.3.0/bin/cc

link_files /System/Index/Binaries /Programs/gcc/8.3.0/bin
link_files /System/Index/Includes /Programs/gcc/8.3.0/include
link_files /System/Index/Libraries /Programs/gcc/8.3.0/lib
link_files /System/Index/Libraries/libexec /Programs/gcc/8.3.0/libexec

#bison
cd /opt
wget http://ftp.twaren.net/Unix/GNU/gnu/bison/bison-3.4.1.tar.xz
tar xfv bison-3.4.1.tar.xz
cd bison-3.4.1

./configure \
  --prefix=/ \
  --disable-yacc \
  --disable-nls

make -j1
make install DESTDIR=/opt/sysroot/Programs/bison/3.4.1
ln -s 3.4.1 /opt/sysroot/Programs/bison/current
rm -rf /opt/sysroot/Programs/bison/3.4.1/share/{bison,doc,info,man}

link_files /System/Index/Binaries /Programs/bison/3.4.1/bin
link_files /System/Index/Shared /Programs/bison/3.4.1/share

#flex
cd /opt
wget https://github.com/westes/flex/files/981163/flex-2.6.4.tar.gz
tar xfv flex-2.6.4.tar.gz
cd flex-2.6.4
sed -i "/math.h/a #include <malloc.h>" src/flexdef.h

./configure \
  --disable-static

make -j$(nproc)
make install DESTDIR=/opt/sysroot/Programs/flex/2.6.4
ln -s 2.6.4 /opt/sysroot/Programs/flex/current
rm -rf /opt/sysroot/Programs/flex/2.6.4/share

link_files /System/Index/Binaries /Programs/flex/2.6.4/bin
link_files /System/Index/Includes /Programs/flex/2.6.4/include
link_files /System/Index/Libraries /Programs/flex/2.6.4/lib

#make
cd /opt
wget http://ftp.twaren.net/Unix/GNU/gnu/make/make-4.2.1.tar.gz
tar xfv make-4.2.1.tar.gz
cd make-4.2.1
sed -i '211,217 d; 219,229 d; 232 d' glob/glob.c

./configure \
  --prefix=/

make -j$(nproc)
make install DESTDIR=/opt/sysroot/Programs/make/4.2.1
ln -s 4.2.1 /opt/sysroot/Programs/make/current
rm -rf /opt/sysroot/Programs/make/4.2.1/share

link_files /System/Index/Binaries /Programs/make/4.2.1/bin
link_files /System/Index/Includes /Programs/make/4.2.1/include

#m4
cd /opt
wget https://ftp.gnu.org/gnu/m4/m4-1.4.18.tar.xz
tar xfv m4-1.4.18.tar.xz
cd m4-1.4.18
sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c
echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h

./configure \
  --prefix=/

make -j$(nproc)
make install DESTDIR=/opt/sysroot/Programs/m4/1.4.18
ln -s 1.4.18 /opt/sysroot/Programs/m4/current
rm -rf /opt/sysroot/Programs/m4/1.4.18/share

link_files /System/Index/Binaries /Programs/m4/1.4.18/bin

#pkg-config
cd /opt
wget https://pkgconfig.freedesktop.org/releases/pkg-config-0.29.2.tar.gz
tar xfv pkg-config-0.29.2.tar.gz
cd pkg-config-0.29.2

./configure \
  --prefix=/ \
  --with-internal-glib \
  --disable-host-tool

make -j$(nproc)
make install DESTDIR=/opt/sysroot/Programs/pkg-config/0.29.2
ln -s 0.29.2 /opt/sysroot/Programs/pkg-config/current
rm -rf /opt/sysroot/Programs/pkg-config/0.29.2/share/{doc,man}

link_files /System/Index/Binaries /Programs/pkg-config/0.29.2/bin
link_files /System/Index/Shared /Programs/pkg-config/0.29.2/share

#libnl (netlink)
cd /opt
wget https://github.com/thom311/libnl/releases/download/libnl3_4_0/libnl-3.4.0.tar.gz
tar xfv libnl-3.4.0.tar.gz
cd libnl-3.4.0

./configure \
  --prefix= \
  --sysconfdir=/etc \
  --disable-static
  
make -j$(nproc)
make install DESTDIR=/opt/sysroot/Programs/libnl/3.4.0
ln -s 3.4.0 /opt/sysroot/Programs/libnl/current
rm -rf /opt/sysroot/Programs/libnl/3.4.0/share/man
mv /opt/sysroot/Programs/libnl/3.4.0/lib/pkgconfig /opt/sysroot/Programs/libnl/3.4.0/share
cp -rv /opt/sysroot/Programs/libnl/3.4.0/etc/* /opt/sysroot/System/Settings
rm -rf /opt/sysroot/Programs/libnl/3.4.0/etc

link_files /System/Index/Includes /Programs/libnl/3.4.0/include
link_files /System/Index/Libraries /Programs/libnl/3.4.0/lib
link_files /System/Index/Shared /Programs/libnl/3.4.0/share

#iw (tools for wifi)
cd /opt
wget https://www.kernel.org/pub/software/network/iw/iw-5.0.1.tar.xz
tar xfv iw-5.0.1.tar.xz
cd iw-5.0.1
CC="gcc --sysroot=/opt/sysroot/Programs/glibc/2.29" \
PKG_CONFIG_PATH=/opt/sysroot/Programs/libnl/3.4.0/share/pkgconfig \
CFLAGS="--sysroot=/opt/sysroot -O2 -s -I/opt/sysroot/Programs/glibc/2.29/include -I/opt/sysroot/Programs/kernel-amd64/5.2.3/headers -I/opt/sysroot/Programs/libnl/3.4.0/include/libnl3" \
LDFLAGS="-L/opt/sysroot/Programs/libnl/3.4.0/lib -lnl-3" \
make
PKG_CONFIG_PATH=/opt/sysroot/Programs/libnl/3.4.0/share/pkgconfig \
make DESTDIR=/opt/sysroot/Programs/iw/5.0.1 PREFIX=/ install
ln -s 5.0.1 /opt/sysroot/Programs/iw/current
rm -rf /opt/sysroot/Programs/iw/5.0.1/share

link_files /System/Index/Binaries /Programs/iw/5.0.1/sbin

#zlib
cd /opt
wget https://zlib.net/zlib-1.2.11.tar.gz
tar xfv zlib-1.2.11.tar.gz
cd zlib-1.2.11

./configure \
  --prefix=/ \
  --shared

make CC="gcc --sysroot=/opt/sysroot -I/opt/sysroot/Programs/glibc/2.29/include -I/opt/sysroot/Programs/kernel-amd64/5.2.3/headers" CFLAGS="-O2 -s" LDSHARED="gcc -shared -Wl,-soname,libz.so.1,--version-script,zlib.map"
make prefix=/ DESTDIR=/opt/sysroot/Programs/zlib/1.2.11 install
ln -s 1.2.11 /opt/sysroot/Programs/zlib/current
mv /opt/sysroot/Programs/zlib/1.2.11/lib/pkgconfig /opt/sysroot/Programs/zlib/1.2.11/share
rm -rf /opt/sysroot/Programs/zlib/1.2.11/share/man

link_files /System/Index/Includes /Programs/zlib/1.2.11/include
link_files /System/Index/Libraries /Programs/zlib/1.2.11/lib
link_files /System/Index/Shared /Programs/zlib/1.2.11/share

#openssl
cd /opt
wget https://www.openssl.org/source/openssl-1.1.1c.tar.gz
tar xfv openssl-1.1.1c.tar.gz
cd openssl-1.1.1c

./Configure \
  -DL_ENDIAN \
  shared \
  zlib-dynamic \
  --prefix=/ \
  --openssldir=/etc/ssl \
  --libdir=lib \
  linux-x86_64
  
make \
CC="gcc --sysroot=/opt/sysroot" \
CFLAGS="-O2 -s -I/opt/sysroot/Programs/zlib/1.2.11/include -I/opt/sysroot/Programs/glibc/2.29/include -I/opt/sysroot/Programs/kernel-amd64/5.2.3/headers"
make install DESTDIR=/opt/sysroot/Programs/openssl/1.1.1c
ln -s 1.1.1c /opt/sysroot/Programs/openssl/current
mv /opt/sysroot/Programs/openssl/1.1.1c/lib/pkgconfig /opt/sysroot/Programs/openssl/1.1.1c/share
rm -rf /opt/sysroot/Programs/openssl/1.1.1c/lib/{libcrypto.a,libssl.a}
rm -rf /opt/sysroot/Programs/openssl/1.1.1c/share/{doc,man}
cp -rv /opt/sysroot/Programs/openssl/1.1.1c/etc/* /opt/sysroot/System/Settings
rm -rf /opt/sysroot/Programs/openssl/1.1.1c/etc

link_files /System/Index/Binaries /Programs/openssl/1.1.1c/bin
link_files /System/Index/Includes /Programs/openssl/1.1.1c/include
link_files /System/Index/Libraries /Programs/openssl/1.1.1c/lib
link_files /System/Index/Shared /Programs/openssl/1.1.1c/shared

#ncurses
cd /opt
wget https://mirrors.dotsrc.org/gnu/ncurses/ncurses-6.1.tar.gz
tar xfv ncurses-6.1.tar.gz
cd ncurses-6.1

./configure \
  --prefix= \
  --with-shared \
  --without-debug \
  --disable-stripping \
  --without-manpages \
  --enable-static=no \
  --without-ada
  
make -j$(nproc)
make install DESTDIR=/opt/sysroot/Programs/ncurses/6.1
ln -s 6.1 /opt/sysroot/Programs/ncurses/current
unlink /opt/sysroot/Programs/ncurses/6.1/lib/terminfo
rm -rf /opt/sysroot/Programs/ncurses/6.1/lib/{libform.a,libmenu.a,libncurses++.a,libncurses.a,libpanel.a}

link_files /System/Index/Binaries /Programs/ncurses/6.1/bin
link_files /System/Index/Includes /Programs/ncurses/6.1/include
link_files /System/Index/Libraries /Programs/ncurses/6.1/lib
link_files /System/Index/Shared /Programs/ncurses/6.1/share

#wpa_supplicant
cd /opt
wget https://w1.fi/releases/wpa_supplicant-2.8.tar.gz
tar xfv wpa_supplicant-2.8.tar.gz
cd wpa_supplicant-2.8/wpa_supplicant
cp defconfig .config
sed -i '/CONFIG_CTRL_IFACE_DBUS_NEW=y/d' .config
sed -i '/CONFIG_CTRL_IFACE_DBUS_INTRO=y/d' .config
CC="gcc --sysroot=/opt/sysroot/Programs/glibc/2.29" \
PKG_CONFIG_PATH=/opt/sysroot/Programs/libnl/3.4.0/share/pkgconfig \
CFLAGS="--sysroot=/opt/sysroot -O2 -s -I/opt/sysroot/Programs/libnl/3.4.0/include/libnl3 -I/opt/sysroot/Programs/openssl/1.1.1c/include -I/opt/sysroot/Programs/glibc/2.29/include -I/opt/sysroot/Programs/kernel-amd64/5.2.3/headers" \
LDFLAGS="-L/opt/sysroot/Programs/libnl/3.4.0/lib -lnl-3 -L/opt/sysroot/Programs/openssl/1.1.1c/lib" \
make BINDIR=/sbin LIBDIR=/lib
mkdir -p /opt/sysroot/Programs/wpa_supplicant/2.8/sbin
ln -s 2.8 /opt/sysroot/Programs/wpa_supplicant/current
install -v -m755 wpa_{cli,passphrase,supplicant} /opt/sysroot/Programs/wpa_supplicant/2.8/sbin

link_files /System/Index/Binaries /Programs/wpa_supplicant/2.8/sbin

#gobohide (1.3)
cd /opt
wget https://github.com/gobolinux/GoboHide/releases/download/1.3/GoboHide-1.3.tar.gz
tar xfv GoboHide-1.3.tar.gz
cd GoboHide-1.3

./autogen.sh
./configure \
  PKG_CONFIG_PATH=/opt/sysroot/Programs/libnl/3.4.0/share/pkgconfig \
  CFLAGS="-O2 -s -I/opt/sysroot/Programs/libnl/3.4.0/include/libnl3" \
  LDFLAGS="-L/opt/sysroot/Programs/libnl/3.4.0/lib" \
  LIBS="-lnl-3" \
  --prefix=/
  
make -j$(nproc)
make install DESTDIR=/opt/sysroot/Programs/gobohide/1.3
ln -s 1.3 /opt/sysroot/Programs/gobohide/current
rm -rf /opt/sysroot/Programs/gobohide/1.3/{etc,share}

link_files /System/Index/Binaries /Programs/gobohide/1.3/bin

#grub2
cd /opt
wget https://ftp.gnu.org/gnu/grub/grub-2.04.tar.xz
tar xfv grub-2.04.tar.xz
cd grub-2.04

./configure \
  -target=x86_64 \
  --prefix= \
  --sbindir=/sbin \
  --sysconfdir=/etc \
  --disable-werror

make -j$(nproc)
make install DESTDIR=/opt/sysroot/Programs/grub/2.04
ln -s 2.04 /opt/sysroot/Programs/grub/current
rm -rf /opt/sysroot/Programs/grub/2.04/etc/bash_completion.d
rm -rf /opt/sysroot/Programs/grub/2.04/share/{info,locale,man}

link_files /System/Index/Binaries /Programs/grub/2.04/bin
link_files /System/Index/Libraries /Programs/grub/2.04/lib
link_files /System/Index/Binaries /Programs/grub/2.04/sbin
link_files /System/Index/Shared /Programs/grub/2.04/share

#STRIP ALL BINARIES TO SAVE SPACE
find /opt/sysroot/Programs/*/current/bin -executable -type f | xargs strip -s || true
find /opt/sysroot/Programs/*/current/sbin -executable -type f | xargs strip -s || true
find /opt/sysroot/Programs/*/current/libexec -executable -type f | xargs strip -s || true
