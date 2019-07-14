#!/bin/sh
set -e
set -x

#FUNCTIONS
link_files () {  
  find /opt/sysroot$2 -mindepth 1 -depth -type d -printf "%P\n" | while read dir; do mkdir -p "/opt/sysroot$1/$dir"; done
  find /opt/sysroot$2 -type f -printf "%P\n" | while read file; do ln -s "$2/$file" "/opt/sysroot$1/$file"; done
}

#FETCH NEEDED TOOLS
apt-get install -y gcc-8-aarch64-linux-gnu gcc-8-arm-linux-gnueabihf gawk bison wget patch build-essential u-boot-tools bc vboot-kernel-utils libncurses5-dev g++-arm-linux-gnueabihf flex texinfo unzip help2man libtool-bin python3 git nano kmod pkg-config

#CREATE DIR STRUCTURE
rm -fr /opt/sysroot/*
cp -rv /opt/PowerOS/sysroot/* /opt/sysroot

#GET WIFI RULES DATABASE
cd /opt
git clone git://git.kernel.org/pub/scm/linux/kernel/git/linville/wireless-regdb.git

#KERNEL
cd /opt
ln -s /usr/bin/aarch64-linux-gnu-gcc-8 /usr/bin/aarch64-linux-gnu-gcc
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export WIFIVERSION=
if [ ! -d "/opt/kernel" ]; then
  wget -O /opt/kernel.tar.gz https://chromium.googlesource.com/chromiumos/third_party/kernel/+archive/86596f58eadf.tar.gz
  mkdir /opt/kernel
  tar xfv /opt/kernel.tar.gz -C /opt/kernel
fi
cd /opt/kernel
patch -p1 < /opt/PowerOS/patches/linux-3.18-log2.patch
patch -p1 < /opt/PowerOS/patches/linux-3.18-hide-legacy-dirs.patch
cp include/linux/compiler-gcc5.h include/linux/compiler-gcc8.h
cat /opt/PowerOS/config/config.chromeos /opt/PowerOS/config/config.chromeos.extra > .config
cp /opt/wireless-regdb/db.txt /opt/kernel/net/wireless
make oldconfig
make prepare
make CFLAGS="-O2 -s" -j$(nproc) Image
make CFLAGS="-O2 -s" -j$(nproc) modules
make dtbs
make CFLAGS="-O2 -s" -j$(nproc)

make INSTALL_MOD_PATH="/tmp/modules" modules_install
rm -f /tmp/modules/lib/modules/*/{source,build}
mkdir -p /opt/sysroot/Programs/kernel-aarch64/3.18.0-19095-g86596f58eadf/modules
cp -rv /tmp/modules/lib/modules/3.18.0-19095-g86596f58eadf/* /opt/sysroot/Programs/kernel-aarch64/3.18.0-19095-g86596f58eadf/modules
ln -s 3.18.0-19095-g86596f58eadf /opt/sysroot/Programs/kernel-aarch64/current
ln -s /Programs/kernel-aarch64/3.18.0-19095-g86596f58eadf/modules /opt/sysroot/System/Kernel/Modules/3.18.0-19095-g86596f58eadf
rm -rf /tmp/modules
#depmod -b /opt/sysroot/System/Kernel/Modules -F System.map "3.18.0-19095-g86596f58eadf"

make INSTALL_DTBS_PATH="/opt/sysroot/Programs/kernel-aarch64/3.18.0-19095-g86596f58eadf/dtbs" dtbs_install

cp /opt/PowerOS/signing/kernel.its .
mkimage -D "-I dts -O dtb -p 2048" -f kernel.its vmlinux.uimg
dd if=/dev/zero of=bootloader.bin bs=512 count=1
echo "console=tty1 init=/sbin/init root=PARTUUID=%U/PARTNROFF=1 rootwait rw noinitrd" > cmdline
vbutil_kernel --pack vmlinux.kpart --version 1 --vmlinuz vmlinux.uimg --arch aarch64 --keyblock /opt/PowerOS/signing/kernel.keyblock --signprivate /opt/PowerOS/signing/kernel_data_key.vbprivk --config cmdline --bootloader bootloader.bin
mkdir -p /opt/sysroot/Programs/kernel-aarch64/3.18.0-19095-g86596f58eadf/image
cp vmlinux.kpart /opt/sysroot/Programs/kernel-aarch64/3.18.0-19095-g86596f58eadf/image

make mrproper
make ARCH=arm headers_check
make ARCH=arm INSTALL_HDR_PATH="/tmp/headers" headers_install
mkdir -p /opt/sysroot/Programs/kernel-aarch64/3.18.0-19095-g86596f58eadf/headers
cp -rv /tmp/headers/include/* /opt/sysroot/Programs/kernel-aarch64/3.18.0-19095-g86596f58eadf/headers
rm -fr /tmp/headers
#link headers to include dir??
find /opt/sysroot/Programs/kernel-aarch64/3.18.0-19095-g86596f58eadf/headers \( -name .install -o -name ..install.cmd \) -delete

#BUSYBOX:
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-
cd /opt
wget https://busybox.net/downloads/busybox-1.30.1.tar.bz2
tar xfv busybox-1.30.1.tar.bz2
cd busybox-1.30.1
cp /opt/PowerOS/config/config.busybox .config
make CFLAGS="-O2 -s" -j$(nproc)
make install
mkdir -p /opt/sysroot/Programs/busybox/1.30.1/bin
ln -s 1.30.1 /opt/sysroot/Programs/busybox/current
cp /tmp/busybox/bin/busybox /opt/sysroot/Programs/busybox/1.30.1/bin
find /tmp/busybox/bin/* -type l -execdir ln -s /Programs/busybox/1.30.1/bin/busybox /opt/sysroot/System/Index/Binaries/{} ';'
find /tmp/busybox/sbin/* -type l -execdir ln -s /Programs/busybox/1.30.1/bin/busybox /opt/sysroot/System/Index/Binaries/{} ';'
rm -fr /tmp/busybox
#mkdir -p /opt/sysroot/Programs/busybox/1.30.1/etc
#ln -s /Programs/busybox/1.30.1/etc /opt/sysroot/System/Settings/busybox

#GLIBC
cd /opt
wget https://ftp.gnu.org/gnu/glibc/glibc-2.29.tar.xz
tar xfv glibc-2.29.tar.xz
cd glibc-2.29
mkdir build
cd build

../configure \
  CFLAGS="-O2 -s" \
  --host=arm-linux-gnueabihf \
  --prefix= \
  --includedir=/include \
  --libexecdir=/libexec \
  --with-__thread \
  --with-tls \
  --with-fp \
  --with-headers=/opt/sysroot/Programs/kernel-aarch64/3.18.0-19095-g86596f58eadf/headers \
  --without-cvs \
  --without-gd \
  --enable-kernel=3.18.0 \
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

link_files /System/Index/Binaries /Programs/glibc/2.29/bin
link_files /System/Settings /Programs/glibc/2.29/etc
link_files /System/Index/Includes /Programs/glibc/2.29/include
link_files /System/Index/Libraries /Programs/glibc/2.29/lib
link_files /System/Index/Binaries /Programs/glibc/2.29/sbin

#BINUTILS
cd /opt
wget https://ftp.yzu.edu.tw/gnu/binutils/binutils-2.32.tar.xz
tar xfv binutils-2.32.tar.xz
cd binutils-2.32

./configure \
  CFLAGS="-O2 -s" \
  --host=arm-linux-gnueabihf \
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
  --host=arm-linux-gnueabihf \
  --target=arm-linux-gnueabihf \
  --with-sysroot=/ \
  --with-float=hard \
  --prefix=/ \
  --enable-threads=posix \
  --enable-languages=c,c++ \
  --enable-__cxa_atexit \
  --disable-libmudflap \
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
  CFLAGS="-O2 -s --sysroot=/opt/sysroot" \
  --host=arm-linux-gnueabihf \
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
  CFLAGS="-O2 -s --sysroot=/opt/sysroot" \
  --host=arm-linux-gnueabihf \
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
  CFLAGS="-O2 -s --sysroot=/opt/sysroot" \
  --prefix=/ \
  --host=arm-linux-gnueabihf

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
  CFLAGS="-O2 -s --sysroot=/opt/sysroot" \
  --host=arm-linux-gnueabihf \
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
  CFLAGS="-O2 -s --sysroot=/opt/sysroot" \
  --host=arm-linux-gnueabihf \
  --prefix=/ \
  --with-internal-glib \
  --disable-host-tool \
  glib_cv_stack_grows=yes \
  glib_cv_uscore=no \
  ac_cv_func_posix_getpwuid_r=yes \
  ac_cv_func_posix_getgrgid_r=yes

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
  CFLAGS="-O2 -s --sysroot=/opt/sysroot" \
  --host=arm-linux-gnueabihf \
  --prefix=/ \
  --sysconfdir=/etc \
  --disable-cli \
  --disable-static
  
make -j$(nproc)
make install DESTDIR=/opt/sysroot/Programs/libnl/3.4.0
ln -s 3.4.0 /opt/sysroot/Programs/libnl/current
rm -rf /opt/sysroot/Programs/libnl/3.4.0/share/man
mv /opt/sysroot/Programs/libnl/3.4.0/lib/pkgconfig /opt/sysroot/Programs/libnl/3.4.0/share

link_files /System/Settings /Programs/libnl/3.4.0/etc
link_files /System/Index/Includes /Programs/libnl/3.4.0/include
link_files /System/Index/Libraries /Programs/libnl/3.4.0/lib
link_files /System/Index/Shared /Programs/libnl/3.4.0/share

#iw (tools for wifi)
cd /opt
wget https://www.kernel.org/pub/software/network/iw/iw-5.0.1.tar.xz
tar xfv iw-5.0.1.tar.xz
cd iw-5.0.1
CC="arm-linux-gnueabihf-gcc --sysroot=/opt/sysroot/Programs/glibc/2.29" \
PKG_CONFIG_PATH=/opt/sysroot/Programs/libnl/3.4.0/share/pkgconfig \
CFLAGS="--sysroot=/opt/sysroot -O2 -s -I/opt/sysroot/Programs/libnl/3.4.0/include/libnl3" \
LDFLAGS="-L/opt/sysroot/Programs/libnl/3.4.0/lib -lnl-3" \
make
PKG_CONFIG_PATH=/opt/sysroot/Programs/libnl/3.4.0/share/pkgconfig \
make DESTDIR=/opt/sysroot/Programs/iw/5.0.1 PREFIX=/ install
ln -s 5.0.1 /opt/sysroot/Programs/wi/current
rm -rf /opt/sysroot/Programs/iw/5.0.1/share

link_files /System/Index/Binaries /Programs/iw/5.0.1/sbin

#zlib
cd /opt
wget https://zlib.net/zlib-1.2.11.tar.gz
tar xfv zlib-1.2.11.tar.gz
cd zlib-1.2.11

./configure \
  --prefix=/ \
  --enable-static=no \
  --shared

make CC="arm-linux-gnueabihf-gcc --sysroot=/opt/sysroot" CFLAGS="-O2 -s" LDSHARED="arm-linux-gnueabihf-gcc -shared -Wl,-soname,libz.so.1,--version-script,zlib.map"
make prefix=/ DESTDIR=/opt/sysroot/Programs/zlib/1.2.11 install
ln -s 1.2.11 /opt/sysroot/Programs/zlib/current
mv /opt/sysroot/Programs/zlib/1.2.11/lib/pkgconfig /opt/sysroot/Programs/zlib/1.2.11/share
rm -rf //opt/sysroot/Programs/zlib/1.2.11/share/man

link_files /System/Index/Includes /Programs/zlib/1.2.11/include
link_files /System/Index/Libraries /Programs/zlib/1.2.11/lib
link_files /System/Index/Shared /Programs/zlib/1.2.11/share


