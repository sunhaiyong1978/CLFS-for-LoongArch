# <center>Teach you how to build a Linux system based on LoongArch64 architecture</center>

<center>(CLFS For LoongArch64)</center>  

<center>Author: Sun Haiyong</center>
<center>Translator: Andrii Kurdiumov</center>


## 0 Preface
    Loongson Zhongke launched a new instruction set architecture LoongArch in 2021, of which the 64-bit instruction set is called LoongArch64.  
    The goal of this article is to make a basic Linux system for LoongArch64. As a new instruction set architecture to make a Linux system, we can assume that there is no runnable system on the architecture platform as the premise, and use cross-compilation to make a Linux system. A basic Linux system.


## 1 About the porting of software packages
    For the target system made in this article is a Linux system based on the LoongArch64 architecture, the instruction set used for the LoongArch64 architecture is relatively new at the time of publication of this article. Many basic software packages of Linux systems do not include support for this instruction set. In order to solve the problem of supporting the new architecture, different processing methods can be adopted according to different situations of the software package.

* Expanded porting software package  
    This type of software package usually deals with specific instruction set architecture details in the Linux system, such as: Linux kernel, GCC, Binutls, Glibc, LLVM, etc., and these software packages usually require a large amount of code to be added to support new instructions Set architecture.  
    For this type of software package, if you want to use the best means to support the new instruction set architecture, then of course you must submit it to the latest official version and get long-term support, but it takes a process to achieve such a result. In the process, the method of "patching" can be adopted. But because these software packages usually need to modify and add a large amount of code, this makes the patch file usually specific to a specific version. When the version is upgraded, the patch cannot be used directly, so the source code of the corresponding version should be used to use the patch.  
    Another "not so good" way is to add the complete source code of the new architecture to download as a whole, that is, the patch is already in the source code, so that you can use it as long as you download the modified package source code.

* Easy porting software package  
    The code of this type of software package basically does not involve assembly or non-assembly implementation (assembly is usually used as a means to optimize performance). This type of software package usually has multiple instruction set architectures and similar work behaviors, which can work in a certain category. Adding the judgment of the new instruction set architecture to the behavior or through less changes can realize the transplantation of the new instruction set architecture, such as: Systemd, Automake, etc., so the patch for this kind of software package has a higher version universality. A patch may be suitable for multiple versions. Before this type of software package officially supports the new instruction set architecture, the "patch" method is more suitable for the porting of this type of software package.

* No need to migrate software packages  
    Most of these software packages are written in non-assembled development languages and have strong versatility. They can usually be compiled or used directly after the compiler or operating environment they rely on is transplanted. For example, Coreutils, Findutils, etc.  
    This type of software package may also need to support the new architecture during the configuration phase. The main reason is that the config.sub and config.guess that come with the software package do not have matching architecture settings when checking the target system. This type of problem is easier to solve. You need to overwrite the files in the software package with config.sub and config.guess in the Automake software package with the new architecture.

    In addition to the above-mentioned software packages that are portable on the new architecture platform, there are also some software packages that are written for a specific instruction set architecture. If it is a non-core function software package, you can temporarily ignore it. If there is a corresponding function portable software Packages can also be used to replace these platform-specific packages.
    

## 2 Preparation
    Before starting production, do some preparatory work, including system preparation, production environment setting and downloading of the source code of the software package.

### 2.1 System preparation
    First, prepare a machine that can install a general-purpose Linux system. The system to be used for cross-compiling the target platform is called the "main system". The "main system" can be a system on an X86 machine or a machine with other architectures. System, in order to facilitate the explanation, this article uses the Linux system on the X86 architecture to make the explanation.

    Choosing a suitable Linux still has a certain effect on whether the production can be successfully completed. Here you can use common distributions, such as Fedora, Debian, CentOS, etc., or you can use specialized systems, such as LFS LiveCD, etc. Next, we will use The Fedora system is explained as the "main system" for cross-compilation.

    In order to minimize the problems caused by additional factors during the production system explanation process, we produced in a "rebuilt" Fedora system, and used the following commands to build in a system that supports the dnf command tool:

```sh
export DISTRO_URL=https://mirrors.bfsu.edu.cn/fedora/releases/34/Everything/x86_64/os/
sudo dnf install @core @c-development rpm-build git python3-devel texinfo \
                 zlib-devel xz-lzma-compat gettext-devel perl-FindBin \
                 gdbm-devel expat-devel gobject-introspection-devel \
                 libgusb-devel libusb-devel libudev-devel libgudev-devel \
                 perl-Pod-Html rpm-devel tcl ncurses-devel openssl-devel libxslt bc \
                 wget docbook-style-xsl meson ninja-build python3-jinja2 gperf rsync \
                 xcursorgen mkfontscale wayland-devel itstool xmlto doxygen lynx \
                 --installroot ${HOME}/la-clfs --disablerepo="*" \
                 --repofrompath base,${DISTRO_URL} \
                 --releasever 34 --nogpgcheck
```
    The above steps will create a "la-clfs" directory in the current user's directory. A basic build environment will be installed in this directory. The Fedora 34 system is installed here. Readers can also install other systems as the build environment.
    The build process will be carried out in this directory.

    Copy the domain name resolution configuration file of the current system to the newly created system so that the system can access network resources.

```sh
cp -a /etc/resolv.conf ${HOME}/la-clfs/etc/
```

    Next switch to this directory:

```sh
sudo chroot ${HOME}/la-clfs
```

    Mount the necessary file system:

```sh
mount -t proc proc proc
mount -t sysfs sys sys
mount -t devtmpfs dev dev 
mount -t devpts devpts dev/pts 
mount -t tmpfs shm dev/shm
```

### 2.2 Production environment settings

#### Create the necessary directories
    Use the following commands to create several directories, and the subsequent build will be carried out in these directories.

```sh
export SYSDIR=/opt/mylaos
mkdir -pv ${SYSDIR}
mkdir -pv ${SYSDIR}/downloads
mkdir -pv ${SYSDIR}/build
install -dv ${SYSDIR}/cross-tools
install -dv ${SYSDIR}/sysroot
```

    Briefly explain the usage for these directories:

* By setting the "SYSDIR" variable to facilitate the use of the "base directory", this variable sets a specific directory as the "base directory", and the work related to this build is carried out in this directory.

* The "downloads" directory is used to store source code packages and patch files of various software;

* The "build" directory is used to compile various software packages;

* The "cross-tools" directory is used to store cross compilation tool chains and related software;

* "Sysroot" is used to store the target platform system.

#### Create build user

    In order to prevent accidental damage to the system itself during the building process, an ordinary user account is created. Unless special permissions are required during the subsequent build process, all operations on the target system are performed by this user.

```sh
groupadd lauser
useradd -s /bin/bash -g lauser -m -k /dev/null lauser
```
    Set the directory to belong to the newly created user:

```sh
chown -Rv lauser ${SYSDIR}
chmod -v a+wt ${SYSDIR}/{sysroot,cross-tools,downloads,build}
```


##### Switch to production user

    Use the command to switch to the newly created user:  

```sh
su - lauser
```

    Adding the "-" parameter when using the "su" command to switch can prevent the user environment variables before the switch from being brought to the new user environment.

##### Set the build user environment

    Set the most streamlined and necessary environment variables for the production users to help the subsequent build. The following is the long-term setting of the user's environment variables.

```sh
cat> ~/.bash_profile << "EOF"
exec env -i HOME=${HOME} TERM=${TERM} PS1='\u:\w\$ '/bin/bash
EOF
```

```sh
cat> ~/.bashrc << "EOF"
set +h
umask 022
export SYSDIR="/opt/mylaos"
export BUILDDIR="${SYSDIR}/build"
export DOWNLOADDIR="${SYSDIR}/downloads"
export LC_ALL=POSIX
export CROSS_HOST="$(echo $MACHTYPE | sed "s/$(echo $MACHTYPE | cut -d- -f2)/cross/")"
export CROSS_TARGET="loongarch64-unknown-linux-gnu"
export MABI="lp64"
export BUILD64="-mabi=lp64"
export PATH=${SYSDIR}/cross-tools/bin:/bin:/usr/bin
unset CFLAGS
unset CXXFLAGS
EOF
```

    Several environment variables are set here, and the meaning of these variables is briefly introduced below:

* SYSDIR: It is convenient to refer to the "base directory", and the "base directory" used can be changed by modifying the path set by this variable.
* BUILDIR: The directory specified by this variable is used for the software package compilation process.
* DOWNLOADDIR: The directory specified by this variable stores the software packages and some necessary patch files needed in the process of making the system.
* CROSS_HOST: Set the architecture system descriptor used by the "main system"
* CROSS_TARGET: Set the architecture system descriptor used by the "target system".
* MABI: Specify the ABI name used by default in the "Target System".
* BUILD64: Set the ABI parameters used when compiling the software package in the "target system" as a 64-bit ABI.

    After setting the user environment configuration file, use the source command to make the environment settings effective, use the command:

```sh
source ~/.bash_profile
```



#### Create the directory structure of the target system

    The target system we want to make is a regular Linux/GNU system. We create the target system's directory according to the directory structure used by the regular Linux/GNU system. The command is as follows:

```sh
pushd ${SYSDIR}/sysroot
	mkdir -pv ./{boot,home,root,mnt,opt,srv,run}
	mkdir -pv ./etc/{opt,sysconfig}
	mkdir -pv ./media/{floppy,cdrom}
	mkdir -pv ./usr/{,local/}{include,src}
	mkdir -pv ./usr/local/{bin,lib,sbin}
	mkdir -pv ./usr/{,local/}share/{color,dict,doc,info,locale,man}
	mkdir -pv ./usr/{,local/}share/{misc,terminfo,zoneinfo}
	mkdir -pv ./usr/{,local/}share/man/man{1..8}
	mkdir -pv ./var/{cache,local,log,mail,opt,spool}
	mkdir -pv ./var/lib/{color,misc,locate}
	mkdir -pv ./usr/{lib{,64},bin,sbin}
	ln -sfv usr/{lib{,64},bin,sbin} ./
	mkdir -pv ./lib/firmware
	mkdir -pv ./{dev,proc,sys}
	ln -sfv ../run ./var/run
	ln -sfv ../run/lock ./var/lock
	install -dv -m 1777 ./tmp ./var/tmp
	ln -sfv. ./boot/boot
popd
```
    The target system will be stored in the ${SYSDIR}/sysroot directory, so create directories and link files based on this directory.

### 2.3 Download package

    In order to use the latest software package to build the target system, it may be necessary to download the software package source code and patch files from the Internet. The downloaded files are recommended to be stored in the "downloads" directory.

```sh
pushd ${SYSDIR}/downloads
```

    Then you can use the wget tool to download the corresponding version of the software package. For example, to download the coreutils-8.32 software package, you can use the command:

```sh
	wget https://ftp.gnu.org/gnu/coreutils/coreutils-8.32.tar.xz
```

    After downloading, the software package is stored in the "downloads" directory.

    The following is the address of the source code of the software package used in this production:

    **Acl:** https://download.savannah.gnu.org/releases/acl/acl-2.3.1.tar.xz  
    **Attr:** https://download.savannah.gnu.org/releases/attr/attr-2.5.1.tar.gz  
    **Autoconf:** https://ftp.gnu.org/gnu/autoconf/autoconf-2.71.tar.xz  
    **Automake:** https://ftp.gnu.org/gnu/automake/automake-1.16.3.tar.xz  
    **Bash:** https://ftp.gnu.org/gnu/bash/bash-5.1.8.tar.gz  
    **BC:** https://github.com/gavinhoward/bc/releases/download/4.0.2/bc-4.0.2.tar.xz  
    **Binutils:** ```https://github.com/loongarch/binutils-gdb.git branch name "loongarch/upstream_v6_a1d65b3"```  
    **Bison:** https://ftp.gnu.org/gnu/bison/bison-3.7.6.tar.xz  
    **Boost:** https://boostorg.jfrog.io/artifactory/main/release/1.77.0/source/boost_1_77_0.tar.bz2  
    **Bzip2:** https://www.sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz  
    **Coreutils:** https://ftp.gnu.org/gnu/coreutils/coreutils-8.32.tar.xz  
    **CMake:** https://cmake.org/files/v3.21/cmake-3.21.1.tar.gz  
    **Ctags:** http://prdownloads.sourceforge.net/ctags/ctags-5.8.tar.gz  
    **CURL:** https://curl.se/download/curl-7.78.0.tar.xz  
    **D-Bus**: https://dbus.freedesktop.org/releases/dbus/dbus-1.12.20.tar.gz  
    **DHCPCD**: https://roy.marples.name/downloads/dhcpcd/dhcpcd-9.4.0.tar.xz  
    **Diffutils:** https://ftp.gnu.org/gnu/diffutils/diffutils-3.8.tar.xz  
    **Dosfstools:** https://github.com/dosfstools/dosfstools/releases/download/v4.2/dosfstools-4.2.tar.gz  
    **Doxygen:** https://www.doxygen.nl/files/doxygen-1.9.2.src.tar.gz  
    **E2fsprogs:** https://downloads.sourceforge.net/project/e2fsprogs/e2fsprogs/v1.46.2/e2fsprogs-1.46.2.tar.gz  
    **Ethtool:** https://mirrors.edge.kernel.org/pub/software/network/ethtool/ethtool-5.13.tar.xz  
    **Expat:** https://prdownloads.sourceforge.net/expat/expat-2.4.1.tar.xz  
    **File:** https://astron.com/pub/file/file-5.40.tar.gz  
    **Findutils:** https://ftp.gnu.org/gnu/findutils/findutils-4.8.0.tar.xz  
    **Flex:** https://github.com/westes/flex/releases/download/v2.6.4/flex-2.6.4.tar.gz  
    **Fontconfig:** https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.13.1.tar.bz2  
    **Freetype:** https://downloads.sourceforge.net/freetype/freetype-2.11.0.tar.xz  
    **Fribidi:** https://github.com/fribidi/fribidi/releases/download/v1.0.10/fribidi-1.0.10.tar.xz  
    **Gawk:** https://ftp.gnu.org/gnu/gawk/gawk-5.1.0.tar.xz  
    **GCC:** ```https://github.com/loongarch/gcc.git branch name "loongarch_upstream"```  
    **GDBM:** https://ftp.gnu.org/gnu/gdbm/gdbm-1.19.tar.gz  
    **Gettext:** https://ftp.gnu.org/gnu/gettext/gettext-0.21.tar.xz  
    **Git:** https://www.kernel.org/pub/software/scm/git/git-2.33.0.tar.xz  
    **Glib:** https://download.gnome.org/sources/glib/2.69/glib-2.69.2.tar.xz  
    **Glibc:** ```https://github.com/loongarch/glibc.git branch name "loongarch_2_34_for_upstream"```  
    **Glibmm:** https://download.gnome.org/sources/glibmm/2.68/glibmm-2.68.1.tar.xz  
    **GMP:** https://ftp.gnu.org/gnu/gmp/gmp-6.2.1.tar.xz  
    **GnuTLS:** https://www.gnupg.org/ftp/gcrypt/gnutls/v3.7/gnutls-3.7.2.tar.xz  
    **Gobject-Introspection:** https://download.gnome.org/sources/gobject-introspection/1.68/gobject-introspection-1.68.0.tar.xz  
    **GPerf:** https://ftp.gnu.org/gnu/gperf/gperf-3.1.tar.gz  
    **GPM:** https://www.nico.schottelius.org/software/gpm/archives/gpm-1.20.7.tar.bz2  
    **Grep:** https://ftp.gnu.org/gnu/grep/grep-3.7.tar.xz  
    **Groff:** https://ftp.gnu.org/gnu/groff/groff-1.22.4.tar.gz  
    **Grub2:** ```https://github.com/loongarch64/grub branch name "dev-la64"```  
    **Gzip:** https://ftp.gnu.org/gnu/gzip/gzip-1.10.tar.xz  
    **Harfbuzz:** https://github.com/harfbuzz/harfbuzz/releases/download/2.8.2/harfbuzz-2.8.2.tar.xz  
    **Iana-Etc:** https://github.com/Mic92/iana-etc/releases/download/20210526/iana-etc-20210526.tar.gz  
    **ICU4C:** https://github.com/unicode-org/icu/releases/download/release-69-1/icu4c-69_1-src.tgz  
    **Inetutils:** https://ftp.gnu.org/gnu/inetutils/inetutils-2.1.tar.xz  
    **Inih:** https://github.com/benhoyt/inih/archive/r53/inih-r53.tar.gz  
    **IPRoute2:** https://www.kernel.org/pub/linux/utils/net/iproute2/iproute2-5.12.0.tar.xz  
    **Jasper:** https://github.com/jasper-software/jasper/releases/download/version-2.0.33/jasper-2.0.33.tar.gz  
    **KBD:** https://www.kernel.org/pub/linux/utils/kbd/kbd-2.4.0.tar.xz  
    **Kmod:** https://www.kernel.org/pub/linux/utils/kernel/kmod/kmod-29.tar.xz  
    **Less:** https://www.greenwoodsoftware.com/less/less-581.tar.gz  
    **Lcms:** https://downloads.sourceforge.net/lcms/lcms2-2.12.tar.gz  
    **Libaio:** https://ftp.debian.org/debian/pool/main/liba/libaio/libaio_0.3.112.orig.tar.xz  
    **Libcap:** https://www.kernel.org/pub/linux/libs/security/linux-privs/libcap2/libcap-2.54.tar.xz  
    **Libelf:** https://sourceware.org/ftp/elfutils/0.185/elfutils-0.185.tar.bz2  
    **Libevent:** https://github.com/libevent/libevent/releases/download/release-2.1.12-stable/libevent-2.1.12-stable.tar.gz  
    **Libffi:** https://sourceware.org/pub/libffi/libffi-3.3.tar.gz  
    **Libgudev:** https://download.gnome.org/sources/libgudev/237/libgudev-237.tar.xz  
    **Libgusb:** https://github.com/hughsie/libgusb/archive/0.3.7/libgusb-0.3.7.tar.gz  
    **Libjpeg-Turbo:** https://downloads.sourceforge.net/libjpeg-turbo/libjpeg-turbo-2.1.1.tar.gz  
    **Libmng:** https://downloads.sourceforge.net/libmng/libmng-2.0.3.tar.xz  
    **Libmnl:** https://netfilter.org/projects/libmnl/files/libmnl-1.0.4.tar.bz2  
    **Libnl:** https://github.com/thom311/libnl/releases/download/libnl3_5_0/libnl-3.5.0.tar.gz  
    **Libpipeline:** https://download.savannah.gnu.org/releases/libpipeline/libpipeline-1.5.3.tar.gz  
    **Libpng:** https://downloads.sourceforge.net/libpng/libpng-1.6.37.tar.xz  
    **LibRaw:** https://www.libraw.org/data/LibRaw-0.20.2.tar.gz  
    **Libsigc++:** https://download.gnome.org/sources/libsigc++/3.0/libsigc++-3.0.7.tar.xz  
    **Libtasn1:** https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.17.0.tar.gz  
    **Libtool:** https://ftp.gnu.org/gnu/libtool/libtool-2.4.6.tar.xz  
    **Libusb:** https://github.com/libusb/libusb/releases/download/v1.0.24/libusb-1.0.24.tar.bz2  
    **Libunistring:** https://ftp.gnu.org/gnu/libunistring/libunistring-0.9.10.tar.xz  
    **Libxml2:** http://xmlsoft.org/sources/libxml2-2.9.12.tar.gz  
    **Libxslt:** http://xmlsoft.org/sources/libxslt-1.1.34.tar.gz  
    **Links:** http://links.twibright.com/download/links-2.23.tar.bz2  
    **Linux:** ```https://github.com/loongson/linux.git branch name "loongarch-next"```  
    **Linux-Firmware:** https://mirrors.edge.kernel.org/pub/linux/kernel/firmware/linux-firmware-20210818.tar.xz  
    **LVM2:** https://sourceware.org/ftp/lvm2/LVM2.2.03.13.tgz  
    **M4:** https://ftp.gnu.org/gnu/m4/m4-1.4.19.tar.xz  
    **Make:** https://ftp.gnu.org/gnu/make/make-4.3.tar.gz  
    **Man-DB:** https://download.savannah.gnu.org/releases/man-db/man-db-2.9.4.tar.xz  
    **Man-Pages:** https://www.kernel.org/pub/linux/docs/man-pages/man-pages-5.11.tar.xz  
    **Mdadm:** https://www.kernel.org/pub/linux/utils/raid/mdadm/mdadm-4.1.tar.xz  
    **Meson:** https://github.com/mesonbuild/meson/releases/download/0.59.1/meson-0.59.1.tar.gz  
    **MPC:** https://ftp.gnu.org/gnu/mpc/mpc-1.2.1.tar.gz  
    **MPFR:** https://www.mpfr.org/mpfr-4.1.0/mpfr-4.1.0.tar.xz  
    **Ncurses:** https://ftp.gnu.org/gnu/ncurses/ncurses-6.2.tar.gz  
    **Nettle:** https://ftp.gnu.org/gnu/nettle/nettle-3.7.3.tar.gz  
    **Ninja:** https://github.com/ninja-build/ninja/archive/v1.10.2/ninja-1.10.2.tar.gz  
    **NSPR:** https://archive.mozilla.org/pub/nspr/releases/v4.32/src/nspr-4.32.tar.gz  
    **NSS:** https://archive.mozilla.org/pub/security/nss/releases/NSS_3_69_RTM/src/nss-3.69.tar.gz  
    **Openjpeg:** https://github.com/uclouvain/openjpeg/archive/v2.4.0/openjpeg-2.4.0.tar.gz  
    **OpenSSL:** https://www.openssl.org/source/openssl-1.1.1l.tar.gz  
    **OpenSSH:** https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-8.6p1.tar.gz  
    **P11-Kit:** https://github.com/p11-glue/p11-kit/releases/download/0.24.0/p11-kit-0.24.0.tar.xz  
    **Patch:** https://ftp.gnu.org/gnu/patch/patch-2.7.6.tar.xz  
    **PCIUtils:** https://mirrors.edge.kernel.org/pub/software/utils/pciutils/pciutils-3.7.0.tar.xz  
    **PCRE:** https://ftp.pcre.org/pub/pcre/pcre-8.45.tar.bz2  
    **Perl:** https://www.cpan.org/src/5.0/perl-5.34.0.tar.gzz  
    **Pkg-Config:** https://pkg-config.freedesktop.org/releases/pkg-config-0.29.2.tar.gz  
    **Procps-NG:** https://sourceforge.net/projects/procps-ng/files/Production/procps-ng-3.3.17.tar.xz  
    **PSmisc:** https://sourceforge.net/projects/psmisc/files/psmisc/psmisc-23.4.tar.xz  
    **Python:** https://www.python.org/ftp/python/3.9.6/Python-3.9.6.tgz  
    **Python-Pip:** https://files.pythonhosted.org/packages/52/e1/06c018197d8151383f66ebf6979d951995cf495629fc54149491f5d157d0/pip-21.2.4.tar.gz  
    **Python-Setuptools:** https://files.pythonhosted.org/packages/db/e2/c0ced9ccffb61432305665c22842ea120c0f649eec47ecf2a45c596707c4/setuptools-57.4.0.tar.gz  
    **Readline:** https://ftp.gnu.org/gnu/readline/readline-8.1.tar.gz  
    **Sed:** https://ftp.gnu.org/gnu/sed/sed-4.8.tar.xz  
    **Shadow:** https://github.com/shadow-maint/shadow/releases/download/4.8.1/shadow-4.8.1.tar.xz  
    **Sqlite3:** https://sqlite.org/2021/sqlite-src-3360000.zip  
    **Systemd:** https://github.com/systemd/systemd/archive/v249/systemd-249.tar.gz  
    **Sudo:** https://www.sudo.ws/dist/sudo-1.9.7p2.tar.gz  
    **Tar:** https://ftp.gnu.org/gnu/tar/tar-1.34.tar.xz  
    **Texinfo:** https://ftp.gnu.org/gnu/texinfo/texinfo-6.7.tar.xz  
    **Tiff:** https://download.osgeo.org/libtiff/tiff-4.3.0.tar.gz  
    **UnRAR:** https://www.rarlab.com/rar/unrarsrc-6.0.7.tar.gz  
    **UnZip:** ftp://ftp.info-zip.org/pub/infozip/src/unzip60.tgz  
    **Usbutils:** https://mirrors.edge.kernel.org/pub/linux/utils/usb/usbutils/usbutils-014.tar.xz  
    **Util-Linux:** https://www.kernel.org/pub/linux/utils/util-linux/v2.36/util-linux-2.36.2.tar.xz  
    **Vala:** https://download.gnome.org/sources/vala/0.53/vala-0.53.1.tar.xz  
    **VIM:** https://github.com/vim/vim/archive/refs/tags/v8.2.2879.tar.gz  
    **WGet:** https://ftp.gnu.org/gnu/wget/wget-1.21.1.tar.gz  
    **Wireless-Tools:** https://hewlettpackard.github.io/wireless-tools/wireless_tools.29.tar.gz  
    **Wpa_Supplicant:** https://w1.fi/releases/wpa_supplicant-2.9.tar.gz  
    **Xfsprogs:** https://mirrors.edge.kernel.org/pub/linux/utils/fs/xfs/xfsprogs/xfsprogs-5.12.0.tar.xz  
    **XML-Parser:** https://cpan.metacpan.org/authors/id/T/TO/TODDR/XML-Parser-2.46.tar.gz  
    **XZ:** https://tukaani.org/xz/xz-5.2.5.tar.xz  
    **Zip:** ftp://ftp.info-zip.org/pub/infozip/src/zip30.tgz  
    **Zlib:** https://zlib.net/zlib-1.2.11.tar.xz  
    **Zstd:** https://github.com/facebook/zstd/releases/download/v1.5.0/zstd-1.5.0.tar.gz    


    The following is the download address of the patch file required for this build:

    https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/automake-1.16.3-add-loongarch.patch  
    https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/ctags-5.8-fix_form_fedora.patch  
    https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/ctags-5.8-for-gcc_12.patch  
    https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/gcc-12-loongarch-fix-ldso_name-2.patch  
    https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/glibc-2.33-fix-ldso_name.patch  
    https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/glibc-2.34-fix-setjmp.patch  
    https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/grub-2.06-loongarch-li_to_liw.patch  
    https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/grub-2.06-fix-initrd.patch  
    https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/icu4c-69-add-loongarch.patch  
    https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/kbd-2.4.0-backspace-1.patch  
    https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/libffi-3.3-add-loongarch.patch  
    https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/linux-5-loongarch-rearrange_ucontext_layout.patch  
    https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/nspr-4.32-add-loongarch64.patch  
    https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/stack-direction-add-loongarch.patch  
    https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/systemd-249-add-loongarch64.patch  
    https://downloads.sourceforge.net/sourceforge/libpng-apng/libpng-1.6.37-apng.patch.gz   
    https://www.linuxfromscratch.org/patches/blfs/svn/wireless_tools-29-fix_iwlist_scanning-1.patch  


Other download addresses:

    **ACPI-Update:** https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/20210822/acpi-update-20210822.tar.gz  
    **SSL certificate file:** https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/20210818/ssl-certs.tar.gz  


    After the download is complete, leave the "downloads" directory:

```sh
popd
```


## 3 Make a cross tool chain and related tools
    Then we will formally enter the production link of cross tool chain and related tools.
### 3.1 Linux kernel header file

* Code preparation  
    The Linux kernel needs to be expanded and transplanted to the software package. If there is no official software support, a special method of obtaining code is required. The following is the method of obtaining:

```sh
git clone https://github.com/loongson/linux.git -b loongarch-next --depth 1
pushd linux
    git archive --format=tar --output ../linux-5.git.tar "loongarch-next"
popd
mkdir linux-5.git
pushd linux-5.git
    tar xvf ../linux-5.git.tar
popd
tar -czf ${DOWNLOADDIR}/linux-5.git.tar.gz linux-5.git

```

* Build steps  
    Follow the steps below to make the Linux kernel header file and install it in the target system directory.

```sh
tar xvf ${DOWNLOADDIR}/linux-5.git.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/linux-5.git
	patch -Np1 -i ${DOWNLOADDIR}/linux-5-loongarch-rearrange_ucontext_layout.patch
	make mrproper
	make ARCH=loongarch INSTALL_HDR_PATH=dest headers_install
	find dest/include -name'.*' -delete
	mkdir -pv ${SYSDIR}/sysroot/usr/include
	cp -rv dest/include/* ${SYSDIR}/sysroot/usr/include
popd
```


### 3.2 Binutils of Cross Compiler
* Code preparation  
    Binutils needs to be expanded and transplanted to the software package. If there is no official software support, a special method of obtaining code is required. The following is the method of obtaining:

```sh
git clone https://github.com/loongson/binutils-gdb.git -b loongarch/upstream_v6_a1d65b3 --depth 1
pushd binutils-gdb
    git archive --format=tar --output ../binutils-2.37.tar "loongarch/upstream_v6_a1d65b3"
popd
mkdir binutils-2.37
pushd binutils-2.37
    tar xvf ../binutils-2.37.tar
popd
tar -czf ${DOWNLOADDIR}/binutils-2.37.tar.gz binutils-2.37
```

* Build steps  
    Follow the steps below to make Binutils in the cross-compilation toolchain and install it in the directory where the cross-toolchain is stored.

```sh
tar xvf ${DOWNLOADDIR}/binutils-2.37.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/binutils-2.37
	rm -rf gdb* libdecnumber readline sim
	mkdir build
	cd build
	CC=gcc AR=ar AS=as \
	../configure --prefix=${SYSDIR}/cross-tools --build=${CROSS_HOST} --host=${CROSS_HOST} \
	             --target=${CROSS_TARGET} --with-sysroot=${SYSDIR}/sysroot --disable-nls \
	             --disable-static --disable-werror --enable-64-bit-bfd
	make configure-host
	make 
	make install
	cp -v ../include/libiberty.h ${SYSDIR}/sysroot/usr/include
popd
```

### 3.3 GMP
    Build the GMP software package used in the cross tool chain.

```sh
tar xvf ${DOWNLOADDIR}/gmp-6.2.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/gmp-6.2.1
	./configure --prefix=${SYSDIR}/cross-tools --enable-cxx --disable-static
	make
	make install
popd
```

### 3.4 MPFR
    Build the MPFR software package used in the cross tool chain.  

```sh
tar xvf ${DOWNLOADDIR}/mpfr-4.1.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/mpfr-4.1.0
	./configure --prefix=${SYSDIR}/cross-tools --disable-static --with-gmp=${SYSDIR}/cross-tools
	make
	make install
popd
```

### 3.5 MPC
    Build the MPC software package used in the cross tool chain.

```sh
tar xvf ${DOWNLOADDIR}/mpc-1.2.1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/mpc-1.2.1 
	./configure --prefix=${SYSDIR}/cross-tools --disable-static --with-gmp=${SYSDIR}/cross-tools
	make
	make install
popd
```

### 3.6 GCC for Cross Compiler (Lite Edition)
* Code preparation  
    GCC needs to expand the transplanted software package. If there is no support in the  official software, the special method of obtaining code is required. Following is the method of retreiving version which support LoongArch64:

```sh
git clone https://github.com/loongson/gcc.git -b loongarch_upstream --depth 1
pushd gcc
    git archive --format=tar --output ../gcc-12.0.0.tar "loongarch_upstream"
popd
mkdir gcc-12.0.0
pushd gcc-12.0.0
    tar xvf ../gcc-12.0.0.tar
popd
tar -czf ${DOWNLOADDIR}/gcc-12.0.0.tar.gz gcc-12.0.0
```

* Build steps  
    To biuld the GCC in the cross-compiler, the GCC for the cross-toolchain needs to be compiled and installed in a simplified way for the first time to compile. Otherwise it will fail to compile and link part of the content due to the lack of the C library of the target system. The build process is as follows:

```sh
tar xvf ${DOWNLOADDIR}/gcc-12.0.0.tar.gz -C ${BUILDDIR} 
pushd ${BUILDDIR}/gcc-12.0.0
	patch -Np1 -i ${DOWNLOADDIR}/gcc-12-loongarch-fix-ldso_name-2.patch
	mkdir build
	pushd build
		AR=ar LDFLAGS="-Wl,-rpath,${SYSDIR}/cross-tools/lib" \
		../configure --prefix=${SYSDIR}/cross-tools --build=${CROSS_HOST} --host=${CROSS_HOST} \
		             --target=${CROSS_TARGET} --disable-nls \
		             --with-mpfr=${SYSDIR}/cross-tools --with-gmp=${SYSDIR}/cross-tools \
		             --with-mpc=${SYSDIR}/cross-tools \
		             --with-newlib --disable-shared --with-sysroot=${SYSDIR}/sysroot \
		             --disable-decimal-float --disable-libgomp --disable-libitm \
		             --disable-libsanitizer --disable-libquadmath --disable-threads \
		             --disable-target-zlib \
		             --with-system-zlib --enable-checking=release \
		             --with-abi=${MABI} --with-fix-loongson3-llsc \
		             --enable-languages=c
		make all-gcc all-target-libgcc
		make install-gcc install-target-libgcc
	popd
popd
```

For the target LoongArch architecture, there are currently several parameters that require special attention:  
* ```--with-newlib```, because there is currently no Glibc support for the target system, so use newlib to temporarily support the operation of GCC.    
* ```--disable-shared```, this parameter is required to use newlib.
* ```--with-abi=${MABI}```, the conversion is --with-abi=lp64, and the ABI name used by loongarch64 is lp64.  
* ```--enable-languages=c```, this time just compile C language support, because currently there is no Glibc of the target system, only a simplified version can be produced.


### 3.7 Glibc for the target system
* Code preparation  
    Glibc needs to be expanded and transplanted to the software package. If there is no support in the  official software, the special method of obtaining code is required. Following is the method of retreiving version which support LoongArch64:

```sh
git clone https://github.com/loongson/glibc.git -b loongarch_2_34_for_upstream --depth 1
pushd glibc
    git archive --format=tar --output ../glibc-2.34.tar "loongarch_2_34_for_upstream"
popd
mkdir glibc-2.34
pushd glibc-2.34
    tar xvf ../glibc-2.34.tar
popd
tar -czf ${DOWNLOADDIR}/glibc-2.34.tar.gz glibc-2.34
```

* Production steps  
    After building and installing the Binutils of the cross tool chain, the simplified version of GCC and the header files of the Linux kernel, you can compile the Glibc for the target system. The build and installation steps are as follows:

```sh
tar xvf ${DOWNLOADDIR}/glibc-2.34.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/glibc-2.34
    patch -Np1 -i ${DOWNLOADDIR}/glibc-2.33-fix-ldso_name.patch
    patch -Np1 -i ${DOWNLOADDIR}/glibc-2.34-fix-setjmp.patch
    mkdir -v build-64
    pushd build-64
	    BUILD_CC="gcc" CC="${CROSS_TARGET}-gcc ${BUILD64}" \
        CXX="${CROSS_TARGET}-gcc ${BUILD64}" \
        AR="${CROSS_TARGET}-ar" RANLIB="${CROSS_TARGET}-ranlib" \
        ../configure --prefix=/usr --host=${CROSS_TARGET} --build=${CROSS_HOST} \
	                 --libdir=/usr/lib64 --libexecdir=/usr/lib64/glibc \
	                 --with-binutils=${SYSDIR}/cross-tools/bin \
	                 --with-headers=${SYSDIR}/sysroot/usr/include \
	                 --enable-stack-protector=strong --enable-add-ons \
	                 --disable-werror libc_cv_slibdir=/usr/lib64
		make
		make DESTDIR=${SYSDIR}/sysroot install
	popd
popd
```
    Glibc is part of the target system, so when specifying path parameters such as prefix, it is set according to the path of the conventional system. Therefore, DESTDIR must be specified during installation to specify the installation to the directory where the target system is stored.

### 3.8 GCC for Cross Compiler (Full Version)
    After completing the Glibc for the target system, you can start building the full version of GCC in the cross tool chain. The building steps are as follows:

```sh
tar xvf ${DOWNLOADDIR}/gcc-12.0.0.tar.gz -C ${BUILDDIR} 
pushd ${BUILDDIR}/gcc-12.0.0
	patch -Np1 -i ${DOWNLOADDIR}/gcc-12-loongarch-fix-ldso_name-2.patch
	sed -i "/cfenv/d" libstdc++-v3/src/c++17/*.cc
	mkdir build-all
	pushd build-all
		AR=ar LDFLAGS="-Wl,-rpath,${SYSDIR}/cross-tools/lib" \
		../configure --prefix=${SYSDIR}/cross-tools --build=${CROSS_HOST} \
		             --host=${CROSS_HOST} --target=${CROSS_TARGET} \
		             --with-sysroot=${SYSDIR}/sysroot --with-mpfr=${SYSDIR}/cross-tools \
		             --with-gmp=${SYSDIR}/cross-tools --with-mpc=${SYSDIR}/cross-tools \
		             --enable-__cxa_atexit --enable-threads=posix --with-system-zlib \
		             --enable-libstdcxx-time --enable-checking=release \
		             --with-abi=${MABI} --with-fix-loongson3-llsc \
		             --enable-languages=c,c++,fortran,objc,obj-c++,lto
		make
		make install
	popd
popd
```

After completing the Glibc for the target system, you can add and modify some compilation parameters, mainly as follows:  
* Removed ```--with-newlib``` and ```--disable-shared```, because Glibc available now, newlib is no longer needed.  
* ```--enable-threads=posix```, thread support can be set.
* ```--enable-languages=c,c++,fortran,objc,obj-c++,lto```, more development languages can be supported.

### 3.9 File
    The latest official version of the File software package has integrated the support of LoongArch, which can identify the binary files of the LoongArch architecture, so the version above 5.40 is used when making it.

```sh
tar xvf ${DOWNLOADDIR}/file-5.40.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/file-5.40
	./configure --prefix=${SYSDIR}/cross-tools
	make
	make install
popd
```

### 3.10 Automake
    The Automake software package provides many scripts integrated with the software package to generate Makefile files, but the script target has not yet added support for the LoongArch architecture, so it is necessary to patch the software package to increase the support. The build steps are as follows:

```sh
tar xvf ${DOWNLOADDIR}/automake-1.16.3.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/automake-1.16.3
	patch -Np1 -i ${DOWNLOADDIR}/automake-1.16.3-add-loongarch.patch
	./configure --prefix=${SYSDIR}/cross-tools
	make
	make install
popd
```

    Apply the patch and install it in the directory of the cross toolchain, so that when there are subsequent software packages that need to update the script file, it can be replaced by the script file in the Automake installed this time.

### 3.11 Pkg-Config
    In order to be able to use the "pc" file installed in the target system during the cross-compiling of the target system, we install a pkg-config in the directory of the cross tool chain specifically to query the "pc" file from the target system directory Command, the build process is as follows:

```sh
tar xvf ${DOWNLOADDIR}/pkg-config-0.29.2.tar.gz -C ${BUILDDIR}/
pushd ${BUILDDIR}/pkg-config-0.29.2
	./configure --prefix=${SYSDIR}/cross-tools \
	            --with-pc_path=${SYSDIR}/sysroot/usr/lib64/pkgconfig:${SYSDIR}/sysroot/usr/share/pkgconfig \
	            --program-prefix=${CROSS_TARGET}- --with-internal-glib --disable-host-tool
	make
	make install
popd
```

### 3.12 Ninja

```sh
tar xvf ${DOWNLOADDIR}/ninja-1.10.2.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/ninja-1.10.2
	python3 configure.py --bootstrap
	install -vm755 ninja ${SYSDIR}/cross-tools/bin/
popd
```

### 3.13 Groff
	The process of compiling the target system will have certain requirements for Groff version, so install a newer version of Groff in the directory of the cross tool chain.

```sh
tar xvf ${DOWNLOADDIR}/groff-1.22.4.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/groff-1.22.4
	PAGE=A4 ./configure --prefix=${SYSDIR}/cross-tools
	make
	make install
popd
```


### 3.14 Perl
```sh
tar xvf ${DOWNLOADDIR}//perl-5.34.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/perl-5.34.0
    sed -i "s@/usr/include@${SYSDIR}/cross-tools/include@g" ext/Errno/Errno_pm.PL
    ./configure.gnu --prefix=${SYSDIR}/cross-tools \
    	             -Dprivlib=${SYSDIR}/cross-tools/lib/perl5/5.34/core_perl \
	             -Darchlib=${SYSDIR}/cross-tools/lib64/perl5/5.34/core_perl \
	             -Dsitelib=${SYSDIR}/cross-tools/lib/perl5/5.34/site_perl \
	             -Dsitearch=${SYSDIR}/cross-tools/lib64/perl5/5.34/site_perl \
	             -Dvendorlib=${SYSDIR}/cross-tools/lib/perl5/5.34/vendor_perl \
	             -Dvendorarch=${SYSDIR}/cross-tools/lib64/perl5/5.34/vendor_perl
    make
    make install
popd
```

### 3.15 Python
```sh
tar xvf ${DOWNLOADDIR}/Python-3.9.6.tgz -C ${BUILDDIR}
pushd ${BUILDDIR}/Python-3.9.6
	./configure --prefix=${SYSDIR}/cross-tools --libdir=${SYSDIR}/cross-tools/lib64 \
	            --enable-shared --with-system-expat --with-system-ffi \
	            --with-ensurepip=install --enable-optimizations
	make
	make install
popd
```

### 3.16 Grub2
    In order to make and generate the EFI boot file used on LoongArch machine in the cross-compilation environment, we store a Grub software package that can generate the EFI of the target machine in the cross tool chain directory.

* Code preparation  
    Grub2 needs to be expanded and transplanted to the software package. If there is no official software support, a special method of obtaining code is required. The following is the method of obtaining:

```sh
git clone -b "dev-la64" https://github.com/loongarch64/grub.git
pushd grub
    git archive --format=tar --output ../grub-2.06.tar "dev-la64"
    ./bootstrap
    pushd gnulib
        git archive --format=tar --output ../../gnulib.tar HEAD
    popd
popd
mkdir grub-2.06
pushd grub-2.06
    tar xvf ../grub-2.06.tar
    mkdir gnulib
    tar xvf ../gnulib.tar -C gnulib
    ./bootstrap
popd
tar -czf ${DOWNLOADDIR}/grub-2.06.tar.gz grub-2.06

```

* Build steps  

```sh
tar -xvf ${DOWNLOADDIR}/grub-2.06.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/grub-2.06
    patch -Np1 -i ${DOWNLOADDIR}/grub-2.06-loongarch-li_to_liw.patch
    patch -Np1 -i ${DOWNLOADDIR}/grub-2.06-fix-initrd.patch
    sed -i "s@-march=loongarch @@g" Makefile.in conf/Makefile.common grub-core/Makefile.in
	mkdir build
	pushd build
		TARGET_CC="${CROSS_TARGET}-gcc" \
		../configure --build=${CROSS_HOST} --host=${CROSS_HOST} \
		             --target=${CROSS_TARGET} --prefix=${SYSDIR}/cross-tools \
		             --program-transform-name=s,grub,${CROSS_TARGET}-grub, \
		             --with-platform=efi --with-utils=host --disable-werror
		make
		make install
	popd
popd
```
    The built Grub can run in the X86 Linux system environment and can generate the EFI file used on the LoongArch machine.


## 4 Make the target system
    After the cross tool chain and related tools are built and installed, you can continue to produce the target system.
    
### 4.1 Distribution building instructions

#### Schema test script replacement
    In the process of building the target system, you will often encounter the words that indicate that the loongarch64 architecture is not recognized in the configure phase. This is usually because the architecture detection script that comes with the software package does not increase the recognition of the loongarch64 architecture, so you need to deal with the problem. There are usually two ways:  
    1. Delete the configuration script, and then automatically add the new detection script to the software package through the automake command. The specific operation method is:  

```sh
rm config.guess config.sub
automake --add-missing
```

    It is assumed here that the two script files config.guess and config.sub are in the first-level directory of the software package, or in directories such as build-aux, find the files and delete them, and then use the "--add-" of the automake command "missing" parameter to run, this parameter will automatically confirm whether the script for detecting the architecture is missing, if it is missing, it will be copied from the directory where the Automake package is installed, because automake runs in the cross tool chain directory, so it has been added The judgment of the LoongArch architecture, so that the software package can run normally.

    2. Directly replace the file, the specific operation method is:

```sh
cp ${SYSDIR}/sysroot/usr/share/automake-1.16/config.* config/
```

    If you can’t solve the problem with the automake command, you can directly copy the script file installed by the Automake package. Take the Automake-1.16 version we installed as an example, copy the beginning of config from ${SYSDIR}/sysroot/usr/share/automake-1.16/ The file overwrites the file with the same name in the software package currently to be compiled. It is assumed that the file to be overwritten is in the config directory, or it may be in another directory, which can be overwritten as needed.

    It is also possible that there are multiple detection scripts in a software package, so all of them need to be covered.
    
#### Install the software package in the target system
    The software packages in the target system are all stored in the root directory ("/") when installed, so if they are installed directly, they will be installed in the directory of the main system. This must be wrong, so when we install Add the "DESTDIR" parameter to specify a directory, then the installed files will be installed with the specified directory as the root directory of the installation. When we set it as the directory where the target system is stored, we can avoid conflicts with the main system and allow installation The packages are installed in the normal directory structure.

    In the subsequent production process, you will see that most software packages support the "DESTDIR" parameter setting, but some software packages do not. In this case, similar functional parameters supported by the software package are usually used to solve the problem.

#### Cross-compile software package
    Generally, the "build" and "host" parameters can be used to specify the compilation method for the software package with the configure configuration script. When the "build" and "host" are the same, it is local compilation, and when they are different, it is cross-compilation.
    
    The "build" parameter can be understood as the architecture system information used by the current main system, and the "host" is the architecture system information used by the target system. In this article, the Linux system of LoongArch64 architecture is cross-compiled in the x86 Linux system, so According to the previously defined environment variables, "build" is designated as ```${CROSS_HOST}``` to represent the current main system, and "host" is designated as ```${CROSS_TARGET}`'' to represent the compilation The target architecture system.

    Because it is cross-compilation, it is possible to detect parameter errors during the configuration phase of the software package. This may cause the compiled software package to not match the target architecture system. At this time, you can specify some detection parameters to solve the problem, usually you can use the creation config.cache file, and then write some parameters and values that need to be detected into the file, for example:

```sh
cat> config.cache << "EOF"
    ac_cv_func_mmap_fixed_mapped=yes
    ......
EOF
```

    After that specify ```--cache-file=config.cache``` in the configure parameters, so that you can use the values set in the file, instead of trying to detect parameters automaticaly, which can help avoid detection errors.

#### Compile directory
    Most software packages can be configured and compiled in the "root directory" of the software package, but there are also some packages that suggest creating a new directory for configuration and compilation. For these packages that require directory to be created for compilation, we usually use Create a directory starting with "build" under the software directory, and compile in this directory, so as to facilitate the cleanup work after using the software package.

#### Clear the compilation directory
    After completing the cross-tool compilation, it is recommended to clean up the ```${BUILDDIR}``` directory, because all files in this directory are needed for the compilation process, you can simply delete all files and directories, for example Use the following command (be careful not to delete system files or important data by mistake when deleting in batches):

```sh
    rm -rf ${SYSDIR}/build/*
```

    Be careful to keep the build directory itself, because you will need to use it in the future.

#### Set environment variables
‵``sh
export LDFLAGS="-Wl,-rpath-link=${SYSDIR}/sysroot/usr/lib64"
export PKG_CONFIG_SYSROOT_DIR=${SYSDIR}/sysroot
```

### 4.2 The building of software packages

#### Man-Pages
```sh
tar xvf ${DOWNLOADDIR}/man-pages-5.11.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/man-pages-5.11
	make DESTDIR=${SYSDIR}/sysroot install
popd
```
    The Man-Pages software package has no configuration phase, just install it directly into the target system's directory.

##### Iana-Etc
```sh
tar xvf ${DOWNLOADDIR}/iana-etc-20210407.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/iana-etc-20210407
	cp services protocols ${SYSDIR}/sysroot/etc
popd
```
    The Iana-Etc software package does not need to be configured and compiled, as long as the included files are copied to the directory of the target system.

#### GMP
```sh
tar xvf ${DOWNLOADDIR}/gmp-6.2.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/gmp-6.2.1
	rm config.guess config.sub
	automake --add-missing
	./configure --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --prefix=/usr --libdir=/usr/lib64 --enable-cxx
	make 
	make DESTDIR=${SYSDIR}/sysroot install
	rm -v ${SYSDIR}/sysroot/usr/lib64/lib{gmp,gmpxx}.la
popd
```
    The detection framework script that comes with the GMP software package does not support LoongArch, so delete the detection script and use the automake command to reinstall the detection script.

#### MPFR
```sh
tar xvf ${DOWNLOADDIR}/mpfr-4.1.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/mpfr-4.1.0
	./configure --build=${CROSS_HOST} --host=${CROSS_TARGET} --prefix=/usr --libdir=/usr/lib64
	make
	make DESTDIR=${SYSDIR}/sysroot install
	rm -v ${SYSDIR}/sysroot/usr/lib64/libmpfr.la
popd
```

#### MPC
```sh
tar xvf ${DOWNLOADDIR}/mpc-1.2.1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/mpc-1.2.1
	rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
	automake --add-missing
	./configure --build=${CROSS_HOST} --host=${CROSS_TARGET} --prefix=/usr --libdir=/usr/lib64
	make
	make DESTDIR=${SYSDIR}/sysroot install
	rm -v ${SYSDIR}/sysroot/usr/lib64/libmpc.la
popd
```

#### Zlib
```sh
tar xvf ${DOWNLOADDIR}/zlib-1.2.11.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/zlib-1.2.11
	CC="${CROSS_TARGET}-gcc" ./configure --prefix=/usr --libdir=/usr/lib64
	make
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Binutils
    The Binutils compiled this time is used in the target system and will not be used in the cross-compilation phase.

```sh
tar xvf ${DOWNLOADDIR}/binutils-2.37.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/binutils-2.37
	rm -rf gdb* libdecnumber readline sim
	mkdir build
	pushd build
		../configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
		             --host=${CROSS_TARGET} --enable-shared --disable-werror \
		             --with-system-zlib --enable-64-bit-bfd
		make tooldir=/usr
		make DESTDIR=${SYSDIR}/sysroot tooldir=/usr install
	popd
popd
```

#### GCC
    Like the Binutils compiled above, the GCC compiled this time is also the compiler used in the target system. It will not be used in the cross-compilation phase, but the libgcc, libstdc++ and other libraries it provides can be linked for subsequent software package compilation The library used.

```sh
tar xvf ${DOWNLOADDIR}/gcc-12.0.0.tar.gz -C ${BUILDDIR} 
pushd ${BUILDDIR}/gcc-12.0.0
	patch -Np1 -i ${DOWNLOADDIR}/gcc-12-loongarch-fix-ldso_name-2.patch
	sed -i "/cfenv/d" libstdc++-v3/src/c++17/*.cc
	sed -i's@\./fixinc\.sh@-c true@' gcc/Makefile.in
	mkdir build
	pushd build
		../configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
		             --host=${CROSS_TARGET} --target=${CROSS_TARGET} \
		             --enable-__cxa_atexit --enable-threads=posix \
		             --with-system-zlib --enable-libstdcxx-time \
		             --enable-checking=release \
		             --with-build-sysroot=${SYSDIR}/sysroot \
		             --with-abi=${MABI} --with-fix-loongson3-llsc \
		             --enable-languages=c,c++,fortran,objc,obj-c++,lto
		make
		make DESTDIR=${SYSDIR}/sysroot install
		ln -sv /usr/bin/cpp ${SYSDIR}/sysroot/lib
		ln -sv gcc ${SYSDIR}/sysroot/usr/bin/cc
	popd
popd
```

    Because it is used in the target system, the compilation is complete, and the support for languages such as C, C++, and Fortran is added.

#### Bzip2
```sh
tar xvf ${DOWNLOADDIR}/bzip2-1.0.8.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/bzip2-1.0.8
	sed -i.orig -e "/^all:/s/ test//" Makefile
	sed -i -e's:ln -s -f $(PREFIX)/bin/:ln -s -f :'Makefile
	make CC=${CROSS_TARGET}-gcc -f Makefile-libbz2_so
	make clean
	make CC=${CROSS_TARGET}-gcc
	make PREFIX=${SYSDIR}/sysroot/usr install
	cp -v bzip2-shared ${SYSDIR}/sysroot/bin/bzip2
	cp -av libbz2.so* ${SYSDIR}/sysroot/lib64
	ln -sfv ../../lib64/libbz2.so.1.0 ${SYSDIR}/sysroot/usr/lib64/libbz2.so
	ln -sfv bzip2 ${SYSDIR}/sysroot/bin/bunzip2
	ln -sfv bzip2 ${SYSDIR}/sysroot/bin/bzcat
	rm -fv ${SYSDIR}/sysroot/usr/lib/libbz2.a
popd
```

    Since the Bzip2 software package does not have a configure configuration script, the CC parameter is directly specified for the make command when compiling. This parameter is used to set the compiler executable used when compiling the program. The cross compiler is set here to ensure compilation uses a cross-compiler.
    When installing the Bzip2 software package, because there is no DESTDIR parameter to set the installation root directory, the path of the target system storage directory is added to the PREFIX parameter.

#### XZ
```sh
tar xvf ${DOWNLOADDIR}/xz-5.2.5.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/xz-5.2.5
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make
	make DESTDIR=${SYSDIR}/sysroot install
	rm ${SYSDIR}/sysroot/usr/lib64/liblzma.la
popd
```

#### Zstd
```sh
tar xvf ${DOWNLOADDIR}/zstd-1.5.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/zstd-1.5.0
	make CC="${CROSS_TARGET}-gcc" PREFIX=/usr LIBDIR=/usr/lib64
	make CC="${CROSS_TARGET}-gcc" PREFIX=/usr LIBDIR=/usr/lib64 DESTDIR=${SYSDIR}/sysroot install
popd
```

#### File
```sh
tar xvf ${DOWNLOADDIR}/file-5.40.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/file-5.40
	rm config.{sub,guess}
	automake --add-missing
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Ncurses
```sh
tar xvf ${DOWNLOADDIR}/ncurses-6.2.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/ncurses-6.2
	rm config.{sub,guess}
	automake --add-missing
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
	            --host=${CROSS_TARGET} --with-shared --without-debug \
	            --without-normal --enable-pc-files \
	            --with-pkg-config-libdir=/usr/lib64/pkgconfig --enable-widec \
	            --disable-stripping
	make
	make DESTDIR=${SYSDIR}/sysroot install
	
	for lib in ncurses form panel menu; do
	    rm -vf ${SYSDIR}/sysroot/usr/lib64/lib${lib}.so
	    echo "INPUT(-l${lib}w)"> ${SYSDIR}/sysroot/usr/lib64/lib${lib}.so
	    ln -sfv ${lib}w.pc ${SYSDIR}/sysroot/usr/lib64/pkgconfig/${lib}.pc
	done
	
	rm -vf ${SYSDIR}/sysroot/usr/lib64/libcursesw.so
	echo "INPUT(-lncursesw)"> ${SYSDIR}/sysroot/usr/lib64/libcursesw.so
	ln -sfv libncurses.so ${SYSDIR}/sysroot/usr/lib64/libcurses.so
	rm -fv ${SYSDIR}/sysroot/usr/lib64/libncurses++wa
popd

cp -v ${SYSDIR}/sysroot/usr/bin/ncursesw6-config ${SYSDIR}/cross-tools/bin/
sed -i "s@-L\$libdir@@g" ${SYSDIR}/cross-tools/bin/ncursesw6-config
```
    After installing the Ncurses of the target system, I copied a ncursesw6-config script command to the cross-compilation directory. This is because the command will be called to obtain the link information of the Nucrses library installed in the target system when compiling some software packages later. If the library link in the main system is inconsistent with the library link in the target system, the link may fail. Therefore, providing a script that can link the information correctly is an effective solution.

#### Readline
```sh
tar xvf ${DOWNLOADDIR}/readline-8.1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/readline-8.1
	sed -i'/MV.*old/d' Makefile.in
	sed -i'/{OLDSUFF}/c:' support/shlib-install
	rm support/config.{sub,guess}
	automake --add-missing
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} --host=${CROSS_TARGET} \
				--disable-static --with-curses
	make SHLIB_LIBS="-lncursesw"
	make SHLIB_LIBS="-lncursesw" DESTDIR=${SYSDIR}/sysroot install
popd
```

    Due to cross-compilation reasons, Readline's configuration script cannot correctly detect the Ncurses software package installed in the target system, so adding the ```--with-curses``` parameter in the configuration ensures that Ncurses support is added and added during the compilation phase ```SHLIB_LIBS="-lncursesw"``` to ensure that the library files are linked correctly.

#### M4
```sh
tar xvf ${DOWNLOADDIR}/m4-1.4.19.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/m4-1.4.19
	patch -Np1 -i ${DOWNLOADDIR}/stack-direction-add-loongarch.patch
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### BC
```sh
tar xvf ${DOWNLOADDIR}/bc-4.0.2.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/bc-4.0.2
	CC="${CROSS_TARGET}-gcc" HOSTCC="gcc" ./configure --prefix=/usr
	make
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Flex
```sh
tar xvf ${DOWNLOADDIR}/flex-2.6.4.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/flex-2.6.4
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
	            --host=${CROSS_TARGET} --disable-static ac_cv_func_malloc_0_nonnull=yes \
	            ac_cv_func_realloc_0_nonnull=yes
	make
	make DESTDIR=${SYSDIR}/sysroot install
	ln -sv flex ${SYSDIR}/sysroot/usr/bin/lex
popd
```

#### Attr
```sh
tar xvf ${DOWNLOADDIR}/attr-2.5.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/attr-2.5.1
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
	            --host=${CROSS_TARGET} --disable-static --sysconfdir=/etc
	make
	make DESTDIR=${SYSDIR}/sysroot install
	rm ${SYSDIR}/sysroot/usr/lib64/libattr.la
popd
```

#### Acl
```sh
tar xvf ${DOWNLOADDIR}/acl-2.3.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/acl-2.3.1
	rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
	automake --add-missing
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
	            --host=${CROSS_TARGET} --disable-static
	make
	make DESTDIR=${SYSDIR}/sysroot install
	rm ${SYSDIR}/sysroot/usr/lib64/libacl.la
popd
```

#### Libcap
```sh
tar xvf ${DOWNLOADDIR}/libcap-2.54.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libcap-2.54
	make CROSS_COMPILE="${CROSS_TARGET}-" BUILD_CC="gcc" GOLANG=no prefix=/usr lib=lib64
	make CROSS_COMPILE="${CROSS_TARGET}-" BUILD_CC="gcc" GOLANG=no prefix=/usr lib=lib64 \
		 DESTDIR=${SYSDIR}/sysroot install
popd
```

    Because the software package does not have a configuration script, directly add the parameter of the specified compiler ```CROSS_COMPILE="${CROSS_TARGET}-"``` to the make command. It should be noted that CROSS_COMPILE specifies the prefix of the cross-compilation tool instead of The specific command name, so that various compilation, assembly and link-related commands will automatically add the specified prefix during the compilation process.

    In addition, during the compilation process, the program running in the main system will be compiled. At this time, the cross compiler cannot be used to compile, so you need to specify the parameter ```BUILD_CC="gcc"``` to ensure that the compiling built-time programs uses local compiler.

#### Shadow
```sh
tar xvf ${DOWNLOADDIR}/shadow-4.8.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/shadow-4.8.1
	sed -i's/groups$(EXEEXT) //' src/Makefile.in
	find man -name Makefile.in -exec sed -i's/groups\.1 / /'{} \;
	find man -name Makefile.in -exec sed -i's/getspnam\.3 / /'{} \;
	find man -name Makefile.in -exec sed -i's/passwd\.5 / /'{} \;
	sed -e's:#ENCRYPT_METHOD DES:ENCRYPT_METHOD SHA512:' \
	    -e's:/var/spool/mail:/var/mail:' \
	    -e'/PATH=/{s@/sbin:@@;s@/bin:@@}' \
	    -i etc/login.defs
	sed -i's/1000/999/' etc/useradd
	./configure --sysconfdir=/etc --build=${CROSS_HOST} --host=${CROSS_TARGET} \
				--with-group-name-max-length=32
	make
	make DESTDIR=${SYSDIR}/sysroot install
	sed -i's/yes/no/' ${SYSDIR}/sysroot/etc/default/useradd
popd
```

    The software package has modified some default settings, the following main modifications are introduced:  
    1. Change the user password encryption mode from DES to SHA512, the latter is more difficult to crack than the former.  
    2. Modify useradd to create the user's default starting group number. This modification can be changed or not, but the group corresponding to this group number must exist in the target system regardless of whether it is changed or not.  
    3. Modify the default setting of creating a mail directory when the useradd command creates a user. This directory is rarely used at present, so it is modified to not create it by default.

#### Sed
```sh
tar xvf ${DOWNLOADDIR}/sed-4.8.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/sed-4.8
	rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
	automake --add-missing
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Pkg-Config
```sh
tar xvf ${DOWNLOADDIR}/pkg-config-0.29.2.tar.gz -C ${BUILDDIR}/
pushd ${BUILDDIR}/pkg-config-0.29.2
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
	            --host=${CROSS_TARGET} --with-internal-glib --disable-host-tool \
	            glib_cv_stack_grows=yes glib_cv_uscore=no \
	            ac_cv_func_posix_getpwuid_r=yes ac_cv_func_posix_getgrgid_r=yes
	make
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### PSmisc
```sh
tar xvf ${DOWNLOADDIR}/psmisc-23.4.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/psmisc-23.4
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes
	make
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Gettext
```sh
tar xvf ${DOWNLOADDIR}/gettext-0.21.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/gettext-0.21
	for i in $(dirname $(find -name "config.sub"))
	do
		rm ./$i/config.{sub,guess}
		pushd $(dirname ./$i)
		    automake --add-missing
		popd
	done
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
	            --host=${CROSS_TARGET} --disable-static \
	            --with-libncurses-prefix=${SYSDIR}/sysroot
	make
	sed -i "/hello-c++-kde/d" gettext-tools/examples/Makefile
	make DESTDIR=${SYSDIR}/sysroot install
	rm -v ${SYSDIR}/sysroot/usr/lib64/libgettext*.la
	rm -v ${SYSDIR}/sysroot/usr/lib64/libtextstyle.la
popd
```

    There are multiple detection architecture scripts in the source code of the Gettext software package. These scripts do not support the LoongArch architecture in the current version, so find all the detection scripts and replace them.

#### Bison
```sh
tar xvf ${DOWNLOADDIR}/bison-3.7.6.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/bison-3.7.6
	rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
	automake --add-missing
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Grep
```sh
tar xvf ${DOWNLOADDIR}/grep-3.7.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/grep-3.7
    patch -Np1 -i ${DOWNLOADDIR}/stack-direction-add-loongarch.patch
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Bash
```sh
tar xvf ${DOWNLOADDIR}/bash-5.1.8.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/bash-5.1.8
	rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
	automake --add-missing

	cat> config.cache << "EOF"
	ac_cv_func_mmap_fixed_mapped=yes
	ac_cv_func_strcoll_works=yes
	ac_cv_func_working_mktime=yes
	bash_cv_func_sigsetjmp=present
	bash_cv_getcwd_malloc=yes
	bash_cv_job_control_missing=present
	bash_cv_printf_a_format=yes
	bash_cv_sys_named_pipes=present
	bash_cv_ulimit_maxfds=yes
	bash_cv_under_sys_siglist=yes
	bash_cv_unusable_rtsigs=no
	gt_cv_int_divbyzero_sigfpe=yes
    EOF
	
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
	            --host=${CROSS_TARGET} --without-bash-malloc \
	            --with-installed-readline --cache-file=config.cache
	make
	make DESTDIR=${SYSDIR}/sysroot install
	ln -sv bash ${SYSDIR}/sysroot/bin/sh
popd
```

    Bash software will have a lot of parameter detection errors during the configuration phase of cross-compilation. We need to manually specify the true values of these parameters, create a text file, write the values of these parameters, and add `` `--cache-file=config.cache``` parameter (where config.cache is the name of the text file to save the parameters).

#### Libtool
```sh
tar xvf ${DOWNLOADDIR}/libtool-2.4.6.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libtool-2.4.6
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### GDBM
```sh
tar xvf ${DOWNLOADDIR}/gdbm-1.19.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/gdbm-1.19
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
	            --host=${CROSS_TARGET} --disable-static --enable-libgdbm-compat
	make
	make DESTDIR=${SYSDIR}/sysroot install
	rm ${SYSDIR}/sysroot/usr/lib64/libgdbm*.la
popd
```

#### GPerf
```sh
tar xvf ${DOWNLOADDIR}/gperf-3.1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/gperf-3.1
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Expat
```sh
tar xvf ${DOWNLOADDIR}/expat-2.3.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/expat-2.3.0
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
	            --host=${CROSS_TARGET} 
	make
	make DESTDIR=${SYSDIR}/sysroot install
	rm -v ${SYSDIR}/sysroot/usr/lib64/libexpat.la
popd
```

#### Autoconf
```sh
tar xvf ${DOWNLOADDIR}/autoconf-2.71.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/autoconf-2.71
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make
	make DESTDIR=${SYSDIR}/sysroot install
popd
```
#### Automake
```sh
tar xvf ${DOWNLOADDIR}/automake-1.16.3.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/automake-1.16.3
	patch -Np1 -i ${DOWNLOADDIR}/automake-1.16.3-add-loongarch.patch
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

    In the cross-compilation directory, we have installed an Automake package, which provides detection scripts that improve LoongArch support. Many software will need these scripts to overwrite the scripts in their source code.

    Of course, you need to change the Automake package on the target system to support LoongArch, so that you can use it when you configure and compile some software packages in the target system in the future.

#### Kmod
```sh
tar xvf ${DOWNLOADDIR}/kmod-28.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/kmod-28
	rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
	automake --add-missing
	./configure --prefix=/usr --libdir=/usr/lib64 --bindir=/bin \
	            --sysconfdir=/etc --build=${CROSS_HOST} --host=${CROSS_TARGET} \
	            --with-xz --with-zstd --with-zlib
	make
	make DESTDIR=${SYSDIR}/sysroot install
	
	for target in depmod insmod lsmod modinfo modprobe rmmod; do
		ln -sfv ../bin/kmod ${SYSDIR}/sysroot/sbin/$target
	done
	ln -sfv kmod ${SYSDIR}/sysroot/bin/lsmod
popd
```

#### Libelf
```sh
tar xvf ${DOWNLOADDIR}/elfutils-0.185.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/elfutils-0.185
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
				--host=${CROSS_TARGET} --disable-debuginfod --enable-libdebuginfod=dummy \
				ac_cv_null_dereference=no
	make
	make -C libelf DESTDIR=${SYSDIR}/sysroot install
	make -C libelf DESTDIR=${SYSDIR}/sysroot install-data
popd
```

    This software package uses cross-compilation to have individual function detection errors, which can be solved by specifying parameters and values. This build step uses another method of setting parameter values. If there are not many parameter values to be specified You can set it directly in the configure parameters, such as ```ac_cv_null_dereference=no``` This is the setting method, or you can write these two parameters to "config.cache", and then pass "--cache -file=config.cache" to use.

#### Libffi
```sh
tar xvf ${DOWNLOADDIR}/libffi-3.3.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libffi-3.3
	patch -Np1 -i ${DOWNLOADDIR}/libffi-3.3-add-loongarch.patch
	aclocal
	automake -fi
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
	            --host=${CROSS_TARGET} --disable-static --with-gcc-arch=native
	make
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

    Libffi is also a software package that needs architecture support. Here, LoongArch architecture support is added by patching.

#### OpenSSL
```sh
tar xvf ${DOWNLOADDIR}/openssl-1.1.1l.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/openssl-1.1.1l
	CC="${CROSS_TARGET}-gcc" \
	./Configure --prefix=/usr --openssldir=/etc/ssl \
				--libdir=lib64 shared zlib linux-generic64
	make
	sed -i'/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

    OpenSSL is a very important security algorithm library. Usually, assembly can be used to optimize the algorithm for different architectures, but it also provides a general C implementation, so you can use ```linux-generic64``` to specify the general implementation Compile, of course, the performance of general implementation is relatively low, in the future, if there is optimization support for LoongArch64, you can modify this parameter to achieve the purpose of optimized compilation.

#### Coreutils
```sh
tar xvf ${DOWNLOADDIR}/coreutils-8.32.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/coreutils-8.32
	sed -i "s@SYS_getdents@SYS_getdents64@g" src/ls.c
	rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
	automake --add-missing
	FORCE_UNSAFE_CONFIGURE=1 \
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET} \
				--enable-no-install-program=kill,uptime
	make
	make DESTDIR=${SYSDIR}/sysroot install
	mv -v ${SYSDIR}/sysroot/usr/bin/chroot ${SYSDIR}/sysroot/usr/sbin
popd
```

#### Diffutils
```sh
tar xvf ${DOWNLOADDIR}/diffutils-3.8.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/diffutils-3.8
    patch -Np1 -i ${DOWNLOADDIR}/stack-direction-add-loongarch.patch
	rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
	automake -a
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Gawk
```sh
tar xvf ${DOWNLOADDIR}/gawk-5.1.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/gawk-5.1.0
	sed -i's/extras//' Makefile.in
	for i in $(dirname $(find -name "config.sub"))
	do
		rm ./$i/config.{sub,guess}
		pushd $(dirname ./$i)
			automake --add-missing
		popd
	done
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Findutils
```sh
tar xvf ${DOWNLOADDIR}/findutils-4.8.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/findutils-4.8.0
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
	            --host=${CROSS_TARGET} --localstatedir=/var/lib/locate
	make
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Groff
```sh
tar xvf ${DOWNLOADDIR}/groff-1.22. 4.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/groff-1.22.4
	rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
	automake --add-missing
	PAGE=A4 ./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make TROFFBIN=troff GROFFBIN=groff GROFF_BIN_PATH=
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Less
```sh
tar xvf ${DOWNLOADDIR}/less-581.2.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/less-581.2
	./configure --prefix=/usr --sysconfdir=/etc --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Gzip
```sh
tar xvf ${DOWNLOADDIR}/gzip-1.10.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/gzip-1.10
	rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
	automake --add-missing
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### IPRoute2
```sh
tar xvf ${DOWNLOADDIR}/iproute2-5.12.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/iproute2-5.12.0
	sed -i /ARPD/d Makefile
	rm -fv man/man8/arpd.8
	sed -i's/.m_ipt.o//' tc/Makefile
	PKG_CONFIG=${CROSS_TARGET}-pkgconfig \
	make CC="${CROSS_TARGET}-gcc" HOSTCC="gcc" KERNEL_INCLUDE=${SYSDIR}/sysroot/usr/include
	PKG_CONFIG=${CROSS_TARGET}-pkgconfig \
	make CC="${CROSS_TARGET}-gcc" HOSTCC="gcc" KERNEL_INCLUDE=${SYSDIR}/sysroot/usr/include \
			DESTDIR=${SYSDIR}/sysroot install
popd
```

    The IPRoute2 package does not have a configuration stage. You can directly use the "CC" variable to specify the cross-compiler in the make command. For some programs that run locally during the compilation process, you need to use the "HOSTCC" variable to specify the local compiler. Otherwise "HOSTCC" will use the specified compiler of the "CC" variable. This is means that the compiled program will not be able to run in the cross-compiled main system.

#### KBD
```sh
tar xvf ${DOWNLOADDIR}/kbd-2.4.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/kbd-2.4.0
	patch -Np1 -i ${DOWNLOADDIR}/kbd-2.4.0-backspace-1.patch
	sed -i'/RESIZECONS_PROGS=/s/yes/no/' configure
	sed -i's/resizecons.8 //' docs/man/man8/Makefile.in
	rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
	automake --add-missing
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET} --disable-vlock
	make
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

    When cross-compiling KBD, the linked library may be missing and the build fails. At this time, you can use the LIBS variable to specify the missing linked library to complete the build of the KBD.

#### Libpipeline
```sh
tar xvf ${DOWNLOADDIR}/libpipeline-1.5.3.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libpipeline-1.5.3
	rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
	automake --add-missing
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Make
```sh
tar xvf ${DOWNLOADDIR}/make-4.3.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/make-4.3
	rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
	automake --add-missing
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Patch
```sh
tar xvf ${DOWNLOADDIR}/patch-2.7.6.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/patch-2.7.6
	./configure --prefix=/usr -build=${CROSS_HOST} --host=${CROSS_TARGET}
	make
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### CURL
```sh
tar xvf ${DOWNLOADDIR}/curl-7.78.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/curl-7.78.0
    ./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
                --host=${CROSS_TARGET} --with-openssl \
                --enable-threaded-resolver --with-ca-path=/etc/ssl/certs
	make
	make DESTDIR=${SYSDIR}/sysroot install
	cp ${SYSDIR}/sysroot/usr/bin/curl-config ${SYSDIR}/cross-tools/bin/
popd
```

#### CMake
```sh
tar xvf ${DOWNLOADDIR}/cmake-3.21.1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/cmake-3.21.1
    mkdir build
    pushd build
        cmake -DCMAKE_CXX_COMPILER="${CROSS_TARGET}-g++" -DCMAKE_C_COMPILER="${CROSS_TARGET}-gcc" \
              -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_DOC_DIR=/share/doc/cmake-3.21 \
              -DOPENSSL_ROOT_DIR=${SYSDIR}/sysroot/usr -DCMAKE_BUILD_TYPE=RELEASE ../
        sed -i "/P cmake_install.cmake/s@\tbin/cmake@\t/bin/cmake@g" Makefile
        make
        make DESTDIR=${SYSDIR}/sysroot install
    popd
popd
```

#### Man-DB
```sh
tar xvf ${DOWNLOADDIR}/man-db-2.9.4.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/man-db-2.9.4
	rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
	automake --add-missing
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
	            --host=${CROSS_TARGET} --sysconfdir=/etc --disable-setuid \
	            --enable-cache-owner=bin --with-browser=/usr/bin/lynx \
	            --with-vgrind=/usr/bin/vgrind --with-grap=/usr/bin/grap
	make
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Tar
```sh
tar xvf ${DOWNLOADDIR}/tar-1.34.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/tar-1.34
	FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Texinfo
```sh
tar xvf ${DOWNLOADDIR}/texinfo-6.7.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/texinfo-6.7
	for i in $(dirname $(find -name "config.sub"))
	do
		rm ./$i/config.{sub,guess}
		pushd $(dirname ./$i)
			automake --add-missing
		popd
	done
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make
	make DESTDIR=${SYSDIR}/sysroot install
	make DESTDIR=${SYSDIR}/sysroot TEXMF=/usr/share/texmf install-tex
popd
```

#### VIM
```sh
tar xvf ${DOWNLOADDIR}/v8.2.2879.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/vim-8.2.2879
	echo'#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
	cat> src/auto/config.cache << EOF
	vim_cv_getcwd_broken=no
	vim_cv_toupper_broken=no
	vim_cv_terminfo=yes
	vim_cv_tgetent=zero
	vim_cv_stat_ignores_slash=no
	vim_cv_memmove_handles_overlap=yes
	EOF
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET} --with-tlib=ncurses
	make
	make DESTDIR=${SYSDIR}/sysroot STRIP=${CROSS_TARGET}-strip install
	ln -sv vim ${SYSDIR}/sysroot/usr/bin/vi
popd
```

    During the production of VIM, some parameters need to be set to avoid  errors during automatic detection. However, the parameter setting file of VIM has a default file path, namely "src/auto/config.cache". Just write the parameters and values in the file, configure The configuration script will automatically read from this file.

    After installing VIM, we can configure the default settings file of VIM. The setting steps are as follows:

```sh
cat> ${SYSDIR}/sysroot/etc/vimrc << "EOF"
let skip_defaults_vim=1 
set nocompatible
set backspace=2
set mouse=
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif
EOF
```
    Changing the setting content is mainly to set some basic interface and operating characteristics, such as the conversion of Tab into several spaces, the background color of different terminals, and so on.

#### Util-Linux
```sh
tar xvf ${DOWNLOADDIR}/util-linux-2.36.2.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/util-linux-2.36.2
	cp ${SYSDIR}/sysroot/usr/share/automake-1.16/config.* config/
	./configure --build=${CROSS_HOST} --host=${CROSS_TARGET} \
        ADJTIME_PATH=/var/lib/hwclock/adjtime \
        --libdir=/usr/lib64 \
        --disable-chfn-chsh --disable-login --disable-nologin \
        --disable-su --disable-setpriv --disable-runuser \
        --disable-pylibmount --disable-static --without-python \
        --without-systemd --disable-makeinstall-chown \
        runstatedir=/run
	make
	make DESTDIR=${SYSDIR}/sysroot install
	rm -v ${SYSDIR}/sysroot/usr/lib64/lib{blkid,fdisk,mount,smartcols,uuid}.la
popd
```

    Util-Linux comes with a large number of commands and libraries. Since some commands have been provided in other software packages, use option parameters to turn off the compilation and installation of these commands.

#### Systemd
    Systemd uses the meson command to perform the configuration phase operation. This command is obviously different from other common configure scripts. Therefore, when cross-compilation is currently required, a completely different operation step will be used, which will be explained below.

```sh
tar xvf ${DOWNLOADDIR}/systemd-249.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/systemd-249
	patch -Np1 -i ${DOWNLOADDIR}/systemd-249-add-loongarch64.patch
	pushd src/basic
        python3 missing_syscalls.py missing_syscall_def.h $(ls syscalls-*.txt)
	popd
	sed -i's/GROUP="render"/GROUP="video"/' rules.d/50-udev-default.rules.in
```

    The above steps are to decompress the Systemd source code and apply patches that support LoongArch64, and make necessary corrections to the code.

    The next step is to make a text file for the meson command to cross-compile and configure. The steps are as follows:

```sh
pushd ${BUILDDIR}
echo "[binaries]"> meson-cross.txt
echo "c ='${CROSS_TARGET}-gcc'" >> meson-cross.txt
echo "cpp ='${CROSS_TARGET}-g++'" >> meson-cross.txt
echo "ar ='${CROSS_TARGET}-ar'" >> meson-cross.txt
echo "strip ='${CROSS_TARGET}-strip'" >> meson-cross.txt
echo "pkgconfig ='${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-pkg-config'" >> meson-cross.txt
echo "[properties]" >> meson-cross.txt
echo "sys_root ='${SYSDIR}/sysroot'" >> meson-cross.txt
cat >> meson-cross.txt << "EOF"
[host_machine]
system ='linux'
cpu_family ='loongarch64'
cpu ='loongarch64'
endian ='little'
EOF
popd
```
    After the above steps are completed, a meson-cross.txt file will be generated in the ${BUILDDIR} directory. This file contains the name of the target architecture when compiling Systemd, the system, the tool chain commands used, and the compilation parameters, etc., so that in the next It is enough to quote this file in the configuration phase of.

    The following are the steps to configure and compile:

```sh
	mkdir -p build
	pushd build
		meson --prefix=/usr --libdir=/usr/lib64 --sysconfdir=/etc --localstatedir=/var \
		      -Dblkid=true -Dbuildtype=release -Ddefault-dnssec=no -Dfirstboot=false \
		      -Dinstall-tests=false -Dldconfig=false -Dsysusers=false -Db_lto=false \
		      -Drpmmacrosdir=no -Dhomed=false -Duserdb=false -Dman=false -Dmode=release \
		      --cross-file ${BUILDDIR}/meson-cross.txt ..
		ninja
		DESTDIR=${SYSDIR}/sysroot ninja install
	popd
popd
```

    The newer version of Systemd no longer uses the make command to compile, and uses the ninja command to compile with meson. After compiling, the ninja command is also used to install the software package.

    The installation command supports the "DESTDIR" variable setting, but unlike the make command, the "DESTDIR" variable needs to be written in front of the ninja command. The installation parameter is "install". After the command is executed, the software package will also be installed to the target system. Directory.


#### D-Bus
```sh
tar xvf ${DOWNLOADDIR}/dbus-1.12.20.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/dbus-1.12.20
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
	            --host=${CROSS_TARGET} --sysconfdir=/etc --localstatedir=/var \
	            --disable-static --disable-doxygen-docs --disable-xml-docs \
	            --with-console-auth-dir=/run/console \
	            --with-system-pid-file=/run/dbus/pid \
	            --with-system-socket=/run/dbus/system_bus_socket
	make
	make DESTDIR=${SYSDIR}/sysroot install
	ln -sfv /etc/machine-id ${SYSDIR}/sysroot/var/lib/dbus
popd
```

#### Procps-ng
```sh
tar xvf ${DOWNLOADDIR}/procps-ng-3.3.17.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/procps-3.3.17
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
	            --host=${CROSS_TARGET} --disable-static --disable-kill --with-systemd \
	            ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes
	make 
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

    The Procps-ng package will also have parameter detection errors in the cross-compilation mode, and the parameters and values need to be specified during the configuration phase.

#### E2fsprogs
```sh
tar xvf ${DOWNLOADDIR}/e2fsprogs-1.46.2.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/e2fsprogs-1.46.2
	cp ${SYSDIR}/sysroot/usr/share/automake-1.16/config.* config/
	mkdir -v build
	pushd build
		../configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
		             --host=${CROSS_TARGET} --sysconfdir=/etc \
		             --enable-elf-shlibs--disable-libblkid \
		             --disable-libuuid --disable-uuidd --disable-fsck
		make 
		make DESTDIR=${SYSDIR}/sysroot install
		rm -fv ${SYSDIR}/sysroot/usr/lib64/{libcom_err,libe2p,libext2fs,libss}.la
	popd
popd
```

#### OpenSSH
```sh
tar xvf ${DOWNLOADDIR}/openssh-8.6p1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/openssh-8.6p1
	rm config.{sub,guess}
	automake --add-missing
	./configure --prefix=/usr --libdir=/usr/lib64 --sysconfdir=/etc/ssh \
	            --build=${CROSS_HOST} --host=${CROSS_TARGET} \
	            --disable-strip --with-md5-passwords \
	            --with-privsep-path=/var/lib/sshd \
	            --with-default-path=/usr/bin \
 	            --with-superuser-path=/usr/sbin:/usr/bin \
	            --with-pid-dir=/run
	make 
	make DESTDIR=${SYSDIR}/sysroot install-nokeys host-key
	install -v -m755 contrib/ssh-copy-id ${SYSDIR}/sysroot/usr/bin
popd
```

#### PCIUtils
```sh
tar xvf ${DOWNLOADDIR}/pciutils-3.7.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/pciutils-3.7.0
	make CROSS_COMPILE="${CROSS_TARGET}-" HOST="${CROSS_TARGET}" PREFIX=/usr 
	make CROSS_COMPILE="${CROSS_TARGET}-" HOST="${CROSS_TARGET}" PREFIX=/usr \
	     STRIP="" DESTDIR=${SYSDIR}/sysroot install
popd
```

#### WGet
```sh
tar xvf ${DOWNLOADDIR}/wget-1.21.1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/wget-1.21.1
	rm build-aux/config.{sub,guess}
	automake --add-missing
	./configure --prefix=/usr --sysconfdir=/etc \
	            --build=${CROSS_HOST} --host=${CROSS_TARGET} \
	            --with-ssl=openssl
	make 
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Install the certificate
```sh
tar xvf ${DOWNLOADDIR}/ssl-certs.tar.gz -C ${BUILDDIR}
pushd certs
    cp -a * ${SYSDIR}/sysroot/etc/ssl/certs/
popd
```

#### Inetutils
```sh
tar xvf ${DOWNLOADDIR}/inetutils-2.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/inetutils-2.1
	sed -i "/PATH_PROCNET_DEV/s@no@/proc/net/dev@g" paths
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET} \
	            --disable-logger --disable-whois --disable-rcp \
	            --disable-rexec --disable-rlogin --disable-rsh \
	            --disable-servers
	make 
	make DESTDIR=${SYSDIR}/sysroot install
	mv -v ${SYSDIR}/sysroot/usr/{,s}bin/ifconfig
	chmod -v +x ${SYSDIR}/sysroot/usr/bin/{ping{,6},traceroute}
popd
```

#### DHCPCD
```sh
tar xvf ${DOWNLOADDIR}/dhcpcd-9.4.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/dhcpcd-9.4.0
	./configure --prefix=/usr --sysconfdir=/etc --build=${CROSS_HOST} \
	            --host=${CROSS_TARGET} --disable-privsep
	make 
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Instructions
    When the system does this, it can be used as a simple and usable state. Then you can jump directly to Part 5 ("Start the relevant software package") to continue the subsequent build process, but if you feel that the system is not enough, you can continue The following production steps.

### 4.3 More packages
    All the software packages in this section do not need to be built. You can choose them according to your needs, but you need to pay attention to the dependencies between the software packages. If you find that a certain software package is selectively produced lacking necessary dependencies, then you firstly have to make the packages which build package depends on.


#### Wireless-Tools
```sh
tar xvf ${DOWNLOADDIR}/wireless_tools.29.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/wireless_tools.29
    patch -Np1 -i ${DOWNLOADDIR}/wireless_tools-29-fix_iwlist_scanning-1.patch
    sed -i.orig "/^INSTALL_LIB/s@/lib/@/lib64/@g" Makefile
	make CC=${CROSS_TARGET}-gcc 
	make PREFIX=${SYSDIR}/sysroot/usr INSTALL_MAN=${SYSDIR}/sysroot/usr/share/man install
popd
```

#### Libnl
```sh
tar xvf ${DOWNLOADDIR}/libnl-3.5.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libnl-3.5.0
	rm build-aux/config.{sub,guess}
	automake --add-missing
	./configure --prefix=/usr --sysconfdir=/etc --libdir=/usr/lib64 \
	            --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make 
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Sudo
```sh
tar xvf ${DOWNLOADDIR}/sudo-1.9.7p2.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/sudo-1.9.7p2
    ./configure --prefix=/usr --libexecdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --with-secure-path --with-all-insults --with-env-editor \
                --with-passprompt="[sudo] password for %p: "
    sed -i "/^install_uid/s@= 0@= $(id -u)@g" Makefile
    sed -i "/^install_gid/s@= 0@= $(id -u)@g" Makefile
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### SQLite3
```sh
unzip ${DOWNLOADDIR}/sqlite-src-3360000.zip -d ${BUILDDIR}
pushd ${BUILDDIR}/sqlite-src-3360000
    cp ${SYSDIR}/cross-tools/share/automake-*/config.* ./
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --enable-fts5 \
                CPPFLAGS="-DSQLITE_ENABLE_FTS3=1 \
                          -DSQLITE_ENABLE_FTS4=1 \
                          -DSQLITE_ENABLE_COLUMN_METADATA=1 \
                          -DSQLITE_ENABLE_UNLOCK_NOTIFY=1 \
                          -DSQLITE_ENABLE_DBSTAT_VTAB=1 \
                          -DSQLITE_SECURE_DELETE=1 \
                          -DSQLITE_ENABLE_FTS3_TOKENIZER=1"
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### NSPR
```sh
tar xvf ${DOWNLOADDIR}/nspr-4.32.tar.gz
pushd ${BUILDDIR}/nspr-4.32/nspr
    patch -Np2 -i ${DOWNLOADDIR}/nspr-4.32-add-loongarch64.patch
    cp ${SYSDIR}/cross-tools/share/automake-*/config.* build/autoconf/
    ./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
                --host=${CROSS_TARGET} --with-mozilla \
                --with-pthreads --enable-64bit
    make CC="gcc" -C config
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### NSS
```sh
tar xvf ${DOWNLOADDIR}/nss-3.69.tar.gz
pushd ${BUILDDIR}/nss-3.69/nss
    make CC="gcc" -C coreconf/nsinstall BUILD_OPT=1 USE_64=1 \
         CPU_ARCH="loongarch64" CROSS_COMPILE=1 NSS_ENABLE_WERROR=0 OS_TEST="loongarch64"
    make NATIVE_CC="gcc" CC="${CROSS_TARGET}-gcc" CCC="${CROSS_TARGET}-g++" \
         BUILD_OPT=1 USE_64=1 CPU_ARCH="loongarch64" CROSS_COMPILE=1 \
         USE_SYSTEM_ZLIB=1 NSS_USE_SYSTEM_SQLITE=1 NSS_ENABLE_WERROR=0 \
         NSPR_INCLUDE_DIR=${SYSDIR}/sysroot/usr/include/nspr OS_TEST="loongarch64" -j1

    cat pkg/pkg-config/nss-config.in | sed -e "s,@prefix@,/usr,g" \
        -e "s,@MOD_MAJOR_VERSION@,$(cat lib/util/nssutil.h \
            | grep "#define.*NSSUTIL_VMAJOR" | awk'{print $3}'),g" \
        -e "s,@MOD_MINOR_VERSION@,$(cat lib/util/nssutil.h \
            | grep "#define.*NSSUTIL_VMINOR" | awk'{print $3}'),g" \
        -e "s,@MOD_PATCH_VERSION@,$(cat lib/util/nssutil.h \
            | grep "#define.*NSSUTIL_VPATCH" | awk'{print $3}'),g" \
        > ${SYSDIR}/sysroot/usr/bin/nss-config

    cat pkg/pkg-config/nss.pc.in | sed -e "s,%prefix%,/usr,g" \
        -e's,%exec_prefix%,${prefix},g' -e "s,%libdir%,/usr/lib64,g" \
        -e's,%includedir%,${prefix}/include/nss,g' \
        -e "s,%NSS_VERSION%,$(cat lib/util/nssutil.h \
            | grep "#define.*NSSUTIL_VERSION" | awk'{print $3}'),g" \
        -e "s,%NSPR_VERSION%,$(cat ${SYSDIR}/sysroot/usr/include/nspr/prinit.h \
            | grep "#define.*PR_VERSION" | awk'{print $3}'),g" \
        > ${SYSDIR}/sysroot/usr/lib64/pkgconfig/nss.pc
popd
pushd ${BUILDDIR}/nss-3.69/dist
    install -v -m755 Linux*/lib/*.so ${SYSDIR}/sysroot/usr/lib64
    install -v -m644 Linux*/lib/libcrmf.a ${SYSDIR}/sysroot/usr/lib64
    install -v -m755 -d ${SYSDIR}/sysroot/usr/include/nss
    cp -v -RL {public,private}/nss/* ${SYSDIR}/sysroot/usr/include/nss
    chmod -v 644 ${SYSDIR}/sysroot/usr/include/nss/*
    install -v -m755 Linux*/bin/{certutil,pk12util} ${SYSDIR}/sysroot/usr/bin
popd
```

#### ICU4C
```sh
tar xvf ${DOWNLOADDIR}/icu4c-69_1-src.tgz
pushd ${BUILDDIR}/icu/source
    patch -Np2 -i ${DOWNLOADDIR}/icu4c-69-add-loongarch.patch
    touch config/icucross.mk
    touch config/icucross.inc
    sed -i'/^PKGDATA/s@$(TOOLBINDIR)@/bin@g' data/Makefile.in
    sed -i'/INVOKE/s@$(TOOLBINDIR)@/bin@g' data/Makefile.in extra/uconv/Makefile.in
    sed -i'/INVOKE/s@/bin/icupkg@/sbin/icupkg@g' data/Makefile.in
    ./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
                --host=${CROSS_TARGET} --with-cross-build=${PWD}
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Libxml2
```sh
tar xvf ${DOWNLOADDIR}/libxml2-2.9.12.tar.gz
pushd ${BUILDDIR}/libxml2-2.9.12
    rm config.{sub,guess}
    automake -a
    ./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
                --host=${CROSS_TARGET} --with-history --with-icu \
                --with-python=${SYSDIR}/cross-tools/bin/python3
    make
    make DESTDIR=${SYSDIR}/sysroot install
    rm ${SYSDIR}/sysroot/usr/lib64/libxml2.la
popd
```

#### Libxslt
```sh
tar xvf ${DOWNLOADDIR}/libxslt-1.1.34.tar.gz
pushd ${BUILDDIR}/libxslt-1.1.34
    rm config.{sub,guess}
    automake -a
    ./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
                --host=${CROSS_TARGET} --without-python
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### WPA_Supplicant
```sh
tar xvf ${DOWNLOADDIR}/wpa_supplicant-2.9.tar.gz
pushd ${BUILDDIR}/wpa_supplicant-2.9/wpa_supplicant
    cat> .config << "EOF"
    CONFIG_BACKEND=file
    CONFIG_CTRL_IFACE=y
    CONFIG_DEBUG_FILE=y
    CONFIG_DRIVER_NL80211=y
    CONFIG_DRIVER_WEXT=y
    CONFIG_DRIVER_WIRED=y
    CONFIG_EAP_GTC=y
    CONFIG_EAP_LEAP=y
    CONFIG_EAP_MD5=y
    CONFIG_EAP_MSCHAPV2=y
    CONFIG_EAP_OTP=y
    CONFIG_EAP_PEAP=y
    CONFIG_EAP_TLS=y
    CONFIG_EAP_TTLS=y
    CONFIG_IEEE8021X_EAPOL=y
    CONFIG_IPV6=y
    CONFIG_LIBNL32=y
    CONFIG_PEERKEY=y
    CONFIG_PKCS12=y
    CONFIG_READLINE=y
    CONFIG_SMARTCARD=y
    CONFIG_WPS=y
    CONFIG_CTRL_IFACE_DBUS=y
    CONFIG_CTRL_IFACE_DBUS_NEW=y
    CONFIG_CTRL_IFACE_DBUS_INTRO=y
    EOF
    make CC="${CROSS_TARGET}-gcc" PKG_CONFIG=${CROSS_TARGET}-pkg-config \
         BINDIR=/usr/sbin LIBDIR=/usr/lib64
    install -v -m755 wpa_{cli,passphrase,supplicant} ${SYSDIR}/sysroot/usr/sbin/
    install -v -m644 dbus/fi.w1.wpa_supplicant1.service \
                     ${SYSDIR}/sysroot/usr/share/dbus-1/system-services/
    install -v -d -m755 ${SYSDIR}/sysroot/etc/dbus-1/system.d
    install -v -m644 dbus/dbus-wpa_supplicant.conf \
                     ${SYSDIR}/sysroot/etc/dbus-1/system.d/wpa_supplicant.conf
popd
```

#### Python3
```sh
tar xvf ${DOWNLOADDIR}/Python-3.9.6.tgz -C ${BUILDDIR}
pushd ${BUILDDIR}/Python-3.9.6
	./configure --prefix=/usr --libdir=/usr/lib64 \
	            --build=${CROSS_HOST} --host=${CROSS_TARGET} --enable-shared \
	            --with-system-expat --with-system-ffi --with-ensurepip=install \
	            --enable-optimizations \
	            ac_cv_buggy_getaddrinfo=no ac_cv_file__dev_ptmx=yes ac_cv_file__dev_ptc=no
	make
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Python-Pip
```sh
tar xvf ${DOWNLOADDIR}/pip-21.2.4.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/pip-21.2.4
    ${SYSDIR}/cross-tools/bin/python3 setup.py build
    ${SYSDIR}/cross-tools/bin/python3 setup.py install --prefix=${SYSDIR}/sysroot/usr
popd
```

#### Python-Setuptools
```sh
tar xvf ${DOWNLOADDIR}/setuptools-57.4.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/setuptools-57.4.0
    ${SYSDIR}/cross-tools/bin/python3 setup.py build
    ${SYSDIR}/cross-tools/bin/python3 setup.py install --prefix=${SYSDIR}/sysroot/usr
popd
```

#### Meson
```sh
tar xvf ${DOWNLOADDIR}/meson-0.59.1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/meson-0.59.1
    ${SYSDIR}/cross-tools/bin/python3 setup.py build
    ${SYSDIR}/cross-tools/bin/python3 setup.py install --prefix=${SYSDIR}/sysroot/usr
popd

```

#### Ninja
```sh
tar xvf ${DOWNLOADDIR}/ninja-1.10.2.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/ninja-1.10.2
    CXX="${CROSS_TARGET}-g++" AR="${CROSS_TARGET}-ar" \
    ${SYSDIR}/cross-tools/bin/python3 configure.py
    ninja
    install -vm755 ninja ${SYSDIR}/sysroot/usr/bin/
popd
```

#### Perl5
```sh
tar xvf ${DOWNLOADDIR}/perl-5.34.0.tar.gz -C ${BUILDDIR}
pushd perl-5.34.0
	sh Configure -des -Dprefix=/usr -Dvendorprefix=/usr \
	             -Dprivlib=/usr/lib/perl5/5.34/core_perl \
	             -Darchlib=/usr/lib64/perl5/5.34/core_perl \
	             -Dsitelib=/usr/lib/perl5/5.34/site_perl \
	             -Dsitearch=/usr/lib64/perl5/5.34/site_perl \
	             -Dvendorlib=/usr/lib/perl5/5.34/vendor_perl \
	             -Dvendorarch=/usr/lib64/perl5/5.34/vendor_perl \
	             -Dman1dir=/usr/share/man/man1 -Dman3dir=/usr/share/man/man3 \
	             -Dpager="/usr/bin/less -isR" -Duseshrplib -Dusethreads \
	             -Dusecrosscompile
	cp ${DOWNLOADDIR}/perl-5.34.0-la-config.sh ./config.sh
	sed -i "/^cc=/s@'cc'@'${CROSS_TARGET}-gcc'@g" config.sh
	sed -i "/^ld=/s@'cc'@'${CROSS_TARGET}-gcc'@g" config.sh
	./Configure -S
	make depend
	make
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### XML-Parser
```sh
tar xvf ${DOWNLOADDIR}/XML-Parser-2.46.tar.gz -C ${BUILDDIR}
pushd XML-Parser-2.46
    ${SYSDIR}/cross-tools/bin/perl Makefile.PL
    sed -i "/^INSTALL/s@${SYSDIR}/cross-tools@/usr@g" Makefile
    make CC=${CROSS_TARGET}-gcc LD=${CROSS_TARGET}-gcc
    make CC=${CROSS_TARGET}-gcc LD=${CROSS_TARGET}-gcc DESTDIR=${SYSDIR}/sysroot install
popd
```

#### GPM
    The GPM package provides tools for using the mouse in a text environment.

```sh
tar xvf ${DOWNLOADDIR}/gpm-1.20.7.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/gpm-1.20.7
    patch -Np1 -i ${DOWNLOADDIR}/gpm-1.20.7-consolidated-1.patch
    patch -Np1 -i ${DOWNLOADDIR}/gpm-1.20.1-weak-wgetch.patch
    ./autogen.sh
    ./configure --prefix=/usr --libdir=/usr/lib64 --sysconfdir=/etc \
	            --build=${CROSS_HOST} --host=${CROSS_TARGET}
    make
    make DESTDIR=${SYSDIR}/sysroot install
    ln -sfv libgpm.so.2.1.0 ${SYSDIR}/sysroot/usr/lib64/libgpm.so
popd

cat> ${SYSDIR}/sysroot/etc/sysconfig/mouse << "EOF"
MDEVICE="/dev/input/mice"
PROTOCOL="imps2"
GPMOPTS=""
EOF

cat> ${SYSDIR}/sysroot/usr/lib/systemd/system/gpm.service << "EOF"
[Unit]
Description=Console Mouse manager

[Service]
ExecStart=/usr/sbin/gpm -m /dev/input/mice -t exps2
Type=forking
PIDFile=/run/gpm.pid

[Install]
WantedBy=multi-user.target
EOF

```

#### Libevent

```sh
tar xvf ${DOWNLOADDIR}/libevent-2.1.12-stable.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libevent-2.1.12-stable
    rm build-aux/config.{guess,sub}
    automake -a
    ./configure --prefix=/usr --libdir=/usr/lib64 \
	            --build=${CROSS_HOST} --host=${CROSS_TARGET}
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Links
    Links is a simple Internet browser in a terminal environment.

```sh
tar xvf ${DOWNLOADDIR}/links-2.23.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/links-2.23
    CC="${CROSS_TARGET}-gcc" \
    ./configure --prefix=/usr --libdir=/usr/lib64 \
	            --build=${CROSS_HOST} --host=${CROSS_TARGET}
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Doxygen
```sh
tar xvf ${DOWNLOADDIR}/doxygen-1.9.2.src.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/doxygen-1.9.2
    mkdir build
    pushd build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
              -DCMAKE_INSTALL_PREFIX=/usr -Wno-dev ..
        make
        make DESTDIR=${SYSDIR}/sysroot install
    popd
popd
```

#### Git
```sh
tar xvf ${DOWNLOADDIR}/git-2.33.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/git-2.33.0
    ./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --with-gitconfig=/etc/gitconfig --with-python=python3 --without-iconv \
                 ac_cv_fread_reads_directories=yes ac_cv_snprintf_returns_bogus=no
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### GDB
    The GDB compiled this time is provided by the Binutils package.
```sh
tar xvf ${DOWNLOADDIR}/binutils-2.37.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/binutils-2.37
	mkdir build
	pushd build
		../configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
		             --host=${CROSS_TARGET} --enable-shared --disable-werror \
		             --with-system-zlib --enable-64-bit-bfd --with-system-readline
		make all-gdb all-gdbserver
		make DESTDIR=${SYSDIR}/sysroot install-gdb install-gdbserver
	popd
popd
```

#### CTags
tar xvf ${DOWNLOADDIR}/ctags-5.8.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/ctags-5.8
    patch -Np1 -i ${DOWNLOADDIR}/ctags-5.8-fix_form_fedora.patch
    patch -Np1 -i ${DOWNLOADDIR}/ctags-5.8-for-gcc_12.patch
    ./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd

#### Dosfstools
```sh
tar xvf ${DOWNLOADDIR}/dosfstools-4.2.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/dosfstools-4.2
    ./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --enable-compat-symlinks --mandir=/usr/share/man
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Inih
```sh
tar xvf ${DOWNLOADDIR}/inih-r53.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/inih-r53
    mkdir build
    pushd build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Xfsprogs
```sh
tar xvf ${DOWNLOADDIR}/xfsprogs-5.12.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/xfsprogs-5.12.0
    ./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --mandir=/usr/share/man
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Libaio
```sh
tar xvf ${DOWNLOADDIR}/libaio_0.3.112.orig.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libaio-0.3.112
    make CC="${CROSS_TARGET}-gcc"
    make DESTDIR=${SYSDIR}/sysroot libdir=/usr/lib64 install
popd
```

#### Mdadm
```sh
tar xvf ${DOWNLOADDIR}/mdadm-4.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/mdadm-4.1
    sed's@-Werror@@' -i Makefile
    make CC="${CROSS_TARGET}-gcc"
    make DESTDIR=${SYSDIR}/sysroot PKG_CONFIG=${CROSS_TARGET}-pkg-config install
popd
```

#### LVM2
```sh
tar xvf ${DOWNLOADDIR}/LVM2.2.03.13.tgz -C ${BUILDDIR}
pushd ${BUILDDIR}/LVM2.2.03.13
    ./configure --prefix=/usr --libdir=/usr/lib64 --with-usrlibdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --enable-cmdlib --enable-pkgconfig --enable-udev_sync \
                ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### PCRE
```sh
tar xvf ${DOWNLOADDIR}/pcre-8.45.tar.bz2
pushd ${BUILDDIR}/pcre-8.45
    rm config.{sub,guess}
    automake -a
    ./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
                --host=${CROSS_TARGET} --enable-unicode-properties \
                --enable-pcre16 --enable-pcre32 \
                --enable-pcregrep-libz --enable-pcregrep-libbz2 \
                --enable-pcretest-libreadline
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Glib
```sh
tar xvf ${DOWNLOADDIR}/glib-2.69.2.tar.xz
pushd ${BUILDDIR}/glib-2.69.2
    mkdir build
    pushd build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release -Dman=true -Dselinux=disabled \
              --cross-file=${BUILDDIR}/meson-cross.txt \
              ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### UnRAR
```sh
tar xvf ${DOWNLOADDIR}/unrarsrc-6.0.7.tar.gz
pushd ${BUILDDIR}/unrar
    make CXX="${CROSS_TARGET}-g++" STRIP=${CROSS_TARGET}-strip -f makefile
    install -v -m755 unrar ${SYSDIR}/sysroot/usr/bin
popd
```

#### Zip
```sh
tar xvf ${DOWNLOADDIR}/zip30.tgz
pushd ${BUILDDIR}/zip30
    make -f unix/Makefile CC="${CROSS_TARGET}-gcc -DLARGE_FILE_SUPPORT" generic
    make prefix=${SYSDIR}/sysroot/usr MANDIR=${SYSDIR}/sysroot/usr/share/man/man1 \
         -f unix/Makefile install
popd
```

#### UnZip
```sh
tar xvf ${DOWNLOADDIR}/unzip60.tgz
pushd ${BUILDDIR}/unzip60
    sed -i "s@-DNO_LCHMOD@@g" unix/configure
    make -f unix/Makefile CC="${CROSS_TARGET}-gcc \
            -DLARGE_FILE_SUPPORT -DUNICODE_WCHAR -DUNICODE_SUPPORT" generic
    make prefix=${SYSDIR}/sysroot/usr MANDIR=${SYSDIR}/sysroot/usr/share/man/man1 \
         -f unix/Makefile install
popd
```

#### Libmnl
```sh
tar xvf ${DOWNLOADDIR}/libmnl-1.0.4.tar.bz2
pushd ${BUILDDIR}/libmnl-1.0.4
    ./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
                --host=${CROSS_TARGET}
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Ethtool
```sh
tar xvf ${DOWNLOADDIR}/ethtool-5.13.tar.xz
pushd ${BUILDDIR}/ethtool-5.13
    ./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Boost
```sh
tar xvf ${DOWNLOADDIR}/boost_1_77_0.tar.bz2
pushd ${BUILDDIR}/boost_1_77_0
./bootstrap.sh --prefix=/usr --libdir=/usr/lib64 --with-python=python3
sed -i "/using gcc/s@using gcc@&: loongarch64: ${CROSS_TARGET}-gcc@g" project-config.jam
./b2 stage threading=multi link=shared address-model=64 toolset=gcc-loongarch64
./b2 install --prefix=${SYSDIR}/sysroot/usr --libdir=${SYSDIR}/sysroot/usr/lib64 \
             threading=multi link=shared address-model=64 toolset=gcc-loongarch64
popd
```

#### Libsigc++3
```sh
tar xvf ${DOWNLOADDIR}/libsigc++-3.0.7.tar.xz
pushd ${BUILDDIR}/libsigc++-3.0.7
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Glibmm
```sh
tar xvf ${DOWNLOADDIR}/glibmm-2.68.1.tar.xz
pushd ${BUILDDIR}/glibmm-2.68.1
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Libpng
```sh
tar xvf ${DOWNLOADDIR}/libpng-1.6.37.tar.xz
pushd ${BUILDDIR}/libpng-1.6.37
    gzip -cd ${DOWNLOADDIR}/libpng-1.6.37-apng.patch.gz | patch -p1
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET}
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### LibJPEG-Turbo
```sh
tar xvf ${DOWNLOADDIR}/libjpeg-turbo-2.1.1.tar.gz
pushd ${BUILDDIR}/libjpeg-turbo-2.1.1
    mkdir build
    pushd build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -DCMAKE_INSTALL_PREFIX=/usr \
              -DCMAKE_BUILD_TYPE=RELEASE -DWITH_JPEG8=ON \
              -DCMAKE_INSTALL_DEFAULT_LIBDIR=lib64 ..
        make
        make DESTDIR=${SYSDIR}/sysroot install
    popd
popd
```

#### TIFF
```sh
tar xvf ${DOWNLOADDIR}/tiff-4.3.0.tar.gz
pushd ${BUILDDIR}/tiff-4.3.0
    mkdir cross-build
    pushd cross-build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -DCMAKE_INSTALL_PREFIX=/usr \
              -DCMAKE_BUILD_TYPE=RELEASE \
              -DCMAKE_INSTALL_LIBDIR=lib64 ..
        make
        make DESTDIR=${SYSDIR}/sysroot install
        sed -i /Version/s/\$/$(cat ../VERSION)/ \
               ${SYSDIR}/sysroot/usr/lib64/pkgconfig/libtiff-4.pc
    popd
popd
```

#### LCMS2
```sh
tar xvf ${DOWNLOADDIR}/lcms2-2.12.tar.gz
pushd ${BUILDDIR}/lcms2-2.12
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET}
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### OpenJPEG
```sh
tar xvf ${DOWNLOADDIR}/openjpeg-2.4.0.tar.gz
pushd ${BUILDDIR}/openjpeg-2.4.0
    mkdir cross-build
    pushd cross-build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -DCMAKE_INSTALL_PREFIX=/usr \
              -DCMAKE_BUILD_TYPE=RELEASE \
              -DOPENJPEG_INSTALL_LIB_DIR=lib64 ..
        make
        make DESTDIR=${SYSDIR}/sysroot install
    popd
popd
```

#### Jasper
```sh
tar xvf ${DOWNLOADDIR}/jasper-2.0.33.tar.gz
pushd ${BUILDDIR}/jasper-2.0.33
    mkdir cross-build
    pushd cross-build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -DCMAKE_INSTALL_PREFIX=/usr \
              -DCMAKE_BUILD_TYPE=Release \
              -DJAS_ENABLE_DOC=NO ..
        make
        make DESTDIR=${SYSDIR}/sysroot install
    popd
popd
```

#### LibRaw
```sh
tar xvf ${DOWNLOADDIR}/LibRaw-0.20.2.tar.gz
pushd ${BUILDDIR}/LibRaw-0.20.2
    autoreconf -fiv
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --enable-jpeg --enable-jasper --enable-lcms
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Libmng
```sh
tar xvf ${DOWNLOADDIR}/libmng-2.0.3.tar.xz
pushd ${BUILDDIR}/libmng-2.0.3
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET}
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### FreeType
```sh
tar xvf ${DOWNLOADDIR}/freetype-2.11.0.tar.xz
pushd ${BUILDDIR}/freetype-2.11.0
    sed -ri "s:.*(AUX_MODULES.*valid):\1:" modules.cfg
    sed -r "s:.*(#.*SUBPIXEL_RENDERING) .*:\1:" \
           -i include/freetype/config/ftoption.h
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --enable-freetype-config
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### HarfBuzz
```sh
tar xvf ${DOWNLOADDIR}/harfbuzz-2.8.2.tar.xz
pushd ${BUILDDIR}/harfbuzz-2.8.2
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release -Dbenchmark=disabled \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### FreeType (second time)
    This compilation is to add support for HarfBuzz.
```sh
tar xvf ${DOWNLOADDIR}/freetype-2.11.0.tar.xz
pushd ${BUILDDIR}/freetype-2.11.0
    sed -ri "s:.*(AUX_MODULES.*valid):\1:" modules.cfg
    sed -r "s:.*(#.*SUBPIXEL_RENDERING) .*:\1:" \
           -i include/freetype/config/ftoption.h
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --enable-freetype-config
    make
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libfreetype.la
popd
```

#### Fontconfig
```sh
tar xvf ${DOWNLOADDIR}/fontconfig-2.13.1.tar.bz2
pushd ${BUILDDIR}/fontconfig-2.13.1
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --sysconfdir=/etc --localstatedir=/var
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Fribidi
```sh
tar xvf ${DOWNLOADDIR}/fribidi-1.0.10.tar.xz
pushd ${BUILDDIR}/fribidi-1.0.10
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Nettle
```sh
tar xvf ${DOWNLOADDIR}/nettle-3.7.3.tar.gz
pushd ${BUILDDIR}/nettle-3.7.3
    cp ${SYSDIR}/sysroot/usr/share/automake-*/config.* ./
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET}
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Libunistring
```sh
tar xvf ${DOWNLOADDIR}/libunistring-0.9.10.tar.xz
pushd ${BUILDDIR}/libunistring-0.9.10
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET}
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Libtasn1
```sh
tar xvf ${DOWNLOADDIR}/libtasn1-4.17.0.tar.gz
pushd ${BUILDDIR}/libtasn1-4.17.0
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET}
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### P11-Kit
```sh
tar xvf ${DOWNLOADDIR}/p11-kit-0.24.0.tar.xz
pushd ${BUILDDIR}/p11-kit-0.24.0
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              -Dtrust_paths=/etc/pki/anchors \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### GnuTLS
```sh
tar xvf ${DOWNLOADDIR}/gnutls-3.7.2.tar.xz
pushd ${BUILDDIR}/gnutls-3.7.2
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --enable-openssl-compatibility --enable-ssl3-support \
                --with-default-trust-store-pkcs11="pkcs11:"
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Vala
```sh
tar xvf ${DOWNLOADDIR}/vala-0.53.1.tar.xz
pushd ${BUILDDIR}/vala-0.53.1
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --disable-valadoc
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### LibUSB
```sh
tar xvf ${DOWNLOADDIR}/libusb-1.0.24.tar.bz2
pushd ${BUILDDIR}/libusb-1.0.24
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET}
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### USBUtils
```sh
tar xvf ${DOWNLOADDIR}/usbutils-014.tar.xz
pushd ${BUILDDIR}/usbutils-014
   ./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --datadir=/usr/share/hwdata
    make
    make DESTDIR=${SYSDIR}/sysroot install
    mkdir -v ${SYSDIR}/sysroot/usr/share/hwdata/
    wget http://www.linux-usb.org/usb.ids -O ${SYSDIR}/sysroot/usr/share/hwdata/usb.ids
popd
```

#### Gobject-Introspection
```sh
tar xvf ${DOWNLOADDIR}/gobject-introspection-1.68.0.tar.xz
pushd ${BUILDDIR}/gobject-introspection-1.68.0
    sed -i "/gircompiler_command/s@gircompiler,@'/bin/g-ir-compiler',@g" gir/meson.build
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release -Dgi_cross_use_prebuilt_gi=true \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd

```

#### LibGUSB
```sh
tar xvf ${DOWNLOADDIR}/libgusb-0.3.7.tar.gz
pushd ${BUILDDIR}/libgusb-0.3.7
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release -Ddocs=false \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        sed -i -e "s@${SYSDIR}/sysroot\(.*\)g-ir-compiler@/bin/g-ir-compiler@g" build.ninja
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### LibGUdev
```sh
tar xvf ${DOWNLOADDIR}/libgudev-237.tar.xz
pushd ${BUILDDIR}/libgudev-237
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 --buildtype=release \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        sed -i -e "s@${SYSDIR}/sysroot\(.*\)g-ir-compiler@/bin/g-ir-compiler@g" build.ninja
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Compilation environment settings
    This step is not necessary, but can simplify the subsequent build steps.

```sh
export COMMON_CONFIG="--prefix=/usr --sysconfdir=/etc --localstatedir=/var --libdir=/usr/lib64 \
                      --build=${CROSS_HOST} --host=${CROSS_TARGET}"
export JOBS="-j8"
```
    Two environment variables are set here:

    "COMMON_CONFIG": Used to provide common parameters for the configuration software package.  
    "JOBS": Used to provide the number of parallel compilation settings for the make command.

#### Util-Macros
https://www.x.org/archive/individual/util/util-macros-1.19.3.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/util-macros-1.19.3.tar.gz
pushd ${BUILDDIR}/util-macros-1.19.3
    ./configure $COMMON_CONFIG
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### XorgProto
https://xorg.freedesktop.org/archive/individual/proto/xorgproto-2021.4.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/xorgproto-2021.4.tar.bz2
pushd ${BUILDDIR}/xorgproto-2021.4
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr -Dlegacy=true \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### LibXau
https://www.x.org/archive/individual/lib/libXau-1.0.9.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/libXau-1.0.9.tar.bz2
pushd ${BUILDDIR}/libXau-1.0.9
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### LibXdmcp
https://www.x.org/archive/individual/lib/libXdmcp-1.1.3.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/libXdmcp-1.1.3.tar.bz2
pushd ${BUILDDIR}/libXdmcp-1.1.3
    ./configure $COMMON_CONFIG
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### XCB-Proto
https://xorg.freedesktop.org/archive/individual/proto/xcb-proto-1.14.1.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/xcb-proto-1.14.1.tar.xz
pushd ${BUILDDIR}/xcb-proto-1.14.1
    PYTHON=python3 ./configure $COMMON_CONFIG
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Libxcb
https://xorg.freedesktop.org/archive/individual/lib/libxcb-1.14.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libxcb-1.14.tar.xz
pushd ${BUILDDIR}/libxcb-1.14
    rm build-aux/config.{sub,guess}
    automake -a
    PYTHON=python3 ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm ${SYSDIR}/sysroot/usr/lib64/libxcb.la
popd
```

#### Xorg-Libs
Xorg-libs-packages.txt

Download the software package:

```sh
cat ${DOWNLOADDIR}/Xorg-libs-packages.txt | \
    wget -i- -c -B https://www.x.org/pub/individual/lib/ -P ${DOWNLOADDIR}/
```

Build script:

```sh
mkdir -pv ${BUILDDIR}/xorg-lib
for package in xtrans libX11 libXext libFS libICE libSM libXScrnSaver \
               libXt libXScrnSaver libXt libXmu libXpm libXaw libXfixes \
               libXcomposite libXrender libXcursor libXdamage libfontenc \
               libXfont2 libXft libXi libXinerama libXrandr libXres \
               libXtst libXv libXvMC libXxf86dga libXxf86vm libdmx \
               libpciaccess libxkbfile libxshmfence
do
    tar xvf ${DOWNLOADDIR}/$(grep -E "$package-[0-9]" ${DOWNLOADDIR}/Xorg-libs-packages.txt) \
            -C ${BUILDDIR}/xorg-lib/
    pushd ${BUILDDIR}/xorg-lib/$(grep -E "$package-[0-9]" ${DOWNLOADDIR}/Xorg-libs-packages.txt | \
                                  awk -F'.tar''{ print $1 }')
        for i in $(dirname $(find -name "config.sub"))
        do
            pushd $(dirname ./$i)
                rm -f config.{sub,guess}
                automake --add-missing
            popd
        done
        case $package in
        libX11)
            ./configure $COMMON_CONFIG --with-keysymdefdir=${SYSDIR}/sysroot/usr/include/X11 --enable-malloc0returnsnull
            ;;
        *)
            ./configure $COMMON_CONFIG --enable-malloc0returnsnull
            ;;
        esac
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
        if [-f ${SYSDIR}/sysroot/usr/lib64/$package.la ]; then
            rm -v ${SYSDIR}/sysroot/usr/lib64/$package.la
        fi
    popd
done
```


#### Xorg-Xcb
Xorg-xcb-packages.txt

Download the package:

```sh
cat ${DOWNLOADDIR}/Xorg-xcb-packages.txt | \
    wget -i- -c -B https://xcb.freedesktop.org/dist/ -P ${DOWNLOADDIR}/
```

Build script:

```sh
mkdir -pv ${BUILDDIR}/xcb-package
for package in xcb-util xcb-util-image xcb-util-keysyms \
               xcb-util-renderutil xcb-util-wm xcb-util-cursor
do
    tar xvf ${DOWNLOADDIR}/$(grep -E "$package-[0-9]" ${DOWNLOADDIR}/Xorg-xcb-packages.txt) \
            -C ${BUILDDIR}/xcb-package/
    pushd ${BUILDDIR}/xcb-package/$(grep -E "$package-[0-9]" ${DOWNLOADDIR}/Xorg-xcb-packages.txt | \
                                  awk -F'.tar''{ print $1 }')
        for i in $(dirname $(find -name "config.sub"))
        do
            pushd $(dirname ./$i)
                rm -f config.{sub,guess}
                automake --add-missing
            popd
        done
        ./configure $COMMON_CONFIG
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
        rm -v ${SYSDIR}/sysroot/usr/lib64/libxcb-*.la
    popd
done
```

#### LibDRM
https://dri.freedesktop.org/libdrm/libdrm-2.4.107.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libdrm-2.4.107.tar.xz
pushd ${BUILDDIR}/libdrm-2.4.107
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              -Detnaviv=true -Dudev=true -Dvalgrind=false \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Wayland
https://wayland.freedesktop.org/releases/wayland-1.19.0.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/wayland-1.19.0.tar.xz
pushd ${BUILDDIR}/wayland-1.19.0
    mkdir cross-build
    pushd cross-build
        PKG_CONFIG_SYSROOT_DIR="" \
        meson --prefix=/usr --libdir=/usr/lib64 --buildtype=release \
              -Ddocumentation=false \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Wayland-Protocols
https://wayland.freedesktop.org/releases/wayland-protocols-1.22.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/wayland-protocols-1.22.tar.xz
pushd ${BUILDDIR}/wayland-protocols-1.22
    mkdir cross-build
    pushd cross-build
        PKG_CONFIG_SYSROOT_DIR="" \
        meson --prefix=/usr --libdir=/usr/lib64 --buildtype=release \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```


#### Mesa
https://archive.mesa3d.org/mesa-21.2.1.tar.xz
https://www.linuxfromscratch.org/patches/blfs/svn/mesa-21.2.1-add_xdemos-1.patch

```sh
tar xvf ${DOWNLOADDIR}/mesa-21.2.1.tar.xz
pushd ${BUILDDIR}/mesa-21.2.1
    patch -Np1 -i ${DOWNLOADDIR}/mesa-21.2.1-add_xdemos-1.patch
    mkdir cross-build
    pushd cross-build
        PKG_CONFIG_SYSROOT_DIR="" \
        meson --prefix=/usr --libdir=/usr/lib64 --buildtype=release \
              -Ddri-drivers="r100,r200,nouveau" \
              -Dgallium-drivers="nouveau,r600,swrast,virgl" \
              -Dgallium-nine=false -Dglx=dri -Dvalgrind=disabled \
              -Dlibunwind=disabled -Dvulkan-drivers="" \
              -Dllvm=disabled \
               --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Xbitmap
https://www.x.org/archive//individual/data/xbitmaps-1.1.2.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/xbitmaps-1.1.2.tar.bz2
pushd ${BUILDDIR}/xbitmaps-1.1.2
    ./configure $COMMON_CONFIG
    make DESTDIR=${SYSDIR}/sysroot install
popd
```


#### Xorg-Apps
Xorg-apps-packages.txt

Download the package:

```sh
cat ${DOWNLOADDIR}/Xorg-apps-packages.txt | \
    wget -i- -c -B https://www.x.org/archive//individual/app/ -P ${DOWNLOADDIR}/
```

Build script:

```sh
mkdir -pv ${BUILDDIR}/xorg-apps-package
for package in iceauth luit mkfontscale sessreg setxkbmap smproxy \
               x11perf xauth xbacklight xcmsdb xcursorgen xdpyinfo \
               xdriinfo xev xgamma xhost xinput xkbcomp xkbevd xkbutils \
               xkill xlsatoms xlsclients xmessage xmodmap xpr xprop \
               xrandr xrdb xrefresh xset xsetroot xvinfo xwd xwininfo xwud
do
    tar xvf ${DOWNLOADDIR}/$(grep -E "$package-[0-9]" ${DOWNLOADDIR}/Xorg-apps-packages.txt) \
            -C ${BUILDDIR}/xorg-apps-package/
    pushd ${BUILDDIR}/xorg-apps-package/$(grep -E "$package-[0-9]" ${DOWNLOADDIR}/Xorg-apps-packages.txt | \
                                  awk -F'.tar''{ print $1 }')
        for i in $(dirname $(find -name "config.sub"))
        do
            pushd $(dirname ./$i)
                rm -f config.{sub,guess}
                automake --add-missing
            popd
        done
        case $package in
           luit)
             sed -i -e "/D_XOPEN/s/5/6/" configure
             ;;
        esac
        ./configure $COMMON_CONFIG
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
done
rm -v ${SYSDIR}/sysroot/usr/bin/xkeystone
```


#### Xcursor-Themes
https://www.x.org/archive//individual/data/xcursor-themes-1.0.6.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/xcursor-themes-1.0.6.tar.bz2
pushd ${BUILDDIR}/xcursor-themes-1.0.6
    ./configure $COMMON_CONFIG
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd
```


#### Xorg-Fonts
Xorg-fonts-packages.txt

Download the package:

```sh
cat ${DOWNLOADDIR}/Xorg-fonts-packages.txt | \
    wget -i- -c -B https://www.x.org/pub/individual/font/ -P ${DOWNLOADDIR}/
```

Build script:

```sh
mkdir -pv ${BUILDDIR}/xorg-fonts-package
for package in font-util encodings font-alias font-adobe-utopia-type1 \
               font-bh-ttf font-bh-type1 font-ibm-type1 font-misc-ethiopic \
               font-xfree86-type1
do
    tar xvf ${DOWNLOADDIR}/$(grep -E "$package-[0-9]" ${DOWNLOADDIR}/Xorg-fonts-packages.txt) \
            -C ${BUILDDIR}/xorg-fonts-package/
    pushd ${BUILDDIR}/xorg-fonts-package/$(grep -E "$package-[0-9]" ${DOWNLOADDIR}/Xorg-fonts-packages.txt | \
                                  awk -F'.tar''{ print $1 }')
        for i in $(dirname $(find -name "config.sub"))
        do
            pushd $(dirname ./$i)
                rm -f config.{sub,guess}
                automake --add-missing
            popd
        done
        ./configure $COMMON_CONFIG
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
done
```

#### Xkeyboard-Config
https://www.x.org/archive/individual/data/xkeyboard-config/xkeyboard-config-2.33.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/xkeyboard-config-2.33.tar.bz2
pushd ${BUILDDIR}/xkeyboard-config-2.33
    rm -f config.{sub,guess}
    automake --add-missing
    ./configure $COMMON_CONFIG --with-xkb-rules-symlink=xorg
    make
    make DESTDIR=${SYSDIR}/sysroot install
popd
```


#### Pixman
https://www.cairographics.org/releases/pixman-0.40.0.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/pixman-0.40.0.tar.gz
pushd ${BUILDDIR}/pixman-0.40.0
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```


#### Libepoxy
https://github.com/anholt/libepoxy/releases/download/1.5.9/libepoxy-1.5.9.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libepoxy-1.5.9.tar.xz
pushd ${BUILDDIR}/libepoxy-1.5.9
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Xorg-Server
https://www.x.org/archive//individual/xserver/xorg-server-1.20.13.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/xorg-server-1.20.13.tar.xz
pushd ${BUILDDIR}/xorg-server-1.20.13
    ./configure $COMMON_CONFIG --enable-glamor \
            --enable-suid-wrapper --disable-selective-werror \
            --with-xkb-output=/var/lib/xkb
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
cat >> ${SYSDIR}/sysroot/etc/sysconfig/createfiles << "EOF"
/tmp/.ICE-unix dir 1777 root root
/tmp/.X11-unix dir 1777 root root
EOF
```


#### MTDev
https://bitmath.org/code/mtdev/mtdev-1.1.6.tar.bz2
```sh
tar xvf ${DOWNLOADDIR}/mtdev-1.1.6.tar.bz2
pushd ${BUILDDIR}/mtdev-1.1.6
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```


#### Libevdev
https://www.freedesktop.org/software/libevdev/libevdev-1.11.0.tar.xz
```sh
tar xvf ${DOWNLOADDIR}/libevdev-1.11.0.tar.xz
pushd ${BUILDDIR}/libevdev-1.11.0
    rm -f build-aux/config.{sub,guess}
    automake --add-missing
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```


#### Libwacom
https://github.com/linuxwacom/libwacom/releases/download/libwacom-1.12/libwacom-1.12.tar.bz2
```sh
tar xvf ${DOWNLOADDIR}/libwacom-1.12.tar.bz2
pushd ${BUILDDIR}/libwacom-1.12
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release -Dtests=disabled \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### XF86-Input-Wacom
https://github.com/linuxwacom/xf86-input-wacom/releases/download/xf86-input-wacom-0.40.0/xf86-input-wacom-0.40.0.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/xf86-input-wacom-0.40.0.tar.bz2
pushd ${BUILDDIR}/xf86-input-wacom-0.40.0
    rm -f config.{sub,guess}
    automake --add-missing
    ./configure $COMMON_CONFIG --with-systemd-unit-dir=no
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```


#### Libinput
https://www.freedesktop.org/software/libinput/libinput-1.18.1.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libinput-1.18.1.tar.xz
pushd ${BUILDDIR}/libinput-1.18.1
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              -Ddebug-gui=false -Dtests=false -Ddocumentation=false \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```




#### Xorg-Dirvers
Xorg-drivers-packages.txt
https://www.linuxfromscratch.org/patches/blfs/svn/xf86-video-ati-19.1.0-upstream_fixes-1.patch

Download the package:

```sh
cat ${DOWNLOADDIR}/Xorg-drivers-packages.txt | \
    wget -i- -c -B https://www.x.org/pub/individual/driver/ -P ${DOWNLOADDIR}/
```

Build commands:

```sh
mkdir -pv ${BUILDDIR}/xorg-drivers-package
for package in xf86-input-evdev xf86-input-libinput xf86-input-synaptics \
               xf86-video-amdgpu xf86-video-ati xf86-video-fbdev
do
    tar xvf ${DOWNLOADDIR}/$(grep -E "$package-[0-9]" ${DOWNLOADDIR}/Xorg-drivers-packages.txt) \
            -C ${BUILDDIR}/xorg-drivers-package/
    pushd ${BUILDDIR}/xorg-drivers-package/$(grep -E "$package-[0-9]" ${DOWNLOADDIR}/Xorg-drivers-packages.txt | \
                                  awk -F'.tar''{ print $1 }')
        for i in $(dirname $(find -name "config.sub"))
        do
            pushd $(dirname ./$i)
                rm -f config.{sub,guess}
                automake --add-missing
            popd
        done
        case $package in
           xf86-video-ati)
             patch -Np1 -i ${DOWNLOADDIR}/xf86-video-ati-19.1.0-upstream_fixes-1.patch
             ;;
        esac
        ./configure $COMMON_CONFIG
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
done
```

#### TWM
https://www.x.org/archive/individual/app/twm-1.0.11.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/twm-1.0.11.tar.xz
pushd ${BUILDDIR}/twm-1.0.11
    sed -i -e'/^rcdir =/s,^\(rcdir = \).*,\1/etc/X11/app-defaults,' src/Makefile.in
    rm -f config.{sub,guess}
    automake --add-missing
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```


#### Dejavu-Fonts
https://sourceforge.net/projects/dejavu/files/dejavu/2.37/dejavu-fonts-ttf-2.37.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/dejavu-fonts-ttf-2.37.tar.bz2
pushd ${BUILDDIR}/dejavu-fonts-ttf-2.37
    cp fontconfig/*.conf ${SYSDIR}/sysroot/usr/share/fontconfig/conf.avail/
    install -dv ${SYSDIR}/sysroot/usr/share/fonts/DejaVu/
    cp -v ttf/* ${SYSDIR}/sysroot/usr/share/fonts/DejaVu/
popd
```


#### XTerm
https://invisible-mirror.net/archives/xterm/xterm-368.tgz

```sh
tar xvf ${DOWNLOADDIR}/xterm-368.tgz
pushd ${BUILDDIR}/xterm-368
    sed -i'/v0/{n;s/new:/new:kb=^?:/}' termcap
    printf'\tkbs=\\177,\n' >> terminfo
    sed -i "/PROJECTROOT/s@/usr/X11R6@/usr@g" main.h
    TERMINFO=/usr/share/terminfo \
    ./configure $COMMON_CONFIG --with-app-defaults=/etc/X11/app-defaults
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install install-ti
popd
cat >> ${SYSDIR}/sysroot/etc/X11/app-defaults/XTerm << "EOF"
*VT100*locale: true
*VT100*faceName: Monospace
*VT100*faceSize: 10
*backarrowKeyIsErase: true
*ptyInitialErase: true
EOF
```

#### XInit
https://www.x.org/archive/individual/app/xinit-1.4.1.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/xinit-1.4.1.tar.bz2
pushd ${BUILDDIR}/xinit-1.4.1
    ./configure $COMMON_CONFIG --with-xinitdir=/etc/X11/app-defaults
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Shared-Mime-Info
https://gitlab.freedesktop.org/xdg/shared-mime-info/-/archive/2.1/shared-mime-info-2.1.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/shared-mime-info-2.1.tar.gz
pushd ${BUILDDIR}/shared-mime-info-2.1
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### GDK-Pixbuf
https://download.gnome.org/sources/gdk-pixbuf/2.42/gdk-pixbuf-2.42.6.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/gdk-pixbuf-2.42.6.tar.xz
pushd ${BUILDDIR}/gdk-pixbuf-2.42.6
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              --wrap-mode=nofallback \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Graphene
https://github.com/ebassi/graphene/releases/download/1.10.6/graphene-1.10.6.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/graphene-1.10.6.tar.xz
pushd ${BUILDDIR}/graphene-1.10.6
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Cairo
https://www.cairographics.org/snapshots/cairo-1.17.4.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/cairo-1.17.4.tar.xz
pushd ${BUILDDIR}/cairo-1.17.4
    ./configure $COMMON_CONFIG --enable-tee --enable-gl --enable-xlib-xcb --disable-trace
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Pango
https://download.gnome.org/sources/pango/1.49/pango-1.49.1.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/pango-1.49.1.tar.xz
pushd ${BUILDDIR}/pango-1.49.1
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release --wrap-mode=nofallback \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Libxkbcommon
https://xkbcommon.org/download/libxkbcommon-1.3.0.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libxkbcommon-1.3.0.tar.xz
pushd ${BUILDDIR}/libxkbcommon-1.3.0
    mkdir cross-build
    pushd cross-build
        PKG_CONFIG_SYSROOT_DIR="" \
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Xdg-Utils
https://portland.freedesktop.org/download/xdg-utils-1.1.3.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/xdg-utils-1.1.3.tar.gz
pushd ${BUILDDIR}/xdg-utils-1.1.3
    ./configure $COMMON_CONFIG 
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

## 5 Boot related packages

#### Linux
```sh
tar xvf ${DOWNLOADDIR}/linux-5.git.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/linux-5.git
	patch -Np1 -i ${DOWNLOADDIR}/linux-5-loongarch-rearrange_ucontext_layout.patch
	make mrproper
	make ARCH=loongarch CROSS_COMPILE=${CROSS_TARGET}- defconfig
	make ARCH=loongarch CROSS_COMPILE=${CROSS_TARGET}- menuconfig
	make ARCH=loongarch CROSS_COMPILE=${CROSS_TARGET}-
	make ARCH=loongarch CROSS_COMPILE=${CROSS_TARGET}- INSTALL_MOD_PATH=dest modules_install
	mkdir -pv ${SYSDIR}/sysroot/lib/modules/
	cp -av dest/lib/modules/* ${SYSDIR}/sysroot/lib/modules/
	cp -av vmlinux ${SYSDIR}/sysroot/boot/vmlinux
popd

```

    Because of the cross-compilation, the Linux kernel needs to specify the "ARCH" variable to know the architecture of the target machine. Use the commands of the cross-compilation tool by setting the "CROSS_COMPILE" variable to specify the command prefix.

    The following explains the meaning of multiple make command steps:  
    * ```defconfig```, automatically obtain the default configuration file in the specified architecture directory as the configuration file used for the current compilation.  
    * ```menuconfig```, enter the interactive selection kernel function interface, which requires the main system to install the Ncurses development library, this step can be used to adjust the Linux kernel selection, if the default is sufficient, then this step You can skip it.    
    If you follow this article to make LiveUSB, you need the kernel to compile USB storage device support into the kernel, and change the "M" in front of "USB Mass Storage support" to "*", as follows:

```sh
    Device Drivers ---> 
        USB support ---> 
            <*> USB Mass Storage support
```
    * ```modules_install```, install the module files, the root directory of the module installation is specified by the "INSTALL_MOD_PATH" variable, where "dest" is specified, which means it is installed in the dest directory in the current directory. If there is no such directory, it will be created automatically .

    If you want to support Xorg's keyboard and mouse, you need to confirm the following options:

```sh
Device Drivers --->
  Input device support --->
    <*> Generic input layer (needed for keyboard, mouse, ...) 
    <*> Event interface                  
```

    When the Linux kernel compilation is complete, we can copy kernel file "vmlinux" and the corresponding module to the directory where stored target system.


#### ACPI-Update
   The current Linux-5.git version of the kernel needs to update the firmware configuration information when it is used on the Loongson 3A5000 machine, which can be updated by providing the kernel with an initrd format file. The production method is as follows:

```sh
tar xvf ${DOWNLOADDIR}/acpi-update-20210822.tar.gz
pushd acpi-update-20210822
    find kernel | cpio -H newc --create> ${SYSDIR}/sysroot/boot/acpi-initrd
popd
```

#### Linux-Firmware
```sh
tar xvf ${DOWNLOADDIR}/linux-firmware-20210818.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/linux-firmware-20210818
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

    The Linux-Firmware package is installed mainly because when the target machine is equipped with some independent displays, the corresponding firmware support is needed to display normally.

#### Grub2
```sh
tar -xvf ${DOWNLOADDIR}/grub-2.06.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/grub-2.06
    patch -Np1 -i ${DOWNLOADDIR}/grub-2.06-loongarch-li_to_liw.patch
    patch -Np1 -i ${DOWNLOADDIR}/grub-2.06-fix-initrd.patch
    sed -i "s@-march=loongarch @@g" Makefile.in conf/Makefile.common grub-core/Makefile.in
	mkdir build
	pushd build
		../configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
		             --host=${CROSS_TARGET} -with-platform=efi \
		             --with-utils=host --disable-werror
		make 
		make DESTDIR=${SYSDIR}/sysroot install
	popd
popd
```

    Install Grub2 commands and modules for the target system, so that after starting the target system on the target architecture machine, you can also make the corresponding EFI file and set the boot-related files.


## 6 Set the target system
    The software package production process of the target system has been completed, and the next step is to make the necessary settings for the target system so that the target system can be started and used normally.

### Create user files

    Create a basic user name, most of these user names will be used during the startup process, the steps are following:

```sh
cat> ${SYSDIR}/sysroot/etc/passwd << "EOF"
root::0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/bin/false
daemon:x:6:6:Daemon User:/dev/null:/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/var/run/dbus:/bin/false
sshd:x:50:50:sshd PrivSep:/var/lib/sshd:/bin/false
systemd-bus-proxy:x:72:72:systemd Bus Proxy:/:/bin/false
systemd-journal-gateway:x:73:73:systemd Journal Gateway:/:/bin/false
systemd-journal-remote:x:74:74:systemd Journal Remote:/:/bin/false
systemd-journal-upload:x:75:75:systemd Journal Upload:/:/bin/false
systemd-network:x:76:76:systemd Network Management:/:/bin/false
systemd-resolve:x:77:77:systemd Resolver:/:/bin/false
systemd-timesync:x:78:78:systemd Time Synchronization:/:/bin/false
systemd-coredump:x:79:79:systemd Core Dumper:/:/bin/false
nobody:x:99:99:Unprivileged User:/dev/null:/bin/false
EOF
```


### Create a group file

    Create a basic user group, most of which are required by the system, the steps are followings:

```sh
cat> ${SYSDIR}/sysroot/etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
usb:x:14:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
systemd-journal:x:23:
input:x:24:
mail:x:34:
sshd:x:50:
kvm:x:61:
systemd-bus-proxy:x:72:
systemd-journal-gateway:x:73:
systemd-journal-remote:x:74:
systemd-journal-upload:x:75:
systemd-network:x:76:
systemd-resolve:x:77:
systemd-timesync:x:78:
systemd-coredump:x:79:
saslauth:x:81:
wheel:x:97:
nogroup:x:99:
users:x:999:
EOF
```

### Create an input configuration file

```sh
cat> ${SYSDIR}/sysroot/etc/inputrc << "EOF"
set horizontal-scroll-mode Off
set meta-flag On
set input-meta On
set convert-meta Off
set output-meta On
set bell-style none
"\eOd": backward-word
"\eOc": forward-word
"\e[1~": beginning-of-line
"\e[4~": end-of-line
"\e[5~": beginning-of-history
"\e[6~": end-of-history
"\e[3~": delete-char
"\e[2~": quoted-insert
"\eOH": beginning-of-line
"\eOF": end-of-line
"\e[H": beginning-of-line
"\e[F": end-of-line
EOF
```
    By creating an input configuration file, you can make terminal input more in line with typical system usage. Failure to create this file will not affect the system.

### Set time file
```sh
cat> ${SYSDIR}/sysroot/etc/adjtime << "EOF"
0.0 0 0.0
0
LOCAL
EOF
```

    It is set here to use the time provided by the BIOS. If UTC time is used, the "LOCAL" in the file can be changed to "UTC".

### Create system information file
```sh
cat> ${SYSDIR}/sysroot/etc/lsb-release << "EOF"
DISTRIB_ID="My GNU/Linux System for LoongArch64"
DISTRIB_RELEASE="6.0"
DISTRIB_CODENAME="Sun Haiyong"
DISTRIB_DESCRIPTION="My GNU/Linux System"
EOF
```

```sh
cat> ${SYSDIR}/sysroot/etc/os-release << "EOF"
NAME="My GNU/Linux System for LoongArch64"
VERSION="6.0"
ID=CLFS4LA64
PRETTY_NAME="My GNU/Linux System for LoongArch64 6.0"
VERSION_CODENAME="Sun Haiyong"
EOF
```

### Startup Settings

#### Generate EFI file
    Generate a UEFI boot file for starting using grub, the commands are following:

```sh
mkdir -pv ${SYSDIR}/sysroot/boot/efi/EFI/BOOT
${CROSS_TARGET}-grub-mkimage \
          --directory "${SYSDIR}/sysroot/usr/lib64/grub/loongarch64-efi" \
          --prefix'(,gpt2)/boot/grub' \
          --output "${SYSDIR}/sysroot/boot/efi/EFI/BOOT/BOOTLOONGARCH.EFI" \
          --format'loongarch64-efi' \
          --compression'auto' \
          'ext2''part_gpt'
```
    Because it is running the Grub command stored in the cross-compilation tool directory, the command to run according to the naming rules installed at the time starts with `${CROSS_TARGET}-`.

    Explain the parameters of the above command:    
    * ```--directory```, this parameter specifies the directory where the module used to generate the EFI file is stored, here is the directory of the module installed by Grub in the storage directory of the target system.  
    * ```--prefix```, this parameter specifies the base directory of the EFI file to read the file, that is to say, if EFI needs to read any file, the directory set by this parameter is used as the most basic directory, here is one Very important parameter setting ```(,gpt2)```, which specifies the partition of the storage device. There are two parameters in parentheses and separated by ",". The parameter before the comma is the disk number, and the parameter after the comma The parameter is the partition number. We see that the disk number is not specified here. After the EFI starts, the disk number of the boot EFI file will be automatically used instead, and the partition number is designated as `gpt2`, where "gpt" represents the partition type, which is usually "Gpt" or "msdos", "gpt" represents the GPT partition, and "msdos" represents the DOS partition. At present, the GPT partition has gradually become the mainstream, and UEFI BIOS also recommends the partition to use GPT, and the number after "gpt" represents the partition Number, the first partition is "1" and the second partition is "2", so here `gpt2` represents the second partition of GPT.  
    The reason for this setting is to facilitate the normal booting of the storage device where the target system is installed, because usually the partition where the EFI file is stored and the partition where the matching Grub boot-related files are stored are on the same storage device.  
    * ```--output```, this parameter specifies the path and file name where the generated EFI file is stored, here is the "/boot/efi/EFI/BOOT" in the target system storage directory, which is based on a The directory structure after the system is mounted normally, the "/boot/efi" directory usually mounts the first partition, which is the EFI partition, in which "EFI/BOOT" is usually created, because UEFI BIOS usually Load EFI files from this directory on this partition for booting. "BOOTLOONGARCH.EFI" is the boot EFI file name used by LoongArch machine by default.  
    * ```--format```, this parameter specifies the format name of the generated file, the name will be different for different architectures and different startup methods, here the name used for the EFI startup method of LoongArch64 is "loongarch64-efi".  
    * ```--compression'auto'```, this parameter specifies the compression method used by the generated EFI file, here is set to `auto`, and other values include `xz` which means compression with XZ Mode and `none` means no compression.  
    * `'ext2''part_gpt'`, these two modules are designated to be added to the EFI file, the module added to the EFI file will automatically be used as a function that can be used directly after the EFI file is started, and if it is not added to the EFI You need to load the module to use it. Only `ext2` and `part_gpt` are added here because the modules are stored in the storage device. If you want to read the module, you need to be able to identify the partition and file system of the storage device, here` part_gpt` is used to identify the GPT partition of the storage device, and `ext2` is the file system used by the partition. When the two match the actual partition and file system, what are the subsequent functional requirements? Both can be used by loading modules, which can minimize the size of the EFI file and speed up the loading speed of the BIOS to the EFI file. The storage location of the module is determined by the base directory specified by the `--prefix` parameter. The loongarch64-efi directory in this base directory is the directory where each module is stored.

#### Install Grub module files
    After the EFI file is generated, the Grub module file can be stored in the directory set by the EFI generation. The installation process is as follows:

```sh
mkdir -pv ${SYSDIR}/sysroot/boot/grub
cp -av ${SYSDIR}/sysroot/usr/lib64/grub/loongarch64-efi ${SYSDIR}/sysroot/boot/grub
```

## 7 Process the target system

### Clean up symbol information
    Currently, most of the binary files installed in the target system carry various symbol information, which does not affect execution, but takes up a large amount of storage space. If there is no debugging-related requirement, this information can be cleaned up to reduce storage space.

    You can use the strip command to clean up symbol information, but strip must be able to handle the target platform binary, so we can use the strip command in the cross-compilation tool chain to operate. The steps are as follows:

```sh
pushd ${SYSDIR}/sysroot
	find usr/lib{,64} -type f -name \*.a -exec ${CROSS_TARGET}-strip --strip-debug {}';'
	find usr/lib{,64} -type f -name \*.so* -exec ${CROSS_TARGET}-strip --strip-unneeded {}';'
	find usr/{bin,sbin,libexec} -type f -exec ${CROSS_TARGET}-strip --strip-all {}';'
popd
```

    Here we find that there are many parameters used by strip, here is a brief explanation:  
    * `--strip-debug`, only remove debugging related symbol information, this parameter is suitable for static library files, and will not remove the information needed for the linking process.  
    * `--strip-unneeded`, delete all symbol information not related to relocation. This parameter cannot be used for static library files, otherwise the processed static library cannot be used during static linking.  
    * `--strip-all`, this parameter means that all the symbol information that can be removed should be removed as much as possible. This parameter is not recommended for library files, especially static library files.

### Packaging system
    After the production is completed, you can exit the production user environment, use the command:

```sh
exit
```

    Then you can use root privileges to package the target system, the packaging steps are as follows:

```sh
pushd ${SYSDIR}/sysroot
	sudo tar --xattrs-include='*' --owner=root --group=root -cjpf \
			${SYSDIR}/loongarch64-clfs-system-6.0.tar.bz2 *
popd
```

## 8 Create a bootable USB flash drive
    After making the target system, we can try to start the target system. With the help of a USB flash drive, we can make a simple LiveUSB that can be started.
    
### Set U Disk Partition
    Find a USB flash drive with a capacity of not less than 4G. If the symbol cleaning is not performed, the recommended capacity is not less than 8G. Please make sure that there is no important and preserved data in the USB flash drive, because the next operation will destroy the original USB flash drive. data.

    Then partition the U disk, it is recommended to divide it into 3 partitions, namely:  
    The first partition: EFI partition, the file system is fat, and the capacity is 100M;  
    The second partition: boot partition, the file system is ext2, and the capacity is 500M;  
    The third partition: the root partition, the recommended file system is xfs, and the remaining capacity can be allocated to this partition.

    Assuming that the U disk device is named ```sdb```, the actual production steps are as follows:

```sh
sudo cfdisk -z /dev/sdb
```

    The command will appear interactive operation mode, the `-z` parameter will force the partition type selection (this will cause all the original data on the U disk to be lost, please confirm that there is no data to keep before continuing), here select "gpt" , And then in the partition interface, follow the above-mentioned partitions to the U disk, save and exit. At this time, the system will have three partition names: "/dev/sdb1", "/dev/sdb2" and "/dev/sdb3" , And then begin to process these three partitions.

    First, create a directory for making LiveUSB, the command is as follows:  

```sh
mkdir /tmp/liveusb
```

    Mount the third partition of the U disk, which is the root partition, to this directory, the command is as follows:

```sh
sudo mount /dev/sdb3 /tmp/liveusb
```

    Then, create a boot partition, which is used to mount the second partition, the boot partition. The command is as follows:

```sh
sudo mkdir /tmp/liveusb/boot
sudo mount /dev/sdb2 /tmp/liveusb/boot
```

    Then create an efi partition, which is used to mount the first partition, the EFI partition. The command is as follows:

```sh
sudo mkdir /tmp/liveusb/boot/efi
sudo mount /dev/sdb1 /tmp/liveusb/boot/efi
```

    At this point, the USB partition is ready to be mounted, the next step is to unzip the target system to this directory, the command is as follows:

```sh
pushd /tmp/liveusb
    sudo tar -xvpf ${SYSDIR}/loongarch64-clfs-system-6.0.tar.bz2
popd
```

    After decompressing the target system, don't worry about uninstalling and unplugging the U disk, because it will take some work.

### Make Grub boot menu file
    After booting the machine with Grub, the grub.cfg file is usually automatically loaded to display the boot menu. The following are the steps to make a simple boot menu:

```sh
pushd /tmp/liveusb
cat> boot/grub/grub.cfg << "EOF"
menuentry'My GNU/Linux System for LoongArch64' {
echo'Loading Linux Kernel ...'
linux /vmlinux root=<PARTUUID> rootdelay=5 rw quiet
initrd /acpi-initrd
boot
}
EOF
popd
```
    The directory where grub.cfg is stored is determined by the ```--prefix``` parameter setting when generating the EFI file. Just follow the parameter setting directory and name it grub.cfg.
The following briefly introduces the setting content of the menu file:  
    * ```menuentry```, this setting item sets the items displayed in the boot menu, and one item corresponds to a `menuentry`.  
    * `echo`, input content, is to print the content of the line on the screen.  
    * `linux`, load the Linux kernel, because the currently loaded grub.cfg and the Linux kernel vmlinux file are in the same partition, you can use the path directly, if not in the same partition, you need to set the disk and partition to specify the kernel file path. The following `root=<PARTUUID> rootdelay=5 rw` are the parameters provided to the Linux kernel when booting: `root` specifies the name of the booting root partition, here is the setting of the ```<PARTUUID>``` to be converted, then You will use it later, or you can use a certain device name. Assuming that the device name of the USB flash drive is sdb and the root partition is sdb3, it can be written as root=/dev/sdb3. Of course, you need to insert the USB flash drive into the target machine. Modify the device name at the time; `rootdelay` sets the waiting time, which is usually used when the USB flash drive is used as the startup disk, because the USB flash drive needs a short period of initialization, if there is no waiting, the device cannot be found and the startup fails;` rw` sets the root partition to be mounted in a readable and writable manner.  
    * `initrd`, used to add to the initrd or initramfs file for the kernel to use.

When the root partition is set as the ```<PARTUUID>``` to be converted, it needs to be replaced according to the actual PARTUUID of the root partition. The replacement steps are as follows:

```sh
pushd /tmp/liveusb
	ROOTPARTUUID=$(sudo blkid /dev/sdb3 | awk -F'PARTUUID=''{ print $2 }')
	sed -i "s@<PARTUUID>@PARTUUID=${ROOTPARTUUID}@g" boot/grub/grub.cfg
	unset ROOTPARTUUID
popd
```
    We can see that the replacement step is to obtain the "PARTUUID" of the actual partition through the blkid command. "PARTUUID" is usually a 32-character string composed of 5 letters and numbers, and each character is linked with "-", for example : B2c2bd57-82e4-1c25-b87a-0e9caf919053.  
    When the kernel is started, the root partition can be found by passing the "PARTUUID" parameter to the root parameter, so that the U disk has better versatility.

    With this, we have basically completed the production process of LiveUSB, and then first uninstall the U disk:

```sh
sudo umount -R /tmp/liveusb
```
	
    The umount command uses the ‵-R‵ parameter to unmount multiple mounts in the specified directory at a time.

    Then you can pull out the U disk, and then start it on the Loongson 3A5000 machine.


## 9 Enter the system
    After entering the system, you need to do some work to meet your own needs. Use the root user to execute the following commands:

```sh
ssh-keygen -A
pwconv
grpconv
```

## 10 Appendix

### Reference
"Explore with "Core" to teach you how to build the Linux system of the Godson platform" by Sun Haiyong

LFS: https://www.linuxfromscratch.org/lfs/