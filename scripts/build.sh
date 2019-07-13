#!/bin/sh
set -e
set -x

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
mkdir -p /opt/sysroot/Programs/linux-kernel/3.18.0-19095-g86596f58eadf/modules
cp -rv /tmp/modules/lib/modules/3.18.0-19095-g86596f58eadf/* /opt/sysroot/Programs/linux-kernel/3.18.0-19095-g86596f58eadf/modules
ln -s 3.18.0-19095-g86596f58eadf /opt/sysroot/Programs/linux-kernel/current
rm -rf /tmp/modules
#depmod -b /opt/sysroot/System/Kernel/Modules -F System.map "3.18.0-19095-g86596f58eadf"

make INSTALL_DTBS_PATH="/opt/sysroot/Programs/linux-kernel/3.18.0-19095-g86596f58eadf/dtbs" dtbs_install

cp /opt/PowerOS/signing/kernel.its .
mkimage -D "-I dts -O dtb -p 2048" -f kernel.its vmlinux.uimg
dd if=/dev/zero of=bootloader.bin bs=512 count=1
echo "console=tty1 init=/sbin/init root=PARTUUID=%U/PARTNROFF=1 rootwait rw noinitrd" > cmdline
vbutil_kernel --pack vmlinux.kpart --version 1 --vmlinuz vmlinux.uimg --arch aarch64 --keyblock /opt/PowerOS/signing/kernel.keyblock --signprivate /opt/PowerOS/signing/kernel_data_key.vbprivk --config cmdline --bootloader bootloader.bin
mkdir -p /opt/sysroot/Programs/linux-kernel/3.18.0-19095-g86596f58eadf/image
cp vmlinux.kpart /opt/sysroot/Programs/linux-kernel/3.18.0-19095-g86596f58eadf/image

make mrproper
make ARCH=arm headers_check
make ARCH=arm INSTALL_HDR_PATH="/tmp/headers" headers_install
mkdir -p /opt/sysroot/Programs/linux-kernel/3.18.0-19095-g86596f58eadf/headers
cp -rv /tmp/headers/include/* /opt/sysroot/Programs/linux-kernel/3.18.0-19095-g86596f58eadf/headers
rm -fr /tmp/headers
#link headers to include dir??
find /opt/sysroot/Programs/linux-kernel/3.18.0-19095-g86596f58eadf/headers \( -name .install -o -name ..install.cmd \) -delete

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
find /tmp/busybox/bin/* -type l -execdir ln -s /Programs/busybox/1.30.1/bin/busybox /opt/sysroot/System/Index/bin/{} ';'
find /tmp/busybox/sbin/* -type l -execdir ln -s /Programs/busybox/1.30.1/bin/busybox /opt/sysroot/System/Index/bin/{} ';'
rm -fr /tmp/busybox
mkdir -p /opt/sysroot/Programs/busybox/1.30.1/etc
ln -s /Programs/busybox/1.30.1/etc /opt/sysroot/System/Settings/busybox
