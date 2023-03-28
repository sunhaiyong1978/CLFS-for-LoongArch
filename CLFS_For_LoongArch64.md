# <center>手把手教你构建基于LoongArch64架构的Linux系统</center>

<center>（CLFS For LoongArch64）</center>  

<center>作者：孙海勇</center>


## 0 前言
　　龙芯中科于2021年推出了全新指令集架构LoongArch，其中64位指令集称为LoongArch64。  
　　本文的目标是为LoongArch64制作一套基本的Linux系统，作为对新的指令集架构而制作Linux系统，我们可以默认该架构平台上无可运行的系统为前提，采用交叉编译的方式为其制作一套基本的Linux系统。


## 1 关于软件包的移植
　　对于本文所制作的目标系统是基于LoongArch64架构的Linux系统，对于LoongArch64架构所使用的指令集在本文发布时属于比较新的，很多Linux系统的基本软件包中都没有包含该指令集相关的支持，为了解决支持新架构的问题，可根据不同情况的软件包采用不同的处理方式。

* 扩充式移植软件包  
　　这类软件包通常在Linux系统中与具体指令集架构细节打交道的软件包，例如：Linux内核、GCC、Binutls、Glibc以及LLVM等等，且这些软件包通常需要大量代码的加入才能支持新的指令集架构。  
　　对于这类软件包，如果想以最佳的手段支持新指令集架构，那么当然是提交到官方的最新版本中并得到长期的支持，但要达到这样的结果是需要一个过程的，那么在这个过程中则可以采用“打补丁”的方式。但因通常这些软件包需要修改和增加大量的代码，这使得补丁文件通常针对具体的版本，当版本升级后通常补丁不能直接使用，所以要使用对应版本的源代码来使用补丁。  
　　另一种“不太好”的方式是添加了新架构的完整源代码整体提供下载，即补丁已经打在源代码中，这样只要下载修改过的软件包源码就可以使用了。

* 简易移植软件包  
　　这类软件包代码上基本上不涉及汇编或者有非汇编的实现（汇编通常作为优化性能的手段），此类软件包通常有多种指令集架构采用类似的工作行为，可在某一类工作行为上加入新指令集架构的判断或者通过较少的改动即可实现对新指令集架构的移植，比如：Systemd、Automake等，因此针对这类软件包的补丁具有较高的版本通用性，同一个补丁可能适合用于多个版本上，在该类软件包的官方支持新指令集架构之前，采用“打补丁”的方式更适合这类软件包的移植方式。

* 无需移植软件包  
　　这类软件包大多采用非汇编的开发语言进行编写，具有较强的通用性，通常在其所依赖的编译器或者运行环境进行了移植后就可以直接进行编译或使用了。例如Coreutils、Findutils等。  
　　这类软件包也可能需要在配置阶段进行新架构的支持，主要是软件包自带的config.sub和config.guess检查目标系统时没有匹配的架构设置导致错误，这类问题比较好解决，只需要将增加了新架构的Automake软件包中的config.sub和config.guess覆盖软件包中的文件即可。

　　除了以上这些在新架构平台上可移植的软件包外还有一些软件包是针对某一个特定的指令集架构编写的，如果是非核心功能的软件包可以暂时忽略，如果有对应功能的可移植软件包也可以用来替代这些特定平台的软件包。
　　

## 2 准备工作
　　在开始制作前，先做一些准备工作，这包括系统的准备、制作环境的设置以及软件包源代码的下载。

### 2.1 系统的准备
　　首先准备一台可以安装通用Linux系统的机器，对于要用来交叉编译目标平台的系统我们称为“主系统”，“主系统”可以是X86机器上的系统，也可以是其他架构机器上的系统，为了方便讲解，本文采用在X86架构上的Linux系统进行制作讲解。

　　选择一个合适的Linux对于能否顺利完成制作还是有一定的作用，这里可以使用常见的发行版，如Fedora、Debian、CentOS等，也可以使用专门的系统，如LFS的LiveCD等，接下来我们以Fedora系统作为交叉编译的“主系统”进行讲解。

　　为了使制作系统讲解的过程中尽量减少额外的因素导致的问题，我们在一个“重新搭建的”Fedora系统中进行制作，在一个支持dnf命令工具的系统中使用如下命令进行搭建：

```sh
export DISTRO_URL=https://mirrors.bfsu.edu.cn/fedora/releases/34/Everything/x86_64/os/
sudo dnf install @core @c-development rpm-build git python3-devel texinfo \
                 zlib-devel xz-lzma-compat gettext-devel perl-FindBin \
                 gdbm-devel expat-devel gobject-introspection-devel \
                 libgusb-devel libusb-devel libudev-devel libgudev-devel \
                 perl-Pod-Html rpm-devel tcl ncurses-devel openssl-devel libxslt bc \
                 wget docbook-style-xsl meson ninja-build python3-jinja2 gperf rsync \
                 xcursorgen mkfontscale itstool xmlto doxygen lynx \
                 gdk-pixbuf2-devel gmp-devel libxml2-devel libss-devel \
                 bzip2-devel ghc asciidoc pcre-static \
                 sassc dbus-glib libatomic libnotify-devel gtk-doc polkit-devel \
                 libunistring-devel gc-devel autogen sqlite protobuf-c-compiler emacs \
                 autoconf213 sqlite-devel nodejs cmake  \
                 cldr-emoji-annotation unicode-emoji iso-codes-devel \
                 --installroot ${HOME}/la-clfs --disablerepo="*" \
                 --repofrompath base,${DISTRO_URL} \
                 --releasever 34 --nogpgcheck
```
　　以上步骤将在当前用户的目录中创建"la-clfs"的目录，在这个目录中将安装一个基本的制作环境，这里安装的是Fedora 34的系统，读者也可以安装其它的系统作为制作环境。
　　接下来的制作过程都将在这个目录中进行。

　　复制当前系统的域名解析配置文件到新建立的系统中，以便该系统可以访问网络资源。

```sh
cp -a /etc/resolv.conf ${HOME}/la-clfs/etc/
```

　　接下来切换到该目录中:

```sh
sudo chroot ${HOME}/la-clfs
```

　　挂载必要的文件系统：

```sh
mount -t proc proc proc
mount -t sysfs sys sys
mount -t devtmpfs dev dev 
mount -t devpts devpts dev/pts 
mount -t tmpfs shmfs dev/shm
```

### 2.2 制作环境的设置

#### 创建必要的目录
　　使用如下命令创建几个目录，后续的制作过程都将在这些目录中进行。

```sh
export SYSDIR=/opt/mylaos
mkdir -pv ${SYSDIR}
mkdir -pv ${SYSDIR}/downloads
mkdir -pv ${SYSDIR}/build
install -dv ${SYSDIR}/cross-tools
install -dv ${SYSDIR}/sysroot
```

　　简单说明一下这几个目录的用处：

* 通过设置“SYSDIR"变量方便对“基础目录”的使用，该变量设置了一个具体的目录作为“基础目录”，与本次制作相关的工作都在该目录中进行。

* “downloads”目录用来存放各种软件的源码包以及补丁文件；

* “build”目录用来编译各个软件包；

* “cross-tools”目录用来存放交叉工具链及相关的软件；

* “sysroot”用来存放目标平台系统。

#### 创建制作用户

　　为了防止制作过程中意外的对系统本身造成破坏，创建一个普通用户的账号，后续的制作过程除非需要特殊权限操作，否则对于目标系统的一切操作都使用该用户进行。

```sh
groupadd lauser
useradd -s /bin/bash -g lauser -m -k /dev/null lauser
```
　　设置目录为新创建用户所属：

```sh
chown -Rv lauser ${SYSDIR}
chmod -v a+wt ${SYSDIR}/{sysroot,cross-tools,downloads,build}
```


##### 切换到制作用户

　　使用命令切换到新创建的用户：  

```sh
su - lauser
```

　　使用“su”命令进行切换时加上“-”参数可以防止切换前的用户环境变量带到新用户环境中。

##### 设置制作用户环境

　　为制作用户设置最精简和必要的环境变量，以帮助后续制作过程的开展，以下为用户的环境变量进行长期设置。

```sh
cat > ~/.bash_profile << "EOF"
exec env -i HOME=${HOME} TERM=${TERM} PS1='\u:\w\$ ' /bin/bash
EOF
```

```sh
cat > ~/.bashrc << "EOF"
set +h
umask 022
export SYSDIR="/opt/mylaos"
export BUILDDIR="${SYSDIR}/build"
export DOWNLOADDIR="${SYSDIR}/downloads"
export LC_ALL=POSIX
export CROSS_HOST="$(echo $MACHTYPE | sed "s/$(echo $MACHTYPE | cut -d- -f2)/cross/")"
export CROSS_TARGET="loongarch64-unknown-linux-gnu"
export MABI="lp64d"
export BUILD64="-mabi=lp64d"
export PATH=${SYSDIR}/cross-tools/bin:/bin:/usr/bin
export JOBS=-j8
unset CFLAGS
unset CXXFLAGS
EOF
```

　　这里设置了几个环境变量，下面简单介绍这些变量的含义：

* SYSDIR：方便引用“基础目录”，可以通过修改该变量所设置的路径来改变所使用的“基础目录”。
* BUILDIR：该变量指定的目录用来进行软件包编译过程使用的目录。
* DOWNLOADDIR：该变量指定的目录存放制作系统的过程中所需要的软件包及一些必要的补丁文件。
* CROSS_HOST:设置“主系统”所使用的架构系统描述词
* CROSS_TARGET：设置“目标系统”所使用的架构系统描述词。
* MABI:指定“目标系统”默认使用的ABI名称。
* BUILD64：设置编译“目标系统”中的软件包为64位ABI时使用的ABI参数。

　　设置好用户环境配置文件后通过source命令使环境设置生效，使用命令：

```sh
source ~/.bash_profile
```



#### 创建目标系统的目录结构

　　我们要制作的目标系统是常规的Linux/GNU系统，我们按照常规的Linux/GNU系统所使用的目录结构创建目标系统的目录，命令如下:

```sh
pushd ${SYSDIR}/sysroot
	mkdir -pv ./{boot,home,root,mnt,opt,srv,run}
	mkdir -pv ./etc/{opt,sysconfig,profile.d}
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
	ln -sfv . ./boot/boot
popd
```
　　目标系统将存放在${SYSDIR}/sysroot目录中，所以以该目录为基础创建各种目录和链接文件。

### 2.3 下载软件包


　　为了使用最新的软件包构建目标系统，这可能需要从网络中下载软件包源代码及补丁文件，下载的文件建议存放在“downloads”目录中。

```sh
pushd ${SYSDIR}/downloads
```

　　然后可以使用wget工具下载相应版本的软件包，例如下载coreutils-9.2这个软件包，可使用命令：

```sh
	wget https://ftp.gnu.org/gnu/coreutils/coreutils-9.2.tar.xz
```

　　下载后软件包存放在“downloads”目录中。

　　以下是本次制作所用到的软件包源码的地址：

　　**Acl:** https://download.savannah.gnu.org/releases/acl/acl-2.3.1.tar.xz  
　　**Attr:** https://download.savannah.gnu.org/releases/attr/attr-2.5.1.tar.xz  
　　**Autoconf:** https://ftp.gnu.org/gnu/autoconf/autoconf-2.71.tar.xz  
　　**Autogen:** https://ftp.gnu.org/gnu/autogen/rel5.18.16/autogen-5.18.16.tar.xz  
　　**Automake:** https://ftp.gnu.org/gnu/automake/automake-1.16.5.tar.xz  
　　**Bash:** https://ftp.gnu.org/gnu/bash/bash-5.2.15.tar.gz  
　　**BC:** https://github.com/gavinhoward/bc/archive/6.5.0/bc-6.5.0.tar.gz  
　　**Binutils:**  https://ftp.gnu.org/gnu/binutils/binutils-2.40.tar.xz  
　　**Bison:** https://ftp.gnu.org/gnu/bison/bison-3.8.2.tar.xz  
　　**Boost:** https://boostorg.jfrog.io/artifactory/main/release/1.81.0/source/boost_1_81_0.tar.bz2  
　　**Bzip2:** https://www.sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz  
　　**Coreutils:** https://ftp.gnu.org/gnu/coreutils/coreutils-9.2.tar.xz  
　　**Check:** https://github.com/libcheck/check/releases/download/0.15.2/check-0.15.2.tar.gz  
　　**CMake:** https://cmake.org/files/v3.26/cmake-3.26.1.tar.gz  
　　**CPIO:** https://ftp.gnu.org/gnu/cpio/cpio-2.13.tar.bz2  
　　**Ctags:** http://prdownloads.sourceforge.net/ctags/ctags-5.8.tar.gz  
　　**CURL:** https://curl.se/download/curl-8.0.1.tar.gz  
　　**D-Bus:** https://dbus.freedesktop.org/releases/dbus/dbus-1.15.4.tar.xz  
　　**Dejagnu:** https://ftp.gnu.org/gnu/dejagnu/dejagnu-1.6.3.tar.gz  
　　**DHCPCD:** https://roy.marples.name/downloads/dhcpcd/dhcpcd-9.4.1.tar.xz  
　　**Diffutils:** https://ftp.gnu.org/gnu/diffutils/diffutils-3.9.tar.xz  
　　**Dosfstools:** https://github.com/dosfstools/dosfstools/releases/download/v4.2/dosfstools-4.2.tar.gz  
　　**Doxygen:** https://www.doxygen.nl/files/doxygen-1.9.6.src.tar.gz  
　　**E2fsprogs:** https://downloads.sourceforge.net/project/e2fsprogs/e2fsprogs/v1.46.5/e2fsprogs-1.47.0.tar.gz  
　　**Ethtool:** https://www.kernel.org/pub/software/network/ethtool/ethtool-6.2.tar.xz  
　　**Expat:** https://prdownloads.sourceforge.net/expat/expat-2.5.0.tar.xz  
　　**Expect:** https://sourceforge.net/projects/expect/files/Expect/5.45.4/expect5.45.4.tar.gz  
　　**File:** https://astron.com/pub/file/file-5.44.tar.gz  
　　**Findutils:** https://ftp.gnu.org/gnu/findutils/findutils-4.9.0.tar.xz  
　　**Flex:** https://github.com/westes/flex/releases/download/v2.6.4/flex-2.6.4.tar.gz  
　　**Fontconfig:** https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.14.2.tar.xz  
　　**Freetype:** https://downloads.sourceforge.net/freetype/freetype-2.13.0.tar.xz  
　　**Fribidi:** https://github.com/fribidi/fribidi/releases/download/v1.0.12/fribidi-1.0.12.tar.xz  
　　**Gawk:** https://ftp.gnu.org/gnu/gawk/gawk-5.2.1.tar.xz  
　　**GCC:** ```git://sourceware.org/git/gcc.git  默认分支名“master”```  
　　**GC:** https://www.hboehm.info/gc/gc_source/gc-8.2.2.tar.gz  
　　**GDB:** https://ftp.gnu.org/gnu/gdb/gdb-13.1.tar.xz  
　　**GDBM:** https://ftp.gnu.org/gnu/gdbm/gdbm-1.23.tar.gz  
　　**Gettext:** https://ftp.gnu.org/gnu/gettext/gettext-0.21.1.tar.xz  
　　**Git:** https://www.kernel.org/pub/software/scm/git/git-2.40.0.tar.xz  
　　**Glib:** https://download.gnome.org/sources/glib/2.76/glib-2.76.1.tar.xz  
　　**Glibc:** https://ftp.gnu.org/gnu/libc/glibc-2.37.tar.xz  
　　**Glibmm:** https://download.gnome.org/sources/glibmm/2.76/glibmm-2.76.0.tar.xz  
　　**GMP:** https://ftp.gnu.org/gnu/gmp/gmp-6.2.1.tar.xz  
　　**GnuTLS:** https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-3.8.0.tar.xz  
　　**Gobject-Introspection:** https://download.gnome.org/sources/gobject-introspection/1.76/gobject-introspection-1.76.1.tar.xz  
　　**GPerf:** https://ftp.gnu.org/gnu/gperf/gperf-3.1.tar.gz  
　　**GPM:** https://www.nico.schottelius.org/software/gpm/archives/gpm-1.20.7.tar.bz2  
　　**Graphite:** https://github.com/silnrsi/graphite/releases/download/1.3.14/graphite-1.3.14.tar.gz  
　　**Grep:** https://ftp.gnu.org/gnu/grep/grep-3.10.tar.xz  
　　**Groff:** https://ftp.gnu.org/gnu/groff/groff-1.22.4.tar.gz  
　　**Grub2:** ```https://github.com/loongarch64/grub  分支名“dev/patchwork/efi”```  
　　**Guile:** https://ftp.gnu.org/gnu/guile/guile-3.0.9.tar.xz  
　　**Gzip:** https://ftp.gnu.org/gnu/gzip/gzip-1.12.tar.xz  
　　**Harfbuzz:** https://github.com/harfbuzz/harfbuzz/releases/download/7.1.0/harfbuzz-7.1.0.tar.xz  
　　**Iana-Etc:** https://github.com/Mic92/iana-etc/releases/download/20230320/iana-etc-20230320.tar.gz  
　　**ICU4C:** https://github.com/unicode-org/icu/releases/download/release-72-1/icu4c-72_1-src.tgz  
　　**Inetutils:** https://ftp.gnu.org/gnu/inetutils/inetutils-2.4.tar.xz  
　　**Inih:** https://github.com/benhoyt/inih/archive/r56/inih-r56.tar.gz  
　　**intltool:** https://launchpad.net/intltool/trunk/0.51.0/+download/intltool-0.51.0.tar.gz  
　　**IPRoute2:** https://www.kernel.org/pub/linux/utils/net/iproute2/iproute2-6.2.0.tar.xz  
　　**Jasper:** https://github.com/jasper-software/jasper/releases/download/version-4.0.0/jasper-4.0.0.tar.gz  
　　**KBD:** https://www.kernel.org/pub/linux/utils/kbd/kbd-2.5.1.tar.xz  
　　**Kmod:** https://www.kernel.org/pub/linux/utils/kernel/kmod/kmod-30.tar.xz  
　　**Less:** https://www.greenwoodsoftware.com/less/less-608.tar.gz  
　　**Lcms:** https://downloads.sourceforge.net/lcms/lcms2-2.15.tar.gz  
　　**Libaio:** https://ftp.debian.org/debian/pool/main/liba/libaio/libaio_0.3.113.orig.tar.gz  
　　**Libcap:** https://www.kernel.org/pub/linux/libs/security/linux-privs/libcap2/libcap-2.68.tar.xz  
　　**Libelf:** https://sourceware.org/ftp/elfutils/0.189/elfutils-0.189.tar.bz2  
　　**Libevent:** https://github.com/libevent/libevent/releases/download/release-2.1.12-stable/libevent-2.1.12-stable.tar.gz  
　　**Libffi:** https://github.com/libffi/libffi/archive/v3.4.4/libffi-3.4.4.tar.gz  
　　**Libgudev:** https://download.gnome.org/sources/libgudev/237/libgudev-237.tar.xz  
　　**Libgusb:** https://github.com/hughsie/libgusb/archive/0.4.5/libgusb-0.4.5.tar.gz  
　　**Libjpeg-Turbo:** https://downloads.sourceforge.net/libjpeg-turbo/libjpeg-turbo-2.1.91.tar.gz  
　　**Libmng:** https://downloads.sourceforge.net/libmng/libmng-2.0.3.tar.xz  
　　**Libmnl:** https://netfilter.org/projects/libmnl/files/libmnl-1.0.5.tar.bz2  
　　**Libnl:** https://github.com/thom311/libnl/releases/download/libnl3_7_0/libnl-3.7.0.tar.gz  
　　**Libpipeline:** https://download.savannah.gnu.org/releases/libpipeline/libpipeline-1.5.7.tar.gz  
　　**Libpng:** https://downloads.sourceforge.net/libpng/libpng-1.6.39.tar.xz  
　　**LibRaw:** https://www.libraw.org/data/LibRaw-0.21.1.tar.gz  
　　**Libsigc++:** https://download.gnome.org/sources/libsigc++/3.4/libsigc++-3.4.0.tar.xz  
　　**Libtasn1:** https://ftp.gnu.org/gnu/libtasn1/libtasn1-4.19.0.tar.gz  
　　**Libtool:** https://ftp.gnu.org/gnu/libtool/libtool-2.4.7.tar.xz  
　　**Libusb:** https://github.com/libusb/libusb/releases/download/v1.0.26/libusb-1.0.26.tar.bz2  
　　**Libunistring:** https://ftp.gnu.org/gnu/libunistring/libunistring-1.1.tar.xz  
　　**Libxcrypt:** https://github.com/besser82/libxcrypt/releases/download/v4.4.33/libxcrypt-4.4.33.tar.xz  
　　**Libxml2:** http://xmlsoft.org/sources/libxml2-2.9.12.tar.gz  
　　**Libxslt:** http://xmlsoft.org/sources/libxslt-1.1.34.tar.gz  
　　**Links:** http://links.twibright.com/download/links-2.29.tar.bz2  
　　**Linux-headers:** https://www.kernel.org/pub/linux/kernel/v6.x/linux-6.2.8.tar.xz  
　　**Linux:** ```https://github.com/loongson/linux.git 分支名“loongarch-next”```  
　　**Linux-Firmware:** https://mirrors.edge.kernel.org/pub/linux/kernel/firmware/linux-firmware-20230310.tar.xz  
　　**LLVM:** https://github.com/llvm/llvm-project/releases/download/llvmorg-16.0.0/llvm-project-16.0.0.src.tar.xz  
　　**Lua:** https://www.lua.org/ftp/lua-5.4.4.tar.gz  
　　**LVM2:** https://sourceware.org/ftp/lvm2/LVM2.2.03.20.tgz  
　　**M4:** https://ftp.gnu.org/gnu/m4/m4-1.4.19.tar.xz  
　　**Make:** https://ftp.gnu.org/gnu/make/make-4.4.1.tar.gz  
　　**Man-DB:** https://download.savannah.gnu.org/releases/man-db/man-db-2.11.2.tar.xz  
　　**Man-Pages:** https://www.kernel.org/pub/linux/docs/man-pages/man-pages-6.03.tar.xz  
　　**MarkupSafe:** https://files.pythonhosted.org/packages/source/M/MarkupSafe/MarkupSafe-2.1.2.tar.gz  
　　**Mdadm:** https://www.kernel.org/pub/linux/utils/raid/mdadm/mdadm-4.2.tar.xz  
　　**Meson:** https://github.com/mesonbuild/meson/archive/1.0.1/meson-1.0.1.tar.gz  
　　**MPC:** https://ftp.gnu.org/gnu/mpc/mpc-1.3.1.tar.gz  
　　**MPFR:** https://www.mpfr.org/mpfr-4.2.0/mpfr-4.2.0.tar.xz  
　　**Ncurses:** https://ftp.gnu.org/gnu/ncurses/ncurses-6.4.tar.gz  
　　**Net-Tools:** https://downloads.sourceforge.net/project/net-tools/net-tools-2.10.tar.xz  
　　**Nettle:** https://ftp.gnu.org/gnu/nettle/nettle-3.8.1.tar.gz  
　　**Ninja:** https://github.com/ninja-build/ninja/archive/v1.11.1/ninja-1.11.1.tar.gz  
　　**NSPR:** https://archive.mozilla.org/pub/nspr/releases/v4.35/src/nspr-4.35.tar.gz  
　　**NSS:** https://archive.mozilla.org/pub/security/nss/releases/NSS_3_89_RTM/src/nss-3.89.tar.gz  
　　**Openjpeg:** https://github.com/uclouvain/openjpeg/archive/v2.5.0/openjpeg-2.5.0.tar.gz  
　　**OpenSSL:** https://www.openssl.org/source/openssl-3.1.0.tar.gz  
　　**OpenSSH:** https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-9.3p1.tar.gz  
　　**P11-Kit:** https://github.com/p11-glue/p11-kit/releases/download/0.24.1/p11-kit-0.24.1.tar.xz  
　　**Patch:** https://ftp.gnu.org/gnu/patch/patch-2.7.6.tar.xz  
　　**PCIUtils:** https://mirrors.edge.kernel.org/pub/software/utils/pciutils/pciutils-3.9.0.tar.xz  
　　**PCRE:** https://sourceforge.net/projects/pcre/files/pcre/8.45/pcre-8.45.tar.bz2  
　　**PCRE2:** https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.42/pcre2-10.42.tar.bz2  
　　**Perl:** https://www.cpan.org/src/5.0/perl-5.36.0.tar.gz  
　　**Pkg-Config:** https://pkg-config.freedesktop.org/releases/pkg-config-0.29.2.tar.gz  
　　**Procps-NG:** https://sourceforge.net/projects/procps-ng/files/Production/procps-ng-4.0.3.tar.xz  
　　**PSmisc:** https://sourceforge.net/projects/psmisc/files/psmisc/psmisc-23.6.tar.xz  
　　**Python:** https://www.python.org/ftp/python/3.11.2/Python-3.11.2.tar.xz  
　　**Python-Pip:** https://files.pythonhosted.org/packages/6b/8b/0b16094553ecc680e43ded8f920c3873b01b1da79a54274c98f08cb29fca/pip-23.0.1.tar.gz  
　　**Python-Setuptools:** https://files.pythonhosted.org/packages/25/f3/d68c20919bc774c6cb127f1762f2f2f999d700a58198556e883dd3700e58/setuptools-67.6.0.tar.gz  
　　**QEMU:** https://download.qemu.org/qemu-7.2.0.tar.xz  
　　**Readline:** https://ftp.gnu.org/gnu/readline/readline-8.2.tar.gz  
　　**Ruby:** https://cache.ruby-lang.org/pub/ruby/3.2/ruby-3.2.1.tar.xz  
　　**Rust:** https://static.rust-lang.org/dist/rustc-1.68.1-src.tar.gz  
　　**Sed:** https://ftp.gnu.org/gnu/sed/sed-4.9.tar.xz  
　　**Shadow:** https://github.com/shadow-maint/shadow/releases/download/v4.11.1/shadow-4.11.1.tar.xz  
　　**Sqlite3:** https://github.com/sqlite/sqlite/archive/version-3.41.2/sqlite-3.41.2.tar.gz  
　　**Systemd:** https://github.com/systemd/systemd/archive/v253/systemd-253.tar.gz  
　　**Sudo:** https://www.sudo.ws/dist/sudo-1.9.13p3.tar.gz  
　　**Tar:** https://ftp.gnu.org/gnu/tar/tar-1.34.tar.xz  
　　**Tcl:** https://downloads.sourceforge.net/tcl/tcl8.6.13-src.tar.gz  
　　**Texinfo:** https://ftp.gnu.org/gnu/texinfo/texinfo-7.0.3.tar.xz  
　　**Tiff:** https://download.osgeo.org/libtiff/tiff-4.5.0.tar.xz  
　　**UnRAR:** https://www.rarlab.com/rar/unrarsrc-6.2.6.tar.gz  
　　**UnZip:** ftp://ftp.info-zip.org/pub/infozip/src/unzip60.tgz  
　　**URI:** https://www.cpan.org/authors/id/O/OA/OALDERS/URI-5.17.tar.gz  
　　**Usbutils:** https://www.kernel.org/pub/linux/utils/usb/usbutils/usbutils-015.tar.xz  
　　**Userspace-RCU:** https://lttng.org/files/urcu/userspace-rcu-0.14.tar.bz2  
　　**Util-Linux:** https://www.kernel.org/pub/linux/utils/util-linux/v2.38/util-linux-2.38.1.tar.xz  
　　**Vala:** https://download.gnome.org/sources/vala/0.56/vala-0.56.5.tar.xz  
　　**VIM:** https://github.com/vim/vim/archive/v9.0.1429/vim-9.0.1429.tar.gz  
　　**WGet:** https://ftp.gnu.org/gnu/wget/wget-1.21.3.tar.gz  
　　**Wireless-Tools:** https://hewlettpackard.github.io/wireless-tools/wireless_tools.29.tar.gz  
　　**Wpa_Supplicant:** https://w1.fi/releases/wpa_supplicant-2.10.tar.gz  
　　**Xfsprogs:** https://www.kernel.org/pub/linux/utils/fs/xfs/xfsprogs/xfsprogs-6.2.0.tar.xz  
　　**XML-Parser:** https://cpan.metacpan.org/authors/id/T/TO/TODDR/XML-Parser-2.46.tar.gz  
　　**XZ:** https://tukaani.org/xz/xz-5.4.2.tar.xz  
　　**Zip:** ftp://ftp.info-zip.org/pub/infozip/src/zip30.tgz  
　　**Zlib:** https://zlib.net/zlib-1.2.13.tar.xz  
　　**Zstd:** https://github.com/facebook/zstd/releases/download/v1.5.4/zstd-1.5.4.tar.gz    


　　以下是本次制作所需补丁文件的下载地址：

　　https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/ctags-5.8-fix_form_fedora.patch  
　　https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/ctags-5.8-for-gcc_12.patch  
　　https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/gc-8.0.6-add-loongarch.patch  
　　https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/kbd-2.4.0-backspace-1.patch  
　　https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/nspr-4.32-add-loongarch64.patch  
　　https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/stack-direction-add-loongarch.patch  
　　https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/perl-5.36.0-loongarch64-config.sh  
　　https://downloads.sourceforge.net/sourceforge/libpng-apng/libpng-1.6.37-apng.patch.gz   
　　https://www.linuxfromscratch.org/patches/blfs/svn/wireless_tools-29-fix_iwlist_scanning-1.patch  
　　https://raw.githubusercontent.com/maximeh/buildroot/master/package/expect/0001-enable-cross-compilation.patch   
　　https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/rustc-1.65.0-add-loongarch-support.patch   
　　https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/userspace-rcu-0.13.1-add-loongarch64.patch  

其它文件下载地址：

　　**SSL证书文件:** https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/20210818/ssl-certs.tar.gz  
　　**时区文件:** https://data.iana.org/time-zones/releases/tzdata2023b.tar.gz


　　都下载完成后，离开"downloads"目录:

```sh
popd
```


## 3 制作交叉工具链及相关工具
　　接下来就正式进入交叉工具链和相关工具的制作环节。
### 3.1 Linux内核头文件

* 制作步骤  
　　按以下步骤制作Linux内核头文件并安装到目标系统目录中。

```sh
tar xvf ${DOWNLOADDIR}/linux-6.2.8.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/linux-6.2.8
	make mrproper
	make ARCH=loongarch INSTALL_HDR_PATH=dest headers_install
	find dest/include -name '.*' -delete
	mkdir -pv ${SYSDIR}/sysroot/usr/include
	cp -rv dest/include/* ${SYSDIR}/sysroot/usr/include
popd
```


### 3.2 交叉编译器之Binutils

* 制作步骤  
　　按以下步骤制作交叉编译工具链中的Binutils并安装到存放交叉工具链的目录中。

```sh
tar xvf ${DOWNLOADDIR}/binutils-2.40.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/binutils-2.40
	rm -rf gdb* libdecnumber readline sim
	mkdir tools-build
	pushd tools-build
    	CC=gcc AR=ar AS=as \
	    ../configure --prefix=${SYSDIR}/cross-tools --build=${CROSS_HOST} --host=${CROSS_HOST} \
	                 --target=${CROSS_TARGET} --with-sysroot=${SYSDIR}/sysroot --disable-nls \
	                 --disable-static --enable-64-bit-bfd
    	make configure-host ${JOBS}
    	make ${JOBS}
    	make install-strip
    	cp -v ../include/libiberty.h ${SYSDIR}/sysroot/usr/include
    popd
popd
```

### 3.3 GMP
　　制作交叉工具链中所使用的GMP软件包。

```sh
tar xvf ${DOWNLOADDIR}/gmp-6.2.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/gmp-6.2.1
	./configure --prefix=${SYSDIR}/cross-tools --enable-cxx --disable-static
	make ${JOBS}
	make install
popd
```

### 3.4 MPFR
　　制作交叉工具链中所使用的MPFR软件包。  

```sh
tar xvf ${DOWNLOADDIR}/mpfr-4.1.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/mpfr-4.1.0
	./configure --prefix=${SYSDIR}/cross-tools --disable-static --with-gmp=${SYSDIR}/cross-tools
	make ${JOBS}
	make install
popd
```

### 3.5 MPC
　　制作交叉工具链中所使用的MPC软件包。

```sh
tar xvf ${DOWNLOADDIR}/mpc-1.3.1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/mpc-1.3.1 
	./configure --prefix=${SYSDIR}/cross-tools --disable-static --with-gmp=${SYSDIR}/cross-tools
	make ${JOBS}
	make install
popd
```

### 3.6 交叉编译器之GCC（精简版）

* 代码准备  
　　GCC需要专门获取代码的方式，以下是获取步骤：

```sh
git clone git://sourceware.org/git/gcc.git --depth 1
pushd gcc
    git archive --format=tar --output ../gcc-13.0.0.tar "master"
popd
mkdir gcc-13.0.0
pushd gcc-13.0.0
    tar xvf ../gcc-13.0.0.tar
popd
tar -czf ${DOWNLOADDIR}/gcc-13.0.0.tar.gz gcc-13.0.0
```


* 制作步骤  
　　制作交叉编译器中的GCC，第一次编译交叉工具链的GCC需要采用精简方式进行编译和安装，否则会因为缺少目标系统的C库而导致部分内容编译链接失败，制作过程如下：

```sh
tar xvf ${DOWNLOADDIR}/gcc-13.0.0.tar.gz -C ${BUILDDIR} 
pushd ${BUILDDIR}/gcc-13.0.0
	mkdir tools-build
	pushd tools-build
		AR=ar LDFLAGS="-Wl,-rpath,${SYSDIR}/cross-tools/lib" \
		../configure --prefix=${SYSDIR}/cross-tools --build=${CROSS_HOST} --host=${CROSS_HOST} \
		             --target=${CROSS_TARGET} --disable-nls \
		             --with-mpfr=${SYSDIR}/cross-tools --with-gmp=${SYSDIR}/cross-tools \
		             --with-mpc=${SYSDIR}/cross-tools \
		             --with-newlib --disable-shared --with-sysroot=${SYSDIR}/sysroot \
		             --disable-decimal-float --disable-libgomp --disable-libitm \
		             --disable-libsanitizer --disable-libquadmath --disable-threads \
		             --disable-target-zlib --with-system-zlib --enable-checking=release \
		             --enable-default-pie \
		             --enable-languages=c
		make all-gcc all-target-libgcc ${JOBS}
		make install-strip-gcc install-strip-target-libgcc
	popd
popd
```

对于目标是LoongArch架构来说，目前有几个参数是需要特别注意的：  
* ```--with-newlib```，因为当前没有目标系统Glibc的支持，所以使用newlib来临时支援GCC的运行。    
* ```--disable-shared```，使用newlib需要配合该参数。
* ```--with-sysroot```， 指定默认使用的sysroot路径，该参数对交叉工具链来说极其重要。
* ```--enable-languages=c```，这次仅编译C语言的支持就可以了，因为当前没有目标系统的Glibc，只能制作精简版。
* ```--enable-default-pie```，设置gcc默认使用fpie选项编译源代码。


### 3.7 Automake
　　Automake软件包中提供了许多软件包集成用来生成Makefile文件的脚本，但该脚本目标尚未增加对LoongArch架构的支持，因此需要对软件包打补丁文件来增加支持，制作步骤如下：

```sh
tar xvf ${DOWNLOADDIR}/automake-1.16.5.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/automake-1.16.5
	./configure --prefix=${SYSDIR}/cross-tools
	make ${JOBS}
	make install
popd
```

　　打上补丁并安装到交叉工具链的目录中，这样当后续有软件包需要更新脚本文件时就可以通过本次安装的Automake中的脚本文件来进行替换。

### 3.8 目标系统的Glibc
　　在制作并安装好交叉工具链的Binutils、精简版的GCC以及Linux内核的头文件后就可以编译目标系统的Glibc了，制作和安装步骤如下：

```sh
tar xvf ${DOWNLOADDIR}/glibc-2.37.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/glibc-2.37
    sed -i "s@5.15.0@4.15.0@g" sysdeps/unix/sysv/linux/loongarch/configure{,.ac}
    mkdir -v build-64
    pushd build-64
	    BUILD_CC="gcc" CC="${CROSS_TARGET}-gcc ${BUILD64} -mlarge-func-call" \
        CXX="${CROSS_TARGET}-gcc ${BUILD64} -mlarge-func-call" \
        AR="${CROSS_TARGET}-ar" RANLIB="${CROSS_TARGET}-ranlib" \
        ../configure --prefix=/usr --host=${CROSS_TARGET} --build=${CROSS_HOST} \
	                 --libdir=/usr/lib64 --libexecdir=/usr/lib64/glibc \
	                 --with-binutils=${SYSDIR}/cross-tools/bin \
	                 --with-headers=${SYSDIR}/sysroot/usr/include \
	                 --enable-stack-protector=strong --enable-add-ons \
	                 --disable-werror libc_cv_slibdir=/usr/lib64 \
	                 --enable-kernel=4.15
		make ${JOBS}
		make DESTDIR=${SYSDIR}/sysroot install
		cp -v ../nscd/nscd.conf ${SYSDIR}/sysroot/etc/nscd.conf
		mkdir -pv ${SYSDIR}/sysroot/var/cache/nscd
		install -v -Dm644 ../nscd/nscd.tmpfiles \
		                  ${SYSDIR}/sysroot/usr/lib/tmpfiles.d/nscd.conf
		install -v -Dm644 ../nscd/nscd.service \
		                  ${SYSDIR}/sysroot/usr/lib/systemd/system/nscd.service
	popd
	mkdir -v build-locale
	pushd build-locale
		../configure --prefix=/usr --libdir=/usr/lib64 --libexecdir=/usr/lib64/glibc \
	                 --enable-stack-protector=strong --enable-add-ons \
	                 --disable-werror libc_cv_slibdir=/usr/lib64
		make ${JOBS}
		make DESTDIR=${SYSDIR}/sysroot localedata/install-locales
	popd
popd

```
　　```sed -i "s@5.15.0@4.15.0@g" sysdeps/unix/sysv/linux/loongarch/configure{,.ac}``` Glibc默认支持的内核为5.15以上版本，这里用来将内核版本的需求降低到4.15，以便使用较低版本的内核。
　　```cp -v ${SYSDIR}/cross-tools/share/automake*/config.* ./scripts``` Glibc源码当前集成的探测架构脚本未支持LoongArch，该步骤就是复制支持的脚本到Glibc的源码目录中。
　　```make update-syscall-lists``` 为保持与目标系统所用内核相一致的系统调用，可使用该命令进行同步。
　　Glibc是目标系统的一部分，因此指定prefix等路径参数时是按照常规系统的路径进行设置的，所以必须在安装时指定DESTDIR来指定安装到存放目标系统的目录中。

### 3.9 交叉编译器之GCC（完整版）
　　完成目标系统的Glibc之后就可以着手制作交叉工具链中完整版的GCC了，制作步骤如下：

```sh
tar xvf ${DOWNLOADDIR}/gcc-13.0.0.tar.gz -C ${BUILDDIR} 
pushd ${BUILDDIR}/gcc-13.0.0
	mkdir tools-build-all
	pushd tools-build-all
		AR=ar LDFLAGS="-Wl,-rpath,${SYSDIR}/cross-tools/lib" \
		../configure --prefix=${SYSDIR}/cross-tools --build=${CROSS_HOST} \
		             --host=${CROSS_HOST} --target=${CROSS_TARGET} \
		             --with-sysroot=${SYSDIR}/sysroot --with-mpfr=${SYSDIR}/cross-tools \
		             --with-gmp=${SYSDIR}/cross-tools --with-mpc=${SYSDIR}/cross-tools \
		             --enable-__cxa_atexit --enable-threads=posix --with-system-zlib \
		             --enable-libstdcxx-time --enable-checking=release \
		             --enable-default-pie \
		             --enable-languages=c,c++,fortran,objc,obj-c++,lto
		make ${JOBS}
		make install-strip
	popd
popd
```

在完成目标系统的Glibc之后就可以增加和修改一些编译参数了，主要是如下：  
* 去掉了```--with-newlib```和```--disable-shared```，因为有Glibc，所以不再需要newlib了。  
* ```--enable-threads=posix```,可以设置线程支持了。
* ```--enable-languages=c,c++,fortran,objc,obj-c++,lto```，可以支持更多的开发语言了。
* ```--enable-default-pie```，默认使用pie方式进行编译链接。

### 3.10 File
　　File软件包的官方发布版已经集成了LoongArch的支持，可以识别出LoongArch架构的二进制文件，制作时使用5.40以上的版本。

```sh
tar xvf ${DOWNLOADDIR}/file-5.44.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/file-5.44
	./configure --prefix=${SYSDIR}/cross-tools
	make ${JOBS}
	make install
popd
```

### 3.11 Autoconf

```sh
tar xvf ${DOWNLOADDIR}/autoconf-2.71.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/autoconf-2.71
	./configure --prefix=${SYSDIR}/cross-tools
	make ${JOBS}
	make install
popd
```

### 3.12 Libtool

```sh
tar xvf ${DOWNLOADDIR}/libtool-2.4.7.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libtool-2.4.7
	./configure --prefix=${SYSDIR}/cross-tools
	make ${JOBS}
	make install
popd
```



### 3.13 Pkg-Config
　　为了能在交叉编译目标系统的过程中使用目标系统中已经安装的“pc”文件，我们在交叉工具链的目录中安装一个专门用来从目标系统目录中的查询“pc”文件的pkg-config命令，制作过程如下：

```sh
tar xvf ${DOWNLOADDIR}/pkg-config-0.29.2.tar.gz -C ${BUILDDIR}/
pushd ${BUILDDIR}/pkg-config-0.29.2
	./configure --prefix=${SYSDIR}/cross-tools \
	            --with-pc_path=${SYSDIR}/sysroot/usr/lib64/pkgconfig:${SYSDIR}/sysroot/usr/share/pkgconfig \
	            --program-prefix=${CROSS_TARGET}- --with-internal-glib --disable-host-tool
	make ${JOBS}
	make install
popd
```

### 3.14 Ninja
	编译目标系统的过程中会对Ninja版本有一定要求，因此在交叉工具链的目录中安装一个版本较新的Ninja。

```sh
tar xvf ${DOWNLOADDIR}/ninja-1.11.1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/ninja-1.11.1
	python3 configure.py --bootstrap
	install -vm755 ninja ${SYSDIR}/cross-tools/bin/
popd
```


### 3.15 Groff
	编译目标系统的过程中会对Groff版本有一定要求，因此在交叉工具链的目录中安装一个版本较新的Groff。

```sh
tar xvf ${DOWNLOADDIR}/groff-1.22.4.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/groff-1.22.4
	PAGE=A4 ./configure --prefix=${SYSDIR}/cross-tools
	make ${JOBS}
	make install
popd
```

### 3.16 Guile
	编译目标系统的过程中会需要用到Guile软件包提供的工具，在交叉工具链的目录中安装一个版本较新的Guile。
```sh
tar xvf ${DOWNLOADDIR}/guile-3.0.9.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/guile-3.0.9
    patch -Np1 -i ${DOWNLOADDIR}/guile-3.0.8-add-loongarch64.patch
    ./configure --prefix=${SYSDIR}/cross-tools
    make ${JOBS}
    make install
popd
```

### 3.17 Perl
	为了配合目标系统中编译Perl相关的软件包时能使用正确的路径，因此我们需要在交叉工具链中安装一个目标系统相同版本的Perl软件包。

```sh
tar xvf ${DOWNLOADDIR}/perl-5.36.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/perl-5.36.0
    sed -i "s@/usr/include@${SYSDIR}/cross-tools/include@g" ext/Errno/Errno_pm.PL
    CFLAGS="-D_LARGEFILE64_SOURCE" ./configure.gnu --prefix=${SYSDIR}/cross-tools \
    	         -Dprivlib=${SYSDIR}/cross-tools/lib/perl5/5.36/core_perl \
	             -Darchlib=${SYSDIR}/cross-tools/lib64/perl5/5.36/core_perl \
	             -Dsitelib=${SYSDIR}/cross-tools/lib/perl5/5.36/site_perl \
	             -Dsitearch=${SYSDIR}/cross-tools/lib64/perl5/5.36/site_perl \
	             -Dvendorlib=${SYSDIR}/cross-tools/lib/perl5/5.36/vendor_perl \
	             -Dvendorarch=${SYSDIR}/cross-tools/lib64/perl5/5.36/vendor_perl
    make ${JOBS}
    make install
popd
```

### 3.18 XML-Parser
	给交叉工具链中的Perl提供XML-Parser软件包提供的Perl组件。

```sh
tar xvf ${DOWNLOADDIR}/XML-Parser-2.46.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/XML-Parser-2.46
    ${SYSDIR}/cross-tools/bin/perl Makefile.PL
    make ${JOBS}
    make install
popd
```

### 3.19 URI
	给交叉工具链中的Perl提供URI软件包提供的Perl组件。

```sh
tar xvf ${DOWNLOADDIR}/URI-5.17.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/URI-5.17
    ${SYSDIR}/cross-tools/bin/perl Makefile.PL
    make ${JOBS}
    make install
popd
```

### 3.20 Python3
```sh
tar xvf ${DOWNLOADDIR}/Python-3.10.4.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/Python-3.10.4
	./configure --prefix=${SYSDIR}/cross-tools --with-platlibdir=lib64 \
	            --disable-shared --with-system-expat --with-system-ffi \
	            --with-ensurepip=yes --enable-optimizations \
	            ac_cv_broken_sem_getvalue=yes
	make ${JOBS}
	make install
	sed -i "s@-lutil @@g" ${SYSDIR}/cross-tools/bin/python3.10-config
	cp ${SYSDIR}/cross-tools/lib64/python3.10/_sysconfigdata__linux_{x86_64-linux-gnu,${CROSS_TARGET}}.py
	sed -i -e "/'CC'/s@'gcc@'${CROSS_TARGET}-gcc@g" \
	       -e "/'CXX'/s@'g++@'${CROSS_TARGET}-g++@g" \
	       -e "/'LDSHARED'/s@'gcc@'${CROSS_TARGET}-gcc@g" \
	       -e "/'SOABI'/s@-x86_64-linux-gnu@@g" \
	       -e "/'EXT_SUFFIX'/s@-x86_64-linux-gnu@@g" \
	       ${SYSDIR}/cross-tools/lib64/python3.10/_sysconfigdata__linux_${CROSS_TARGET}.py
popd
```

### 3.21 Jinja
```sh
tar xvf ${DOWNLOADDIR}/Jinja2-3.0.3.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/Jinja2-3.0.3
    python3 setup.py install --optimize=1
popd
```


### 3.22 Qemu

```sh
tar xvf ${DOWNLOADDIR}/qemu-7.2.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/qemu-7.2.0.tar.xz
    mkdir build
    pushd build
        ../configure --prefix=${SYSDIR}/cross-tools --target-list=loongarch64-linux-user --static
        ninja
        cp qemu-loongarch64 ${SYSDIR}/cross-tools/bin/qemu-loongarch64.bin
    popd
popd

echo '#!/bin/bash -e
/opt/mylaos/cross-tools/bin/qemu-loongarch64.bin -L /opt/mylaos/sysroot "$@"' \
> ${SYSDIR}/cross-tools/bin/qemu-loongarch64

echo '#!/bin/bash -e
/opt/mylaos/cross-tools/bin/qemu-loongarch64.bin -L /opt/mylaos/sysroot -E LD_TRACE_LOADED_OBJECTS=1 "$@"' \
> ${SYSDIR}/cross-tools/bin/qemu-loongarch64-ldd

chmod +x ${SYSDIR}/cross-tools/bin/qemu-loongarch64{,-ldd}

```
　　上面步骤中创建了两个脚本命令qemu-loongarch64和qemu-loongarch64-ldd，前者可以执行目标系统中的二进制程序，后者可以查看目标系统的二进制程序或库文件需要的动态链接库。

### 3.23 Meson
　　目标系统中部分软件对meson有版本要求，我们在交叉工具链的环境中提供一个较高版本的meson。

```sh
tar xvf ${DOWNLOADDIR}/meson-1.0.1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/meson-1.0.1
    ${SYSDIR}/cross-tools/bin/python3 setup.py build
    ${SYSDIR}/cross-tools/bin/python3 setup.py install
popd
```


### 3.24 Gobject-Introspection
```sh
tar xvf ${DOWNLOADDIR}/gobject-introspection-1.76.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/gobject-introspection-1.76.1
    mkdir native-build
    pushd native-build
        meson --prefix=${SYSDIR}/cross-tools \
              --buildtype=release ..
        ninja
        ninja install
    popd
popd

cat > ${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-g-ir-scanner << EOF
#!/bin/bash -e
LD_LIBRARY_PATH=${CROSSTOOLS_DIR}/lib64/ \
${SYSDIR}/cross-tools/bin/g-ir-scanner \
      --add-include-path=${SYSDIR}/sysroot/usr/share/gir-1.0 \
      --use-binary-wrapper=${SYSDIR}/cross-tools/bin/qemu-loongarch64 \
      --use-ldd-wrapper=${SYSDIR}/cross-tools/bin/qemu-loongarch64-ldd "\$@"
EOF
chmod +x ${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-g-ir-scanner

cat > ${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-g-ir-compiler << EOF
#!/bin/bash -e
LD_LIBRARY_PATH=${CROSSTOOLS_DIR}/lib64/ \
${SYSDIR}/cross-tools/bin/g-ir-compiler \
          --includedir=/${SYSDIR}/sysroot/usr/share/gir-1.0 "\$@"
EOF
chmod +x ${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-g-ir-compiler

```
　　为了在给目标系统中的一些软件正确生成对应的gir文件，我们在交叉编译目录中增加脚本命令来完成这个目标。

### 3.25 Vala
```sh
tar xvf ${DOWNLOADDIR}/vala-0.56.5.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/vala-0.56.5
    ./configure --prefix=${SYSDIR}/cross-tools --disable-valadoc
    make ${JOBS}
    make install
popd
cat > ${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-vapigen << EOF
#!/bin/bash -e
${SYSDIR}/cross-tools/bin/vapigen --vapidir=${SYSDIR}/sysroot/usr/share/vala/vapi \
                                  --girdir=${SYSDIR}/sysroot/usr/share/gir-1.0  "\$@"
EOF
chmod +x ${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-vapigen

cat > ${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-valac << EOF
#!/bin/bash -e
${SYSDIR}/cross-tools/bin/valac --vapidir=${SYSDIR}/sysroot/usr/share/vala/vapi "\$@"
EOF
chmod +x ${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-valac

```

### 3.26 LLVM

```sh
tar xvf ${DOWNLOADDIR}/llvm-project-16.0.0.src.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/llvm-project-16.0.0.src/llvm
    mkdir native-build
    pushd native-build
        LDFLAGS="" PKG_CONFIG_SYSROOT_DIR="" \
        cmake .. -G Ninja -DCMAKE_INSTALL_PREFIX:PATH=${SYSDIR}/cross-tools \
                 -DCMAKE_CXX_COMPILER="g++" -DCMAKE_C_COMPILER="gcc" \
                 -DBUILD_SHARED_LIBS:BOOL=OFF   -DCMAKE_BUILD_TYPE=Release  \
                 -DLLVM_LIBDIR_SUFFIX=64 \
                 -DCMAKE_C_FLAGS="-DNDEBUG" -DCMAKE_CXX_FLAGS="-DNDEBUG" \
                 -DLLVM_ENABLE_LIBCXX:BOOL=OFF \
                 -DLLVM_ENABLE_RTTI:BOOL=ON -DLLVM_BUILD_LLVM_DYLIB:BOOL=ON  \
                 -DLLVM_LINK_LLVM_DYLIB:BOOL=ON  \
                 -DCMAKE_INSTALL_RPATH="${SYSDIR}/cross-tools/lib64;\\\${ORIGIN}/../lib64" \
                 -DLLVM_BUILD_EXTERNAL_COMPILER_RT:BOOL=ON   \
                 -DLLVM_INSTALL_TOOLCHAIN_ONLY:BOOL=OFF \
                 -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD="LoongArch" \
                 -DLLVM_DEFAULT_TARGET_TRIPLE=${CROSS_TARGET}
        ninja
        ninja install
        cp -a ${SYSDIR}/cross-tools/bin/llvm-config \
              ${SYSDIR}/sysroot/usr/bin/loongarch64-unknown-linux-gnu-llvm-config
        ln -sfv ${SYSDIR}/sysroot/usr/bin/loongarch64-unknown-linux-gnu-llvm-config \
                ${SYSDIR}/cross-tools/bin/
    popd
popd
```

### 3.27 Clang

```sh
tar xvf ${DOWNLOADDIR}/llvm-project-16.0.0.src.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/llvm-project-16.0.0.src/clang
    mkdir native-build
    pushd native-build
        LDFLAGS="" PKG_CONFIG_SYSROOT_DIR="" \
        cmake .. -G Ninja -DCMAKE_INSTALL_PREFIX:PATH=${SYSDIR}/cross-tools \
                 -DCMAKE_CXX_COMPILER="g++" -DCMAKE_C_COMPILER="gcc" \
                 -DBUILD_SHARED_LIBS:BOOL=OFF \
                 -DCMAKE_BUILD_TYPE=Release \
                 -DCMAKE_INSTALL_RPATH="${SYSDIR}/cross-tools/lib64;\\\${ORIGIN}/../lib64" \
                 -DCMAKE_C_FLAGS="-DNDEBUG" -DCMAKE_CXX_FLAGS="-DNDEBUG" \
                 -DLLVM_LIBDIR_SUFFIX=64  \
                 -DLLVM_INSTALL_TOOLCHAIN_ONLY:BOOL=OFF \
                 -DDEFAULT_SYSROOT:PATH="${SYSDIR}/sysroot"
        ninja
        ninja install
        cp -av bin/clang-tblgen ${SYSDIR}/cross-tools/bin/
    popd
popd
```

### 3.28 Rust

　　编译Rust需要主系统中有一个已经可以使用且版本和目标系统编译的版本相同或者上一个版本，若主系统中没有对应的版本我们可以通过rust的官方下载一个主系统上能运行的安装包。
　　以x86_64的环境为例，按照以下步骤进行下载和安装Rust。

```sh
wget https://static.rust-lang.org/dist/rust-1.68.1-x86_64-unknown-linux-gnu.tar.gz
tar xvf rust-1.68.1-x86_64-unknown-linux-gnu.tar.gz
pushd rust-1.68.1-x86_64-unknown-linux-gnu
    ./install.sh --destdir=${SYSDIR}/cross-tools/rust
popd
```

　　完成主系统的Rust安装后，就可以给编译交叉工具链制作Rust软件包了，这样才能在后续进行目标系统Rust的制作。

```sh
tar xvf ${DOWNLOADDIR}/rustc-1.68.1-src.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/rustc-1.68.1-src
    rm -rf src/llvm-project
    tar xvf ${DOWNLOADDIR}/llvm-project-16.0.0.src.tar.xz -C src/
    mv src/llvm-project-16.0.0.src src/llvm-project
    patch -Np1 -i ${DOWNLOADDIR}/rustc-1.65.0-add-loongarch-support.patch
    sed -i "s@ifdef LLVM_RUSTLLVM@if 0@g" compiler/rustc_llvm/llvm-wrapper/PassWrapper.cpp
    find vendor -name .cargo-checksum.json \
          -exec sed -i.uncheck -e 's/"files":{[^}]*}/"files":{ }/' '{}' '+'
    ./configure --target=${CROSS_TARGET},$(echo ${CROSS_HOST} | sed 's@cross@unknown@g') \
                --prefix=${SYSDIR}/cross-tools --sysconfdir=${SYSDIR}/cross-tools/etc \
                --local-rust-root=${SYSDIR}/cross-tools/rust/usr/local \
                --enable-extended --enable-vendor --release-channel=stable \
                --disable-codegen-tests --experimental-targets=""
    make TARGET_CC="${CROSS_TARGET}-gcc" ${JOBS}
    make TARGET_CC="${CROSS_TARGET}-gcc" install
popd
```
　　因Rust自带一套LLVM的源码，但该源码未必支持LoongArch，我们就用已支持LoongArch的LLVM源码来替换Rust自带的源码，并给Rust打上支持LoongArch的补丁，以使该Rust源码编译出来的rust可以生成LoongArch架构的二进制代码。

### 3.29 Lua

```sh
tar xvf ${DOWNLOADDIR}/lua-5.4.4.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/lua-5.4.4
    sed -i '/#define LUA_ROOT/s:/usr/local/:/usr/:' src/luaconf.h
    make MYCFLAGS="-fPIC" linux ${JOBS}
    make INSTALL_TOP=${SYSDIR}/cross-tools \
         INSTALL_LIB=${SYSDIR}/cross-tools/lib64 \
         INSTALL_MAN=${SYSDIR}/cross-tools/share/man/man1 install
popd
```

### 3.30 Ruby

```sh
tar xvf ${DOWNLOADDIR}/ruby-3.1.3.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/ruby-3.1.3
    ./configure --prefix=${SYSDIR}/cross-tools
    make ${JOBS}
    make install
popd
```

### 3.31 Wayland
https://wayland.freedesktop.org/releases/wayland-1.21.92.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/wayland-1.21.92.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/wayland-1.21.92
    mkdir build
    pushd build
        meson --prefix=${SYSDIR}/cross-tools --buildtype=release \
              -Ddocumentation=false ..
        ninja
        ninja install
    popd
popd
```

### 3.32 CMake

```
tar xvf ${DOWNLOADDIR}/cmake-3.26.1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/cmake-3.26.1
    patch -Np1 -i ${DOWNLOADDIR}/cmake-3.22.3-add-loongarch64-to-checktypesize.patch
    mkdir build
    pushd build
        cmake -DCMAKE_INSTALL_PREFIX=${SYSDIR}/cross-tools -DCMAKE_BUILD_TYPE=RELEASE ..
        make ${JOBS}
        make install
    popd
popd
```

### 3.33 Elfutils
```sh
tar xvf ${DOWNLOADDIR}/elfutils-0.189.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/elfutils-0.189
	./configure --prefix=${SYSDIR}/cross-tools --disable-debuginfod --enable-libdebuginfod=dummy
	make ${JOBS}
	make install
popd
```

### 3.34 GDB
```sh
tar xvf ${DOWNLOADDIR}/gdb-13.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/gdb-13.1
	mkdir build
	pushd build
		../configure --prefix=${SYSDIR}/cross-tools --build=${CROSS_HOST} \
		             --host=${CROSS_HOST} --target=${CROSS_TARGET} \
		             --with-sysroot=${SYSDIR}/sysroot --enable-64-bit-bfd
		make ${JOBS}
		make install
	popd
popd
```

### 3.35 Grub2
　　为了在交叉编译的环境下可以制作生成LoongArch机器上使用的EFI启动文件，我们在交叉工具链目录中存放一个可以生成目标机器EFI的Grub软件包。

* 代码准备  
　　Grub2需要进行扩充式移植的软件包，在没有软件官方支持的情况下需要专门的获取代码的方式进行，以下是获取方式：

```sh
git clone -b "dev/patchwork/efi" https://github.com/loongarch64/grub.git --depth 1
pushd grub
    git archive --format=tar --output ../grub-2.11.tar "dev/patchwork/efi"
    ./bootstrap
    pushd gnulib
        git archive --format=tar --output ../../gnulib.tar HEAD
    popd
popd
mkdir grub-2.11
pushd grub-2.11
    tar xvf ../grub-2.11.tar
    mkdir gnulib
    tar xvf ../gnulib.tar -C gnulib
    ./bootstrap
popd
tar -czf ${DOWNLOADDIR}/grub-2.11.tar.gz grub-2.11

```

* 制作步骤  

```sh
tar -xvf ${DOWNLOADDIR}/grub-2.11.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/grub-2.11
    autoreconf -ifv
	mkdir build
	pushd build
		TARGET_CC="${CROSS_TARGET}-gcc" \
		../configure --build=${CROSS_HOST} --host=${CROSS_HOST} \
		             --target=${CROSS_TARGET} --prefix=${SYSDIR}/cross-tools \
		             --program-transform-name=s,grub,${CROSS_TARGET}-grub, \
		             --with-platform=efi --with-utils=host --disable-werror
		make ${JOBS}
		make install
	popd
popd
```
　　本次制作的Grub命令可以运行在X86的Linux系统环境中但可以生成LoongArch机器上使用的EFI文件。


## 4 制作目标系统
　　交叉工具链及其相关的工具制作并安装完成后就可以继续制作目标系统了。
　　
### 4.1 软件包制作说明

#### 架构测试脚本替换
　　在制作目标系统的过程中会经常遇到configure阶段提示不识别loongarch64架构的字样，这通常是软件包自带的架构探测脚本没有增加对loongarch64架构的识别，因此需要去对该问题进行处理，处理的方式通常有两种：  
　　1. 删除配置脚本，然后通过automake命令自动将新的探测脚本加入到软件包中，具体的操作方式为：  

```sh
rm config.guess config.sub
automake --add-missing
```

　　这里假定config.guess和config.sub两个脚本文件在软件包的第一级目录下，也可能是在build-aux之类的目录，找到文件并删除，然后使用automake命令的“--add-missing”参数来运行，该参数会自动确认是否缺少探测架构的脚本，如果缺少会从Automake软件包安装的目录中复制过来，因automake运行的是我们在交叉工具链目录中的，所以已经增加了LoongArch架构的判断，这样软件包就可以正常运行了。

　　2.直接替换文件，具体的操作方式为：

```sh
cp ${SYSDIR}/sysroot/usr/share/automake-1.16/config.* config/
```

　　如果使用automake命令无法解决，可以直接复制Automake软件包安装的脚本文件，以我们安装的Automake-1.16.x版本为例，从${SYSDIR}/sysroot/usr/share/automake-1.16/中复制config开头的文件覆盖当前要编译的软件包中的同名文件即可，这里假定需要覆盖的文件在config目录中，也可能是在其它目录，可根据需要进行覆盖。

　　也可能一个软件包中有多个探测脚本，那么就需要全部进行覆盖。
　　
#### 安装目标系统中的软件包
　　目标系统中的软件包安装的时候都是按照根目录（“/”）来存放的，所以如果直接安装那么就会安装到主系统的目录中，这必然是不对的，所以我们在安装的时候增加“DESTDIR”参数指定一个目录，那么安装的文件将以该指定目录作为安装的根目录进行安装，当我们设置为目标系统存放的目录时，就可以避开与主系统的冲突也可以让安装的软件包以正常的目录结构进行安装。

　　在后续的制作过程中会看到大多数软件包都支持“DESTDIR”参数设置，但也有个别软件包不支持，这种情况下通常采用软件包支持的类似功能参数来解决。

#### 交叉编译软件包
　　通常在带有configure配置脚本的软件包可以使用“build”、“host”参数来指定编译方式，当“build”和“host”相同时是本地编译，不同时就是交叉编译。
　　
　　“build”参数可以理解为当前主系统所使用的架构系统信息，而“host”则是目标系统运行的架构系统信息，在本文中采用在x86的Linux系统中交叉编译LoongArch64架构的Linux系统，所以根据之前定义的环境变量，“build”指定为```${CROSS_HOST}```则代表了当前主系统，“host”指定为```${CROSS_TARGET}```则代表了要编译生成的目标架构系统。

　　由于是交叉编译，所以在软件包的配置阶段有可能探测的参数错误，这可能导致编译出来的软件包不匹配目标架构系统，这时可以采用指定部分探测参数的方式来解决，通常可以采用创建config.cache文件，然后将一些需要探测的参数和取值写入到该文件中，例如：

```sh
cat > config.cache << "EOF"
    ac_cv_func_mmap_fixed_mapped=yes
    ......
EOF
```

　　然后在configure的参数中指定```--cache-file=config.cache```，这样就可以在探测这些参数时使用文件中设置的值而不是尝试去探测，这可以避免探测到错误的取值。

#### 编译目录
　　多数软件包可以在软件包自己的“根目录”中进行配置和编译，但也有一些软件包会建议创建一个新的目录来配置和编译，对这些需要创建目录进行编译的软件包，我们通常采用在该软件目录下创建一个“build”开头的目录，并在该目录中进行编译，这样便于使用完软件包后的清理工作。

#### 清除编译目录
　　在完成交叉工具的编译后，建议清理一下```${BUILDDIR}```目录，因为该目录中所有文件都是编译过程需要用的，可以简单的将其中所有文件和目录都删除，例如使用如下命令(批量删除时需要注意不要误删系统文件或者重要数据)：

```sh
    rm -rf ${SYSDIR}/build/*
```

　　注意保留build目录本身，因为接下来还需要用到。

#### 设置环境变量

```sh
export LDFLAGS="-Wl,-rpath-link=${SYSDIR}/sysroot/usr/lib64"
export PKG_CONFIG_SYSROOT_DIR=${SYSDIR}/sysroot
export PKG_CONFIG_PATH="${SYSDIR}/sysroot/usr/lib64/pkgconfig:${SYSDIR}/sysroot/usr/share/pkgconfig"
export JOBS="-j8"
```

### 4.2 软件包的制作

#### Man-Pages
```sh
tar xvf ${DOWNLOADDIR}/man-pages-6.03.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/man-pages-6.03
	make prefix=/usr DESTDIR=${SYSDIR}/sysroot install
popd
```
　　Man-Pages软件包没有配置阶段，直接安装到目标系统的目录中即可。

#### Iana-Etc
```sh
tar xvf ${DOWNLOADDIR}/iana-etc-20230320.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/iana-etc-20230320
	cp -v services protocols ${SYSDIR}/sysroot/etc
popd
```
　　Iana-Etc软件包无需配置编译，只要将包含的文件复制到目标系统的目录中即可。

#### TZ-Data
```sh
mkdir ${BUILDDIR}/tzdata-2023
tar xvf ${DOWNLOADDIR}/tzdata2023b.tar.gz -C ${BUILDDIR}/tzdata-2023
pushd ${BUILDDIR}/tzdata-2023
    ZONEINFO=${SYSDIR}/sysroot/usr/share/zoneinfo
    mkdir -pv $ZONEINFO/{posix,right}
    for tz in etcetera southamerica northamerica europe africa antarctica  \
              asia australasia backward; do
        /sbin/zic -L /dev/null   -d $ZONEINFO       ${tz}
        /sbin/zic -L /dev/null   -d $ZONEINFO/posix ${tz}
        /sbin/zic -L leapseconds -d $ZONEINFO/right ${tz}
    done
    cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
    /sbin/zic -d $ZONEINFO -p Asia/Shanghai
    unset ZONEINFO
    ln -sfv /usr/share/zoneinfo/Asia/Shanghai ${SYSDIR}/sysroot/etc/localtime
popd
```
tzdata软件包安装的是一组时区文件，这些文件可以设置系统当前的时区，让系统了解哪些时间是正确的。

#### GMP
```sh
tar xvf ${DOWNLOADDIR}/gmp-6.2.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/gmp-6.2.1
	rm config.guess config.sub
	automake --add-missing
	./configure --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --prefix=/usr --libdir=/usr/lib64 --enable-cxx
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
	rm -v ${SYSDIR}/sysroot/usr/lib64/lib{gmp,gmpxx}.la
popd
```
　　GMP软件包自带的探测架构脚本不支持LoongArch，因此删除探测脚本并用automake命令重新安装探测脚本。

#### MPFR
```sh
tar xvf ${DOWNLOADDIR}/mpfr-4.2.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/mpfr-4.2.0
	./configure --build=${CROSS_HOST} --host=${CROSS_TARGET} --prefix=/usr --libdir=/usr/lib64
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
	rm -v ${SYSDIR}/sysroot/usr/lib64/libmpfr.la
popd
```

#### MPC
```sh
tar xvf ${DOWNLOADDIR}/mpc-1.3.1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/mpc-1.3.1
	rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
	automake --add-missing
	./configure --build=${CROSS_HOST} --host=${CROSS_TARGET} --prefix=/usr --libdir=/usr/lib64
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
	rm -v ${SYSDIR}/sysroot/usr/lib64/libmpc.la
popd
```

#### Zlib
```sh
tar xvf ${DOWNLOADDIR}/zlib-1.2.13.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/zlib-1.2.13
	CROSS_PREFIX=${CROSS_TARGET}- ./configure --prefix=/usr --libdir=/usr/lib64
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Binutils
　　这次编译的Binutils是目标系统中使用的，在交叉编译阶段不会使用到它。

```sh
tar xvf ${DOWNLOADDIR}/binutils-2.40.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/binutils-2.40
	rm -rf gdb* libdecnumber readline sim
	mkdir cross-build
	pushd cross-build
		../configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
		             --host=${CROSS_TARGET} --enable-shared --disable-werror \
		             --with-system-zlib --enable-64-bit-bfd
		make tooldir=/usr ${JOBS}
		make DESTDIR=${SYSDIR}/sysroot tooldir=/usr install
	popd
popd
```

#### GCC
　　与上面编译的Binutils一样，这次编译的GCC也是在目标系统中使用的编译器，在交叉编译阶段不会使用到它，但是其提供的libgcc、libstdc++等库可以为后续软件包的编译提供链接用的库。

```sh
tar xvf ${DOWNLOADDIR}/gcc-13.0.0.tar.gz -C ${BUILDDIR} 
pushd ${BUILDDIR}/gcc-13.0.0
	sed -i 's@\./fixinc\.sh@-c true@' gcc/Makefile.in
	mkdir cross-build
	pushd cross-build
		../configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
		             --host=${CROSS_TARGET} --target=${CROSS_TARGET} \
		             --enable-__cxa_atexit --enable-threads=posix \
		             --with-system-zlib --enable-libstdcxx-time \
		             --enable-checking=release \
		             --with-build-sysroot=${SYSDIR}/sysroot \
		             --enable-default-pie \
		             --enable-languages=c,c++,fortran,objc,obj-c++,lto
		make ${JOBS}
		make DESTDIR=${SYSDIR}/sysroot install
		ln -sv /usr/bin/cpp ${SYSDIR}/sysroot/lib
		ln -sv gcc ${SYSDIR}/sysroot/usr/bin/cc
	popd
popd
```

　　因在目标系统中使用，所以编译的完整一些，将C、C++以及Fortran等语言的支持加上。

#### Bzip2
```sh
tar xvf ${DOWNLOADDIR}/bzip2-1.0.8.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/bzip2-1.0.8
	sed -i.orig -e "/^all:/s/ test//" Makefile
	sed -i -e 's:ln -s -f $(PREFIX)/bin/:ln -s -f :' Makefile
	sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
	make CC=${CROSS_TARGET}-gcc -f Makefile-libbz2_so ${JOBS}
	make clean
	make CC=${CROSS_TARGET}-gcc ${JOBS}
	make PREFIX=${SYSDIR}/sysroot/usr install
	cp -v bzip2-shared ${SYSDIR}/sysroot/bin/bzip2
	cp -av libbz2.so* ${SYSDIR}/sysroot/lib64
	ln -sfv ../../lib64/libbz2.so.1.0 ${SYSDIR}/sysroot/usr/lib64/libbz2.so
	ln -sfv bzip2 ${SYSDIR}/sysroot/bin/bunzip2
	ln -sfv bzip2 ${SYSDIR}/sysroot/bin/bzcat
popd
```
　　制作Bzip2软件包的过程用了两次make来生成了共享库和静态库，将它们都安装到目标系统中。
　　由于Bzip2软件包没有configure的配置脚本，因此在编译的时候直接给make命令指定CC参数，该参数用来设置编译程序时使用的编译器命令名，这里设置了交叉编译器的命令名，使得接下来的编译采用交叉编译器进行。
　　安装Bzip2软件包时因没有DESTDIR参数用来设置安装根目录，所以在PREFIX参数中加入目标系统存放目录的路径。

#### XZ
```sh
tar xvf ${DOWNLOADDIR}/xz-5.4.2.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/xz-5.4.2
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
	rm ${SYSDIR}/sysroot/usr/lib64/liblzma.la
popd
```

#### Zstd
```sh
tar xvf ${DOWNLOADDIR}/zstd-1.5.4.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/zstd-1.5.4
	make CC="${CROSS_TARGET}-gcc" PREFIX=/usr LIBDIR=/usr/lib64 ${JOBS}
	make CC="${CROSS_TARGET}-gcc" PREFIX=/usr LIBDIR=/usr/lib64 DESTDIR=${SYSDIR}/sysroot install
popd
```


#### File
```sh
tar xvf ${DOWNLOADDIR}/file-5.44.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/file-5.44
	rm config.{sub,guess}
	automake --add-missing
	./configure --prefix=/usr  --libdir=/usr/lib64 --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Ncurses
```sh
tar xvf ${DOWNLOADDIR}/ncurses-6.4.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/ncurses-6.4
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
	            --host=${CROSS_TARGET} --with-shared --without-debug \
	            --without-normal --enable-pc-files --without-ada \
	            --with-pkg-config-libdir=/usr/lib64/pkgconfig --enable-widec \
	            --disable-stripping
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
	
	for lib in ncurses form panel menu ; do
	    rm -vf                    ${SYSDIR}/sysroot/usr/lib64/lib${lib}.so
	    echo "INPUT(-l${lib}w)" > ${SYSDIR}/sysroot/usr/lib64/lib${lib}.so
	    ln -sfv ${lib}w.pc        ${SYSDIR}/sysroot/usr/lib64/pkgconfig/${lib}.pc
	done
	
	rm -vf  ${SYSDIR}/sysroot/usr/lib64/libcursesw.so
	echo "INPUT(-lncursesw)" > ${SYSDIR}/sysroot/usr/lib64/libcursesw.so
	ln -sfv libncurses.so      ${SYSDIR}/sysroot/usr/lib64/libcurses.so
	rm -fv ${SYSDIR}/sysroot/usr/lib64/libncurses++w.a
popd

cp -v ${SYSDIR}/sysroot/usr/bin/ncursesw6-config ${SYSDIR}/cross-tools/bin/
sed -i "s@-L\$libdir@@g" ${SYSDIR}/cross-tools/bin/ncursesw6-config
```
　　在安装完目标系统的Ncurses后，复制了一个ncursesw6-config脚本命令到交叉编译目录中，这是因为后续编译一些软件包时会调用该命令来获取安装到目标系统中的Nucrses库链接信息，而如果主系统中的库与目标系统中的库链接不一致可能导致链接失败，因此提供一个可以正确链接信息的脚本是有效的解决方案。

#### Readline
```sh
tar xvf ${DOWNLOADDIR}/readline-8.2.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/readline-8.2
	sed -i '/MV.*old/d' Makefile.in
	sed -i '/{OLDSUFF}/c:' support/shlib-install
	rm support/config.{sub,guess}
	automake --add-missing
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} --host=${CROSS_TARGET} \
				--disable-static --with-curses
	make SHLIB_LIBS="-lncursesw" ${JOBS}
	make SHLIB_LIBS="-lncursesw" DESTDIR=${SYSDIR}/sysroot install
popd
```

　　因交叉编译的原因，Redaline的配置脚本无法正确的探测目标系统中安装的Ncurses软件包，因此在配置中加入```--with-curses```参数保证加入Ncurses的支持以及在编译阶段加入```SHLIB_LIBS="-lncursesw"```以保证正确链接库文件。

#### M4
```sh
tar xvf ${DOWNLOADDIR}/m4-1.4.19.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/m4-1.4.19
	patch -Np1 -i ${DOWNLOADDIR}/stack-direction-add-loongarch.patch
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### BC
```sh
tar xvf ${DOWNLOADDIR}/bc-6.5.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/bc-6.5.0
	CC="${CROSS_TARGET}-gcc" HOSTCC="gcc" ./configure --prefix=/usr
	make ${JOBS}
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
	make ${JOBS}
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
	make ${JOBS}
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
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
	rm ${SYSDIR}/sysroot/usr/lib64/libacl.la
popd
```

#### Libcap
```sh
tar xvf ${DOWNLOADDIR}/libcap-2.68.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libcap-2.68
	make CROSS_COMPILE="${CROSS_TARGET}-" BUILD_CC="gcc" GOLANG=no prefix=/usr lib=lib64 ${JOBS}
	make CROSS_COMPILE="${CROSS_TARGET}-" BUILD_CC="gcc" GOLANG=no prefix=/usr lib=lib64 \
		 DESTDIR=${SYSDIR}/sysroot install
popd
```

　　因为该软件包没有配置脚本，所以直接在make命令上增加指定编译器的参数```CROSS_COMPILE="${CROSS_TARGET}-"```，这里要注意CROSS_COMPILE指定的是交叉编译工具的前缀而不是具体命令名，这样在编译过程中各种编译、汇编和链接相关的命令都会自动加上这个指定的前缀。

　　另外在编译过程中会编译在主系统中运行的程序，这个时候不能使用交叉编译器编译，所以还需要指定```BUILD_CC="gcc"```这个参数来保证编译这些要运行的程序使用的是本地编译器。

#### Shadow
```sh
tar xvf ${DOWNLOADDIR}/shadow-4.11.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/shadow-4.11.1
	sed -i 's/groups$(EXEEXT) //' src/Makefile.in
	find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \;
	find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
	find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;
	sed -e 's:#ENCRYPT_METHOD DES:ENCRYPT_METHOD SHA512:' \
	    -e 's:#SHA_CRYPT_:SHA_CRYPT_:'                    \
	    -e 's:/var/spool/mail:/var/mail:'                 \
	    -e '/PATH=/{s@/sbin:@@;s@/bin:@@}'                \
	    -i etc/login.defs
	./configure --sysconfdir=/etc --libdir=/usr/lib64 --build=${CROSS_HOST} --host=${CROSS_TARGET} \
				--with-group-name-max-length=32
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot exec_prefix=/usr install
	mkdir -pv ${SYSDIR}/sysroot/etc/default
popd
```

　　该软件包修改了一些默认的设置，下面介绍以下主要修改的内容：  
　　1、将用户密码的加密模式从DES改为SHA512，后者相对前者更难破解。  
　　2、一些默认路径的修改。

#### Sed
```sh
tar xvf ${DOWNLOADDIR}/sed-4.9.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/sed-4.9
	rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
	automake --add-missing
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make ${JOBS}
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
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
	mkdir -p ${SYSDIR}/cross-tools/tmp/bin
	ln -sf /bin/pkg-config ${SYSDIR}/cross-tools/tmp/bin/${CROSS_TARGET}-pkg-config
popd
```
　　在制作目标系统的Pkg-config软件包的配置过程中因无法探测目标系统中的部分配置设置而会导致配置失败，因此需要在configure阶段强制设置部分参数的取值。

#### PSmisc
```sh
tar xvf ${DOWNLOADDIR}/psmisc-23.6.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/psmisc-23.6
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Gettext
```sh
tar xvf ${DOWNLOADDIR}/gettext-0.21.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/gettext-0.21.1
	sed -i "/hello-c++-kde/d" gettext-tools/examples/Makefile.in
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
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
	rm -v ${SYSDIR}/sysroot/usr/lib64/libgettext*.la
	rm -v ${SYSDIR}/sysroot/usr/lib64/libtextstyle.la
popd
```
　　Gettext软件包的源码中有多处探测架构的脚本，这些脚本在当前的版本中均不支持LoongArch架构，所以找到全部探测脚本并进行替换。


#### Bison
```sh
tar xvf ${DOWNLOADDIR}/bison-3.8.2.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/bison-3.8.2
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### TCL
```sh
tar xvf ${DOWNLOADDIR}/tcl8.6.13-src.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/tcl8.6.13
    SRCDIR=$(pwd)
    pushd unix
	    ./configure --prefix=/usr --libdir=/usr/lib64 --mandir=/usr/share/man \
	                --build=${CROSS_HOST} --host=${CROSS_TARGET} --enable-64bit
	    make ${JOBS}
	    sed -i -e "s|$SRCDIR/unix|${SYSDIR}/sysroot/usr/lib64|" \
	           -e "s|$SRCDIR|${SYSDIR}/sysroot/usr/include|" \
	           -e "/TCL_INCLUDE_SPEC/s|/usr/include|${SYSDIR}/sysroot/usr/include|" \
	           tclConfig.sh
	    sed -i -e "s|$SRCDIR/unix/pkgs/tdbc1.1.3|${SYSDIR}/sysroot/usr/lib64/tdbc1.1.3|" \
               -e "s|$SRCDIR/pkgs/tdbc1.1.3/generic|${SYSDIR}/sysroot/usr/include|"    \
               -e "s|$SRCDIR/pkgs/tdbc1.1.3/library|${SYSDIR}/sysroot/usr/lib64/tcl8.6|" \
               -e "s|$SRCDIR/pkgs/tdbc1.1.3|${SYSDIR}/sysroot/usr/include|"            \
               pkgs/tdbc1.1.3/tdbcConfig.sh
	    sed -i -e "s|$SRCDIR/unix/pkgs/itcl4.2.2|${SYSDIR}/sysroot/usr/lib64/itcl4.2.2|" \
               -e "s|$SRCDIR/pkgs/itcl4.2.2/generic|${SYSDIR}/sysroot/usr/include|"    \
               -e "s|$SRCDIR/pkgs/itcl4.2.2|${SYSDIR}/sysroot/usr/include|"            \
               pkgs/itcl4.2.2/itclConfig.sh
	    unset SRCDIR
	    make DESTDIR=${SYSDIR}/sysroot install
	    make DESTDIR=${SYSDIR}/sysroot install-private-headers
	    ln -sfv tclsh8.6 ${SYSDIR}/sysroot/usr/bin/tclsh
	popd
popd
```


#### Expect
```sh
tar xvf ${DOWNLOADDIR}/expect5.45.4.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/expect5.45.4
    patch -Np1 -i ${DOWNLOADDIR}/0001-enable-cross-compilation.patch
    autoreconf -ifv
	./configure --prefix=/usr --libdir=/usr/lib64 \
	            --build=${CROSS_HOST} --host=${CROSS_TARGET} \
	            --with-tcl=${SYSDIR}/sysroot/usr/lib64 \
	            --enable-shared
	make ${JOBS}
	make TCLSH_PROG=/usr/bin/tclsh DESTDIR=${SYSDIR}/sysroot install
	ln -svf expect5.45.4/libexpect5.45.4.so ${SYSDIR}/sysroot/usr/lib64
popd
```

#### Dejagnu
```sh
tar xvf ${DOWNLOADDIR}/dejagnu-1.6.3.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/dejagnu-1.6.3
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Grep
```sh
tar xvf ${DOWNLOADDIR}/grep-3.10.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/grep-3.10
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Bash
```sh
tar xvf ${DOWNLOADDIR}/bash-5.2.15.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/bash-5.2.15
	cp -v ${SYSDIR}/cross-tools/share/automake-1.16/config.{sub,guess} support/

cat > config.cache << "EOF"
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
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
	ln -sv bash ${SYSDIR}/sysroot/bin/sh
popd
```

　　Bash软件在交叉编译时的配置阶段会有大量的参数探测错误，需要我们手工指定这些参数的真实取值，创建一个文本文件，将这些参数的取值写进去，并在configure配置中增加```--cache-file=config.cache```参数（其中config.cache就是保存参数的文本文件名）。

#### Libtool
```sh
tar xvf ${DOWNLOADDIR}/libtool-2.4.7.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libtool-2.4.7
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
sed -i -e "s@/opt/mylaos/cross-tools/loongarch64-unknown-linux-gnu@/usr@g" \
       -e "s@/opt/mylaos/cross-tools/lib/gcc@/usr/lib64/gcc@g" \
       -e "s@/opt/mylaos/cross-tools/bin@/usr/bin@g" \
       -e "s@/opt/mylaos/sysroot/lib@/usr/lib@g" \
       -e "s@/opt/mylaos/sysroot/usr@/usr@g" \
       -e "s@loongarch64-unknown-linux-gnu-@@g" \
       /opt/mylaos/sysroot/usr/bin/libtool
```
　　交叉编译生成的libtool文件中包含了大量的在交叉编译中使用的路径，因此在目标系统中使用libtool会存在路径不对的问题，我们通过sed命令将这些交叉编译环境中的路径转换成目标系统实际的路径。

#### GDBM
```sh
tar xvf ${DOWNLOADDIR}/gdbm-1.23.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/gdbm-1.23
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
	            --host=${CROSS_TARGET} --disable-static --enable-libgdbm-compat
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
	rm ${SYSDIR}/sysroot/usr/lib64/libgdbm*.la
popd
```

#### GPerf
```sh
tar xvf ${DOWNLOADDIR}/gperf-3.1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/gperf-3.1
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Expat
```sh
tar xvf ${DOWNLOADDIR}/expat-2.5.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/expat-2.5.0
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
	            --host=${CROSS_TARGET} --without-docbook
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
	rm -v ${SYSDIR}/sysroot/usr/lib64/libexpat.la
popd
```

#### Autoconf
```sh
tar xvf ${DOWNLOADDIR}/autoconf-2.71.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/autoconf-2.71
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Automake
```sh
tar xvf ${DOWNLOADDIR}/automake-1.16.5.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/automake-1.16.5
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

　　在交叉编译目录中我们安装了一个Automake软件包，该软件包提供了增加LoongArch支持的探测脚本，有很多软件都会需要用这些脚本来覆盖自己源代码中的脚本。

　　在制作的目标系统中当然也需要改其中的Automake软件包，也使其支持LoongArch，这样将来在目标系统中配置编译一些软件包时就可以使用上。

#### Kmod
```sh
tar xvf ${DOWNLOADDIR}/kmod-30.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/kmod-30
	rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
	automake --add-missing
	./configure --prefix=/usr --libdir=/usr/lib64 --bindir=/bin \
	            --sysconfdir=/etc --build=${CROSS_HOST} --host=${CROSS_TARGET} \
	            --with-xz --with-zstd --with-zlib
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
	
	for target in depmod insmod lsmod modinfo modprobe rmmod; do
		ln -sfv ../bin/kmod ${SYSDIR}/sysroot/sbin/$target
	done
	ln -sfv kmod ${SYSDIR}/sysroot/bin/lsmod
popd
```

#### Libelf
```sh
tar xvf ${DOWNLOADDIR}/elfutils-0.189.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/elfutils-0.189
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
				--host=${CROSS_TARGET} --disable-debuginfod --enable-libdebuginfod=dummy \
				ac_cv_null_dereference=no
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
echo '#!/bin/bash -e
qemu-loongarch64 /opt/mylaos/sysroot/usr/bin/eu-readelf "$@"' > ${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-eu-readelf
chmod +x ${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-eu-readelf
```

　　该软件包使用交叉编译会有个别功能探测错误，使用指定参数和取值的方式来解决，该制作步骤上采用了另一种设置参数取值的方式，若要指定的参数数值不多的情况下可以直接在configure的参数中进行设置,如```ac_cv_null_dereference=no```这就是这种设置方式，也可以通过将这两个参数写到“config.cache”，然后通过“--cache-file=config.cache”来使用。

#### Libffi

* 制作步骤  
```sh
tar xvf ${DOWNLOADDIR}/libffi-3.4.4.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libffi-3.4.4
    ./autogen.sh
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
	            --host=${CROSS_TARGET} --disable-static --with-gcc-arch=native
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### OpenSSL
```sh
tar xvf ${DOWNLOADDIR}/openssl-3.1.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/openssl-3.1.0
	CC="${CROSS_TARGET}-gcc" \
	./Configure --prefix=/usr --openssldir=/etc/ssl \
				--libdir=lib64 shared zlib linux-generic64
	make ${JOBS}
	sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

　　OpenSSL是一个十分重要的安全算法库，通常对不同的架构可以使用汇编对算法进行优化，但其也提供了通用的C实现，因此可以采用```linux-generic64```来指定用通用实现进行编译，当然通用实现的性能是相对较低的，在今后如果有了针对LoongArch64的优化支持则可以修改该参数来达到优化编译的目的。

#### Coreutils
```sh
tar xvf ${DOWNLOADDIR}/coreutils-9.2.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/coreutils-9.2
	FORCE_UNSAFE_CONFIGURE=1 \
	./configure --prefix=/usr  --build=${CROSS_HOST} --host=${CROSS_TARGET} \
				--enable-no-install-program=kill,uptime
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
	mv -v ${SYSDIR}/sysroot/usr/bin/chroot ${SYSDIR}/sysroot/usr/sbin
popd
echo '#!/bin/bash -e
qemu-loongarch64 /opt/mylaos/sysroot/usr/bin/uname "$@"' > ${SYSDIR}/cross-tools/bin/cross-uname
chmod +x ${SYSDIR}/cross-tools/bin/cross-uname
```
　　这里创建一个为交叉编译使用的uname脚本，通过该脚本可以获得目标架构的名称，可以提供给需要的软件包使用。

#### Check
```sh
tar xvf ${DOWNLOADDIR}/check-0.15.2.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/check-0.15.2
	./configure --prefix=/usr --libdir=/usr/lib64 \
	            --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Diffutils
```sh
tar xvf ${DOWNLOADDIR}/diffutils-3.9.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/diffutils-3.9
	rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
	automake -a
	./configure --prefix=/usr  --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Gawk
```sh
tar xvf ${DOWNLOADDIR}/gawk-5.2.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/gawk-5.2.1
	sed -i 's/extras//' Makefile.in
	./configure --prefix=/usr  --libdir=/usr/lib64 --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Findutils
```sh
tar xvf ${DOWNLOADDIR}/findutils-4.9.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/findutils-4.9.0
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
	            --host=${CROSS_TARGET} --localstatedir=/var/lib/locate
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Intltool

```sh
tar xvf ${DOWNLOADDIR}/intltool-0.51.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/intltool-0.51.0
    sed -i 's:\\\${:\\\$\\{:' intltool-update.in
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
	sed -i "s@${SYSDIR}/cross-tools@@g" ${SYSDIR}/sysroot/usr/bin/intltool*
popd
```

#### Groff
```sh
tar xvf ${DOWNLOADDIR}/groff-1.22.4.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/groff-1.22.4
	rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
	automake --add-missing
	PAGE=A4 ./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make TROFFBIN=troff GROFFBIN=groff GROFF_BIN_PATH= ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Less
```sh
tar xvf ${DOWNLOADDIR}/less-608.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/less-608
	./configure --prefix=/usr --sysconfdir=/etc --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Gzip
```sh
tar xvf ${DOWNLOADDIR}/gzip-1.12.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/gzip-1.12
	rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
	automake --add-missing
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### IPRoute2
```sh
tar xvf ${DOWNLOADDIR}/iproute2-6.2.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/iproute2-6.2.0
	sed -i /ARPD/d Makefile
	rm -fv man/man8/arpd.8
	PKG_CONFIG=${CROSS_TARGET}-pkg-config \
	make CC="${CROSS_TARGET}-gcc" HOSTCC="gcc" KERNEL_INCLUDE=${SYSDIR}/sysroot/usr/include \
	     NETNS_RUN_DIR=/run/netns ${JOBS}
	PKG_CONFIG=${CROSS_TARGET}-pkg-config \
	make CC="${CROSS_TARGET}-gcc" HOSTCC="gcc" KERNEL_INCLUDE=${SYSDIR}/sysroot/usr/include \
		 SBINDIR=/usr/sbin DESTDIR=${SYSDIR}/sysroot install
popd
```

　　IPRoute2软件包没有配置阶段，直接在make命令中使用“CC”变量指定交叉编译器，而对于在编译过程中会临时编译一些在本地运行的程序时就需要使用“HOSTCC”变量来指定本地编译器，否则“HOSTCC”会使用“CC”变量的指定编译器，那么编译出来的程序就无法在交叉编译的主系统中运行了。

#### KBD
```sh
tar xvf ${DOWNLOADDIR}/kbd-2.5.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/kbd-2.5.1
	patch -Np1 -i ${DOWNLOADDIR}/kbd-2.4.0-backspace-1.patch
	sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
	sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
	autoreconf -ifv
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET} --disable-vlock
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

　　交叉编译KBD时可能会缺少链接库而导致制作失败，此时可以通过LIBS变量指定缺少链接的库而完成KBD软件包的制作。

#### Libpipeline
```sh
tar xvf ${DOWNLOADDIR}/libpipeline-1.5.7.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libpipeline-1.5.7
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Make
```sh
tar xvf ${DOWNLOADDIR}/make-4.4.1tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/make-4.4.1
	rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
	automake --add-missing
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Patch
```sh
tar xvf ${DOWNLOADDIR}/patch-2.7.6.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/patch-2.7.6
	./configure --prefix=/usr -build=${CROSS_HOST} --host=${CROSS_TARGET}
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### CURL
```sh
tar xvf ${DOWNLOADDIR}/curl-8.0.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/curl-8.0.1
    ./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
                --host=${CROSS_TARGET} --with-openssl \
                --enable-threaded-resolver --with-ca-path=/etc/ssl/certs
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
	cp ${SYSDIR}/sysroot/usr/bin/curl-config ${SYSDIR}/cross-tools/bin/
popd
```

#### CMake
```sh
tar xvf ${DOWNLOADDIR}/cmake-3.26.1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/cmake-3.26.1
    patch -Np1 -i ${DOWNLOADDIR}/cmake-3.22.3-add-loongarch64-to-checktypesize.patch
    mkdir build
    pushd build
        cmake -DCMAKE_CXX_COMPILER="${CROSS_TARGET}-g++" -DCMAKE_C_COMPILER="${CROSS_TARGET}-gcc" \
              -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_DOC_DIR=/share/doc/cmake-3.25 \
              -DOPENSSL_ROOT_DIR=${SYSDIR}/sysroot/usr -DCMAKE_BUILD_TYPE=RELEASE ../
        sed -i "/P cmake_install.cmake/s@\tbin/cmake@\t/bin/cmake@g" Makefile
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
popd
```

#### MarkupSafe
```sh
tar xvf ${DOWNLOADDIR}/MarkupSafe-2.1.2.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/MarkupSafe-2.1.2
    _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_${CROSS_TARGET} \
    ${SYSDIR}/cross-tools/bin/python3 setup.py build
    _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_${CROSS_TARGET} \
    ${SYSDIR}/cross-tools/bin/python3 setup.py install --optimize=1 --root=${SYSDIR}/sysroot --prefix=/usr
popd
```

#### Jinja2
```sh
tar xvf ${DOWNLOADDIR}/Jinja2-3.0.3.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/Jinja2-3.0.3
    ${SYSDIR}/cross-tools/bin/python3 setup.py build
    ${SYSDIR}/cross-tools/bin/python3 setup.py install \
             --optimize=1 --root=${SYSDIR}/sysroot --prefix=/usr
popd
```

#### Man-DB
```sh
tar xvf ${DOWNLOADDIR}/man-db-2.11.2.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/man-db-2.11.2
	rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
	automake --add-missing
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
	            --host=${CROSS_TARGET} --sysconfdir=/etc --disable-setuid \
	            --enable-cache-owner=bin 	--with-browser=/usr/bin/lynx \
	            --with-vgrind=/usr/bin/vgrind --with-grap=/usr/bin/grap
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Tar
```sh
tar xvf ${DOWNLOADDIR}/tar-1.34.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/tar-1.34
	FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Texinfo
```sh
tar xvf ${DOWNLOADDIR}/texinfo-7.0.3.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/texinfo-7.0.3
sed -e 's/__attribute_nonnull__/__nonnull/' \
    -i gnulib/lib/malloc/dynarray-skeleton.c
	for i in $(dirname $(find -name "config.sub"))
	do
		rm ./$i/config.{sub,guess}
		pushd $(dirname ./$i)
			automake --add-missing
		popd
	done
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
	make DESTDIR=${SYSDIR}/sysroot TEXMF=/usr/share/texmf install-tex
popd
```

#### VIM
```sh
tar xvf ${DOWNLOADDIR}/vim-9.0.1429.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/vim-9.0.1429
	echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
cat > src/auto/config.cache << EOF
	vim_cv_getcwd_broken=no
	vim_cv_toupper_broken=no
	vim_cv_terminfo=yes
	vim_cv_tgetent=zero
	vim_cv_stat_ignores_slash=no
	vim_cv_memmove_handles_overlap=yes
	ac_cv_small_wchar_t=no
EOF
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}  --with-tlib=ncurses
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot STRIP=${CROSS_TARGET}-strip install
	ln -sv vim ${SYSDIR}/sysroot/usr/bin/vi
popd
```

　　VIM制作过程中也需要设置一些参数避免自动探测错误，但VIM的参数设置文件是有默认文件路径的即“src/auto/config.cache”，在文件中写入参数和取值即可，configure配置脚本会自动从该文件中读取。

　　在安装完VIM后，我们可以配置VIM的默认设置文件，设置步骤如下：

```sh
cat > ${SYSDIR}/sysroot/etc/vimrc << "EOF"
let skip_defaults_vim=1 
set nocompatible
set backspace=2
set mouse=

if (&term == "xterm") || (&term == "putty")
  set background=dark
endif
EOF
```
　　改设置内容主要是设置了一些基本的界面和操作特性，如Tab转换成几个空格显示，不同的终端下背景颜色等等。

#### Util-Linux
```sh
tar xvf ${DOWNLOADDIR}/util-linux-2.38.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/util-linux-2.38.1
	cp ${SYSDIR}/sysroot/usr/share/automake-1.16/config.* config/
	./configure  --build=${CROSS_HOST} --host=${CROSS_TARGET} \
        ADJTIME_PATH=/var/lib/hwclock/adjtime \
        --libdir=/usr/lib64 \
        --disable-chfn-chsh --disable-login --disable-nologin \
        --disable-su --disable-setpriv --disable-runuser \
        --disable-pylibmount --disable-static --without-python \
        --without-systemd --disable-makeinstall-chown \
        runstatedir=/run
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
	rm -v ${SYSDIR}/sysroot/usr/lib64/lib{blkid,fdisk,mount,smartcols,uuid}.la
popd
```

　　Util-Linux带有大量的命令和库，由于部分命令已经在其它软件包中提供了，所以使用选项参数来关闭这些命令的编译和安装。

#### Systemd

* 代码准备  

```sh
git clone https://github.com/systemd/systemd.git --depth 1
pushd systemd
    git archive --format=tar --output ../systemd-git.tar "main"
popd
mkdir systemd-git
pushd systemd-git
    tar xvf ../systemd-git.tar
popd
tar -czf ${DOWNLOADDIR}/systemd-git.tar.gz systemd-git
```

　　Systemd采用的是meson命令进行配置阶段的操作，该命令与其他常见的configure脚本有明显的不同，所以在当前需要进行交叉编译的情况下也会采用完全不同的操作步骤，以下将展开进行说明。

```sh
tar xvf ${DOWNLOADDIR}/systemd-253.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/systemd-253
	pushd src/basic
        python3 missing_syscalls.py missing_syscall_def.h $(ls syscalls-*.txt)
	popd
	sed -i -e 's/GROUP="render"/GROUP="video"/' \
           -e 's/GROUP="sgx", //' rules.d/50-udev-default.rules.in
```

　　以上步骤是为了解压Systemd源代码和打上支持LoongArch64的补丁，并且对代码进行必要的修正。

　　接下来的步骤是制作一个为meson命令用来交叉编译配置的文本文件，步骤如下：

```sh
pushd ${BUILDDIR}
echo "[binaries]" > meson-cross.txt
echo "c = '${CROSS_TARGET}-gcc'" >> meson-cross.txt
echo "cpp = '${CROSS_TARGET}-g++'" >> meson-cross.txt
echo "ar = '${CROSS_TARGET}-ar'" >> meson-cross.txt
echo "strip = '${CROSS_TARGET}-strip'" >> meson-cross.txt
echo "objcopy = '${CROSS_TARGET}-objcopy'" >> meson-cross.txt
echo "pkgconfig = '${CROSS_TARGET}-pkg-config'" >> meson-cross.txt
echo "cups-config = '${CROSS_TARGET}-cups-config'" >> meson-cross.txt
echo "llvm-config = '${CROSS_TARGET}-llvm-config'" >> meson-cross.txt
echo "vala = '${CROSS_TARGET}-valac'" >> meson-cross.txt
echo "exe_wrapper = 'qemu-loongarch64'" >> meson-cross.txt
echo "[properties]" >> meson-cross.txt
echo "sys_root = '${SYSDIR}/sysroot'" >> meson-cross.txt
echo "pkg_config_libdir = '${SYSDIR}/sysroot/usr/lib64/pkgconfig:${SYSDIR}/sysroot/usr/share/pkgconfig'" >> meson-cross.txt
cat >> meson-cross.txt << "EOF"
[host_machine]
system = 'linux'
cpu_family = 'loongarch64'
cpu = 'loongarch64'
endian = 'little'
EOF
popd
```
　　以上步骤完成后将在${BUILDDIR}目录中生成一个meson-cross.txt文件，该文件包含了编译Systemd时目标架构的名字、系统、使用的工具链命令以及编译参数等等，这样在接下来的配置阶段中引用该文件就可以了。

　　以下是配置和编译的步骤：

```sh
	mkdir -p build
	pushd build
		meson --prefix=/usr --libdir=/usr/lib64 --sysconfdir=/etc --localstatedir=/var \
		      -Dbuildtype=release -Ddefault-dnssec=no -Dfirstboot=false \
		      -Dinstall-tests=false -Dldconfig=false -Dsysusers=false \
		      -Drpmmacrosdir=no -Dhomed=false -Duserdb=false -Dman=false -Dmode=release \
		      -Dpamconfdir=/etc/pam.d \
		      --cross-file ${BUILDDIR}/meson-cross.txt ..
		ninja
		DESTDIR=${SYSDIR}/sysroot ninja install
	popd
popd
```

　　较新版本的Systemd不再使用make命令进行编译了，配合meson使用ninja命令进行编译，在编译后同样用ninja命令安装软件包。

　　安装命令支持“DESTDIR”变量设置，但与make命令不同的是“DESTDIR”变量需要写在ninja命令的前面，安装的参数是“install”，该命令执行后同样将软件包安装到目标系统存放的目录中。


#### D-Bus
```sh
tar xvf ${DOWNLOADDIR}/dbus-1.15.4.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/dbus-1.15.4
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
	            --host=${CROSS_TARGET} --sysconfdir=/etc --localstatedir=/var --runstatedir=/run \
	            --disable-static --disable-doxygen-docs --disable-xml-docs \
	            --enable-user-session \
	            --with-console-auth-dir=/run/console \
	            --with-system-socket=/run/dbus/system_bus_socket
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
	rm -v ${SYSDIR}/sysroot/usr/lib64/libdbus-1.la
	ln -sfv /etc/machine-id ${SYSDIR}/sysroot/var/lib/dbus
popd
```

#### Procps-ng
```sh
tar xvf ${DOWNLOADDIR}/procps-ng-4.0.3.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/procps-ng-4.0.3
	./configure --prefix=/usr --libdir=/usr/lib64  --build=${CROSS_HOST} \
	            --host=${CROSS_TARGET} --disable-static --disable-kill --with-systemd \
	            ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

　　Procps-ng软件包也是在交叉编译方式上会出现参数判断错误的情况，需要在配置阶段指定参数和取值。

#### E2fsprogs
```sh
tar xvf ${DOWNLOADDIR}/e2fsprogs-1.47.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/e2fsprogs-1.47.0
	mkdir -v build
	pushd build
		../configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
		             --host=${CROSS_TARGET} --sysconfdir=/etc \
		             --enable-elf-shlibs --disable-libblkid \
		             --disable-libuuid --disable-uuidd --disable-fsck
		make ${JOBS} 
		make DESTDIR=${SYSDIR}/sysroot install
		rm -fv ${SYSDIR}/sysroot/usr/lib64/{libcom_err,libe2p,libext2fs,libss}.la
	popd
popd
cp -av ${SYSDIR}/sysroot/usr/bin/mk_cmds ${SYSDIR}/cross-tools/bin/
sed -i "s@=/usr@=${SYSDIR}/sysroot/usr@g" ${SYSDIR}/cross-tools/bin/mk_cmds
```


#### OpenSSH
```sh
tar xvf ${DOWNLOADDIR}/openssh-9.3p1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/openssh-9.3p1
	rm config.{sub,guess}
	automake --add-missing
	./configure --prefix=/usr  --libdir=/usr/lib64 --sysconfdir=/etc/ssh \
	            --build=${CROSS_HOST} --host=${CROSS_TARGET} \
	            --disable-strip --with-md5-passwords \
	            --with-privsep-path=/var/lib/sshd \
	            --with-default-path=/usr/bin \
 	            --with-superuser-path=/usr/sbin:/usr/bin \
	            --with-pid-dir=/run
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install-nokeys host-key
	install -v -m755 contrib/ssh-copy-id ${SYSDIR}/sysroot/usr/bin
popd
```

#### PCIUtils
```sh
tar xvf ${DOWNLOADDIR}/pciutils-3.9.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/pciutils-3.9.0
	make CROSS_COMPILE="${CROSS_TARGET}-" HOST="${CROSS_TARGET}" \
	     PREFIX=/usr SHARED=yes LIBDIR=/usr/lib64 ${JOBS}
	make CROSS_COMPILE="${CROSS_TARGET}-" HOST="${CROSS_TARGET}" \
	     PREFIX=/usr SHARED=yes LIBDIR=/usr/lib64 STRIP="" \
	     DESTDIR=${SYSDIR}/sysroot install install-lib
popd
```

#### WGet
```sh
tar xvf ${DOWNLOADDIR}/wget-1.21.3.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/wget-1.21.3
	rm build-aux/config.{sub,guess}
	automake --add-missing
	./configure --prefix=/usr --sysconfdir=/etc \
	            --build=${CROSS_HOST} --host=${CROSS_TARGET} \
	            --with-ssl=openssl
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### 安装证书
　　证书文件用来在使用SSL进行认证时提供相应的证书，如果没有对应的证书则会提示相关错误。

```sh
tar xvf ${DOWNLOADDIR}/ssl-certs.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/certs
    cp -a * ${SYSDIR}/sysroot/etc/ssl/certs/
popd
```

#### Inetutils
```sh
tar xvf ${DOWNLOADDIR}/inetutils-2.4.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/inetutils-2.4
 	sed -i "/PATH_PROCNET_DEV/s@no@/proc/net/dev@g" paths
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET} \
	            --disable-logger --disable-whois --disable-rcp \
	            --disable-rexec --disable-rlogin --disable-rsh \
	            --disable-servers
	make ${JOBS} 
	make DESTDIR=${SYSDIR}/sysroot install
	mv -v ${SYSDIR}/sysroot/usr/{,s}bin/ifconfig
	chmod -v +x ${SYSDIR}/sysroot/usr/bin/{ping{,6},traceroute}
popd
```

#### DHCPCD
```sh
tar xvf ${DOWNLOADDIR}/dhcpcd-9.4.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/dhcpcd-9.4.1
	./configure --prefix=/usr --sysconfdir=/etc --build=${CROSS_HOST} \
	            --host=${CROSS_TARGET} --disable-privsep
	make ${JOBS} 
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### 说明
　　当系统做到这里时已经可作为简单可用的状态，接下来可以直接跳入第5部分（“启动相关软件包”）继续后面的制作过程，但如果觉得系统的东西还不够的时候，可以继续下面的制作步骤。

### 4.3 更多软件包
　　在这节中的软件包不必全部都制作，可以根据需要选择制作，但需要注意的是软件包之间的依赖关系，如果有选择性的制作某个软件包时发现缺少必要的依赖条件，则可以先制作所需依赖的软件包。

#### Wireless-Tools
```sh
tar xvf ${DOWNLOADDIR}/wireless_tools.29.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/wireless_tools.29
    patch -Np1 -i ${DOWNLOADDIR}/wireless_tools-29-fix_iwlist_scanning-1.patch
    sed  -i.orig "/^INSTALL_LIB/s@/lib/@/lib64/@g" Makefile
	make CC=${CROSS_TARGET}-gcc ${JOBS} 
	make PREFIX=${SYSDIR}/sysroot/usr INSTALL_MAN=${SYSDIR}/sysroot/usr/share/man install
popd
```

#### Net-tools
```sh
tar xvf ${DOWNLOADDIR}/net-tools-2.10.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/net-tools-2.10
    yes "" | make BINDIR='/usr/bin' SBINDIR='/usr/bin' CC=${CROSS_TARGET}-gcc
    make BINDIR='/usr/bin' SBINDIR='/usr/bin' CC=${CROSS_TARGET}-gcc DESTDIR=${PWD}/dest install
    rm -v dest/usr/bin/{nis,yp}domainname
    rm -v dest/usr/bin/{hostname,dnsdomainname,domainname,ifconfig}
    rm -rv dest/usr/share/man/man1
    rm -rv dest/usr/share/man/man8/ifconfig.8
    cp -av dest/usr/bin/* ${SYSDIR}/sysroot/usr/bin/
    cp -av dest/usr/share/man/man* ${SYSDIR}/sysroot/usr/share/man/
popd
```

#### Libnl
```sh
tar xvf ${DOWNLOADDIR}/libnl-3.7.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libnl-3.7.0
	rm build-aux/config.{sub,guess}
	automake --add-missing
	./configure --prefix=/usr --sysconfdir=/etc --libdir=/usr/lib64 \
	            --build=${CROSS_HOST} --host=${CROSS_TARGET}
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Sudo
```sh
tar xvf ${DOWNLOADDIR}/sudo-1.9.13p3.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/sudo-1.9.13p3
    ./configure --prefix=/usr --libexecdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --with-secure-path --with-all-insults --with-env-editor \
                --with-passprompt="[sudo] password for %p: "
    sed -i "/^install_uid/s@= 0@= $(id -u)@g" Makefile
    sed -i "/^install_gid/s@= 0@= $(id -u)@g" Makefile
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
sed -i "/wheel ALL=(ALL:ALL) ALL/s@# @@g" ${SYSDIR}/sysroot/etc/sudoers.dist
```

#### SQLite3
```sh
unzip ${DOWNLOADDIR}/sqlite-3.41.2.tar.gz -d ${BUILDDIR}
pushd ${BUILDDIR}/sqlite-3.41.2
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
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libsqlite3*.la
popd
```

#### NSPR
```sh
tar xvf ${DOWNLOADDIR}/nspr-4.35.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/nspr-4.35/nspr
    patch -Np2 -i ${DOWNLOADDIR}/nspr-4.32-add-loongarch64.patch
    cp ${SYSDIR}/cross-tools/share/automake-*/config.* build/autoconf/
    ./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
                --host=${CROSS_TARGET} --with-mozilla \
                --with-pthreads --enable-64bit
    make CC="gcc" -C config
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### NSS
```sh
tar xvf ${DOWNLOADDIR}/nss-3.89.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/nss-3.89/nss
    make CC="gcc" -C coreconf/nsinstall BUILD_OPT=1 USE_64=1 \
         CPU_ARCH="loongarch64" CROSS_COMPILE=1 NSS_ENABLE_WERROR=0 OS_TEST="loongarch64"
    make NATIVE_CC="gcc" CC="${CROSS_TARGET}-gcc" CCC="${CROSS_TARGET}-g++" \
         BUILD_OPT=1 USE_64=1 CPU_ARCH="loongarch64" CROSS_COMPILE=1 \
         USE_SYSTEM_ZLIB=1 NSS_USE_SYSTEM_SQLITE=1 NSS_ENABLE_WERROR=0 \
         NSPR_INCLUDE_DIR=${SYSDIR}/sysroot/usr/include/nspr OS_TEST="loongarch64" -j1

    cat pkg/pkg-config/nss-config.in | sed -e "s,@prefix@,/usr,g" \
        -e "s,@MOD_MAJOR_VERSION@,$(cat lib/util/nssutil.h \
            | grep "#define.*NSSUTIL_VMAJOR" | awk '{print $3}'),g" \
        -e "s,@MOD_MINOR_VERSION@,$(cat lib/util/nssutil.h \
            | grep "#define.*NSSUTIL_VMINOR" | awk '{print $3}'),g" \
        -e "s,@MOD_PATCH_VERSION@,$(cat lib/util/nssutil.h \
            | grep "#define.*NSSUTIL_VPATCH" | awk '{print $3}'),g" \
        > ${SYSDIR}/sysroot/usr/bin/nss-config

    cat pkg/pkg-config/nss.pc.in | sed -e "s,%prefix%,/usr,g" \
        -e 's,%exec_prefix%,${prefix},g' -e "s,%libdir%,/usr/lib64,g" \
        -e 's,%includedir%,${prefix}/include/nss,g' \
        -e "s,%NSS_VERSION%,$(cat lib/util/nssutil.h \
            | grep "#define.*NSSUTIL_VERSION" | awk '{print $3}'),g" \
        -e "s,%NSPR_VERSION%,$(cat ${SYSDIR}/sysroot/usr/include/nspr/prinit.h \
            | grep "#define.*PR_VERSION" | awk '{print $3}'),g" \
        > ${SYSDIR}/sysroot/usr/lib64/pkgconfig/nss.pc
popd
pushd ${BUILDDIR}/nss-3.89/dist
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
tar xvf ${DOWNLOADDIR}/icu4c-72_1-src.tgz -C ${BUILDDIR}
pushd ${BUILDDIR}/icu/source
    touch config/icucross.mk
    touch config/icucross.inc
    sed -i '/^PKGDATA/s@$(TOOLBINDIR)@/bin@g' data/Makefile.in
    sed -i '/INVOKE/s@$(TOOLBINDIR)@/bin@g' data/Makefile.in extra/uconv/Makefile.in
    sed -i '/INVOKE/s@/bin/icupkg@/sbin/icupkg@g' data/Makefile.in
    ./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
                --host=${CROSS_TARGET} --with-cross-build=${PWD}
    sed -i '/INVOKE/s@$(TOOLBINDIR)@/bin@g' data/rules.mk
    sed -i '/INVOKE/s@/bin/icupkg@/sbin/icupkg@g' data/rules.mk
    sed -i '/INVOKE/s@/bin/gensprep@/sbin/gensprep@g' data/rules.mk
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Python3
```sh
tar xvf ${DOWNLOADDIR}/Python-3.11.2.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/Python-3.11.2
    cat > config.cache << "EOF"
    ac_cv_aligned_required=no
    ac_cv_broken_sem_getvalue=no
    ac_cv_computed_gotos=yes
    ac_cv_pthread_is_default=yes
    ac_cv_pthread_system_supported=yes
    ac_cv_working_tzset=yes
    ac_cv_buggy_getaddrinfo=no
    ac_cv_file__dev_ptmx=yes
    ac_cv_file__dev_ptc=no
EOF
	./configure --prefix=/usr  --libdir=/usr/lib64 \
	            --build=${CROSS_HOST} --host=${CROSS_TARGET} --enable-shared \
	            --with-system-expat --with-system-ffi --with-ensurepip=install \
	            --enable-optimizations --with-platlibdir=lib64 \
	            --cache-file=config.cache
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
ln -sv python3 ${SYSDIR}/sysroot/usr/bin/python
sed -i -e "s@${SYSDIR}/sysroot@@g" \
       -e "s@${CROSS_TARGET}-@@g" \
       ${SYSDIR}/sysroot/usr/lib64/python3.10/_sysconfigdata__linux_.py

cp -v ${SYSDIR}/cross-tools/bin/python3.10-config{,.tools}
cp -v ${SYSDIR}/sysroot/usr/bin/python3.10-config ${SYSDIR}/cross-tools/bin/
sed -i "/prefix_real/s@=.*@=${SYSDIR}/sysroot/usr@g" ${SYSDIR}/cross-tools/bin/python3.10-config
```

#### Python-Pip
```sh
tar xvf ${DOWNLOADDIR}/pip-23.0.1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/pip-23.0.1
    ${SYSDIR}/cross-tools/bin/python3 setup.py build
    ${SYSDIR}/cross-tools/bin/python3 setup.py install --root=${SYSDIR}/sysroot --prefix=/usr
    sed -i "s@${SYSDIR}/cross-tools@@g" ${SYSDIR}/sysroot/bin/pip{,3{,.10}}
popd
```

#### Python-Setuptools
```sh
tar xvf ${DOWNLOADDIR}/setuptools-67.6.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/setuptools-67.6.0
    ${SYSDIR}/cross-tools/bin/python3 setup.py build
    ${SYSDIR}/cross-tools/bin/python3 setup.py install --root=${SYSDIR}/sysroot --prefix=/usr
popd
```

#### Meson
```sh
tar xvf ${DOWNLOADDIR}/meson-1.0.1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/meson-1.0.1
    ${SYSDIR}/cross-tools/bin/python3 setup.py build
    ${SYSDIR}/cross-tools/bin/python3 setup.py install --root=${SYSDIR}/sysroot --prefix=/usr
    sed -i "s@${SYSDIR}/cross-tools@@g" ${SYSDIR}/sysroot/bin/meson
popd
```

#### Ninja
```sh
tar xvf ${DOWNLOADDIR}/ninja-1.11.1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/ninja-1.11.1
    CXX="${CROSS_TARGET}-g++" AR="${CROSS_TARGET}-ar" \
    ${SYSDIR}/cross-tools/bin/python3 configure.py
    ninja
    install -vm755 ninja ${SYSDIR}/sysroot/usr/bin/
popd
```

#### Perl5
```sh
tar xvf ${DOWNLOADDIR}/perl-5.36.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/perl-5.36.0
	sh Configure -des -Dprefix=/usr -Dvendorprefix=/usr \
	             -Dprivlib=/usr/lib/perl5/5.36/core_perl \
	             -Darchlib=/usr/lib64/perl5/5.36/core_perl \
	             -Dsitelib=/usr/lib/perl5/5.36/site_perl \
	             -Dsitearch=/usr/lib64/perl5/5.36/site_perl \
	             -Dvendorlib=/usr/lib/perl5/5.36/vendor_perl \
	             -Dvendorarch=/usr/lib64/perl5/5.36/vendor_perl \
	             -Dman1dir=/usr/share/man/man1 -Dman3dir=/usr/share/man/man3 \
	             -Dpager="/usr/bin/less -isR" -Duseshrplib -Dusethreads \
	             -Dusecrosscompile
	cp ${DOWNLOADDIR}/perl-5.36.0-loongarch64-config.sh ./config.sh
	sed -i "/^cc=/s@'cc'@'${CROSS_TARGET}-gcc'@g" config.sh
	sed -i "/^ld=/s@'cc'@'${CROSS_TARGET}-gcc'@g" config.sh
	./Configure -S
	make depend
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### XML-Parser
```sh
tar xvf ${DOWNLOADDIR}/XML-Parser-2.46.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/XML-Parser-2.46
    ${SYSDIR}/cross-tools/bin/perl Makefile.PL CC=${CROSS_TARGET}-gcc LD=${CROSS_TARGET}-ld
    sed -i "/^INSTALL/s@${SYSDIR}/cross-tools@/usr@g" Makefile Expat/Makefile
    sed -i "/^PERL_INC/s@${SYSDIR}/cross-tools@${SYSDIR}/sysroot/usr@g" Makefile Expat/Makefile
    sed -i "/^LDDLFLAGS/s@/usr/local/lib@${SYSDIR}/sysroot/usr/lib64@g" Makefile Expat/Makefile
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### URI
```sh
tar xvf ${DOWNLOADDIR}/URI-5.17.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/URI-5.17
    ${SYSDIR}/cross-tools/bin/perl Makefile.PL CC=${CROSS_TARGET}-gcc LD=${CROSS_TARGET}-ld
    sed -i "/^INSTALL/s@${SYSDIR}/cross-tools@/usr@g" Makefile
    sed -i "/^PERL_INC/s@${SYSDIR}/cross-tools@${SYSDIR}/sysroot/usr@g" Makefile
    sed -i "/^LDDLFLAGS/s@/usr/local/lib@${SYSDIR}/sysroot/usr/lib64@g" Makefile
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Libxml2
```sh
tar xvf ${DOWNLOADDIR}/libxml2-2.9.12.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libxml2-2.9.12
    rm config.{sub,guess}
    automake -a
    mkdir native-build
    pushd native-build
        PKG_CONFIG_PATH="" LDFLAGS="" PKG_CONFIG_SYSROOT_DIR="" \
        ../configure --prefix=${SYSDIR}/cross-tools --with-history --with-icu \
                     --with-python=${SYSDIR}/cross-tools/bin/python3
        make ${JOBS}
        make install
    popd
    mkdir cross-build
    pushd cross-build
        ../configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
                --host=${CROSS_TARGET} --with-history --with-icu \
                --with-python=${SYSDIR}/cross-tools/bin/python3 \
                --with-python_install_dir=/usr/lib64/python3.10/site-packages
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
        rm ${SYSDIR}/sysroot/usr/lib64/libxml2.la
    popd
popd
```

#### Libxslt
```sh
tar xvf ${DOWNLOADDIR}/libxslt-1.1.34.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libxslt-1.1.34
    rm config.{sub,guess}
    automake -a
    ./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
                --host=${CROSS_TARGET} --without-python
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### WPA_Supplicant
```sh
tar xvf ${DOWNLOADDIR}/wpa_supplicant-2.10.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/wpa_supplicant-2.10/wpa_supplicant
cat > .config << "EOF"
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
         BINDIR=/usr/sbin LIBDIR=/usr/lib64 ${JOBS}
    install -v -m755 wpa_{cli,passphrase,supplicant} ${SYSDIR}/sysroot/usr/sbin/
    install -v -m644 systemd/*.service ${SYSDIR}/sysroot/usr/lib/systemd/system/
    install -v -m644 dbus/fi.w1.wpa_supplicant1.service \
                     ${SYSDIR}/sysroot/usr/share/dbus-1/system-services/
    install -v -d -m755 ${SYSDIR}/sysroot/etc/dbus-1/system.d
    install -v -m644 dbus/dbus-wpa_supplicant.conf \
                     ${SYSDIR}/sysroot/etc/dbus-1/system.d/wpa_supplicant.conf
popd
```

#### GPM
　　GPM软件包提供了在文本环境下使用鼠标的工具。

```sh
tar xvf ${DOWNLOADDIR}/gpm-1.20.7.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/gpm-1.20.7
    patch -Np1 -i ${DOWNLOADDIR}/gpm-1.20.7-consolidated-1.patch
    patch -Np1 -i ${DOWNLOADDIR}/gpm-1.20.1-weak-wgetch.patch
    ./autogen.sh
    ./configure --prefix=/usr --libdir=/usr/lib64 --sysconfdir=/etc \
	            --build=${CROSS_HOST} --host=${CROSS_TARGET}
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    ln -sfv libgpm.so.2.1.0 ${SYSDIR}/sysroot/usr/lib64/libgpm.so
popd

cat > ${SYSDIR}/sysroot/etc/sysconfig/mouse << "EOF"
MDEVICE="/dev/input/mice"
PROTOCOL="imps2"
GPMOPTS=""
EOF

cat > ${SYSDIR}/sysroot/usr/lib/systemd/system/gpm.service << "EOF"
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
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Links
　　Links是一个文本环境下简易的互联网浏览器。

```sh
tar xvf ${DOWNLOADDIR}/links-2.29.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/links-2.29
    CC="${CROSS_TARGET}-gcc" \
    ./configure --prefix=/usr --libdir=/usr/lib64 --mandir=/usr/share/man \
	            --build=${CROSS_HOST} --host=${CROSS_TARGET}
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Doxygen
```sh
tar xvf ${DOWNLOADDIR}/doxygen-1.9.6.src.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/doxygen-1.9.6
    mkdir build
    pushd build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
              -DCMAKE_INSTALL_PREFIX=/usr -Wno-dev ..
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
popd
```

#### Git
```sh
tar xvf ${DOWNLOADDIR}/git-2.40.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/git-2.40.0
    ./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --with-gitconfig=/etc/gitconfig --with-python=python3 --without-iconv \
                 ac_cv_fread_reads_directories=yes ac_cv_snprintf_returns_bogus=no
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot perllibdir=/usr/lib/perl5/5.34/site_perl install
popd
```

#### GDB
　　GDB是由Binutils软件包提供的。

```sh
tar xvf ${DOWNLOADDIR}/gdb-13.0.50.20220801.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/gdb-13.0.50.20220801
    patch -Np1 -i ${DOWNLOADDIR}/0001-gdb-gdbserver-LoongArch-Improve-implementation-of-fc.patch
	mkdir cross-build
	pushd cross-build
		../configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
		             --host=${CROSS_TARGET} --enable-shared --disable-werror \
		             --with-system-zlib --enable-64-bit-bfd --with-system-readline \
		             --with-libgmp-prefix=${SYSDIR}/sysroot \
		             --with-libexpat-prefix=${SYSDIR}/sysroot
		make ${JOBS}
		make DESTDIR=${SYSDIR}/sysroot install
	popd
popd
```

#### Valgrind
* 准备代码

```sh
git clone https://github.com/loongson/valgrind-loongarch64/ -b loongarch64-linux --depth 1
pushd valgrind-loongarch64
    git archive --format=tar --output ../valgrind-git.tar "loongarch64-linux"
popd
mkdir valgrind-git
pushd valgrind-git
    tar xvf ../valgrind-git.tar
popd
tar -czf ${DOWNLOADDIR}/valgrind-git.tar.gz valgrind-git
```

* 编译步骤

```sh
tar xvf ${DOWNLOADDIR}/valgrind-git.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/valgrind-git
    autoreconf -ifv
    ./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} --host=${CROSS_TARGET}
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### CTags

```sh
tar xvf ${DOWNLOADDIR}/ctags-5.8.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/ctags-5.8
    patch -Np1 -i ${DOWNLOADDIR}/ctags-5.8-fix_form_fedora.patch
    patch -Np1 -i ${DOWNLOADDIR}/ctags-5.8-for-gcc_12.patch
    ./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Inih
```sh
tar xvf ${DOWNLOADDIR}/inih-r56.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/inih-r56
    mkdir build
    pushd build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Dosfstools
```sh
tar xvf ${DOWNLOADDIR}/dosfstools-4.2.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/dosfstools-4.2
    ./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --enable-compat-symlinks --mandir=/usr/share/man
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Userspace-RCU
```sh
tar xvf ${DOWNLOADDIR}/userspace-rcu-0.14.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/userspace-rcu-0.14
    patch -Np1 -i ${DOWNLOADDIR}/userspace-rcu-0.13.1-add-loongarch64.patch
    autoreconf -ifv
    ./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} --host=${CROSS_TARGET}
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/liburcu*.la
popd
```

#### Xfsprogs
```sh
tar xvf ${DOWNLOADDIR}/xfsprogs-6.2.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/xfsprogs-6.2.0
    CC=${CROSS_TARGET}-gcc ./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --mandir=/usr/share/man
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Libaio
```sh
tar xvf ${DOWNLOADDIR}/libaio_0.3.113.orig.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libaio-0.3.113
    make CC="${CROSS_TARGET}-gcc" ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot libdir=/usr/lib64 install
popd
```

#### Mdadm
```sh
tar xvf ${DOWNLOADDIR}/mdadm-4.2.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/mdadm-4.2
    make CC="${CROSS_TARGET}-gcc" ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot PKG_CONFIG=${CROSS_TARGET}-pkg-config install
popd
```

#### LVM2
```sh
tar xvf ${DOWNLOADDIR}/LVM2.2.03.20.tgz -C ${BUILDDIR}
pushd ${BUILDDIR}/LVM2.2.03.20
    ./configure --prefix=/usr --libdir=/usr/lib64 --with-usrlibdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --enable-cmdlib --enable-pkgconfig --enable-udev_sync \
                ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### PCRE
```sh
tar xvf ${DOWNLOADDIR}/pcre-8.45.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/pcre-8.45
    rm config.{sub,guess}
    automake -a
    ./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
                --host=${CROSS_TARGET} --enable-unicode-properties \
                --enable-pcre16 --enable-pcre32 \
                --enable-pcregrep-libz --enable-pcregrep-libbz2 \
                --enable-pcretest-libreadline
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### PCRE2
```sh
tar xvf ${DOWNLOADDIR}/pcre2-10.42.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/pcre2-10.42
    ./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
                --host=${CROSS_TARGET} --enable-unicode --disable-jit \
                --enable-pcre2-16 --enable-pcre2-32 --enable-pcre2grep-libz \
                --enable-pcre2grep-libbz2 --enable-pcre2test-libreadline
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Glib
```sh
tar xvf ${DOWNLOADDIR}/glib-2.76.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/glib-2.76.1
    mkdir build
    pushd build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release  -Dtests=false \
              -Dman=true -Dselinux=disabled \
              --cross-file=${BUILDDIR}/meson-cross.txt \
              ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
echo '#!/bin/bash -e
qemu-loongarch64 ${SYSDIR}/sysroot/usr/bin/glib-compile-resources "$@"' > ${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-glib-compile-resources
chmod +x ${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-glib-compile-resources
cp -a ${SYSDIR}/cross-tools/bin/{${CROSS_TARGET}-,}glib-compile-resources
echo '#!/bin/bash -e
qemu-loongarch64 ${SYSDIR}/sysroot/usr/bin/glib-compile-schemas "$@"' > ${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-glib-compile-schemas
chmod +x ${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-glib-compile-schemas
cp -a ${SYSDIR}/cross-tools/bin/{${CROSS_TARGET}-,}glib-compile-schemas
```

#### UnRAR
```sh
tar xvf ${DOWNLOADDIR}/unrarsrc-6.2.6.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/unrar
    make CXX="${CROSS_TARGET}-g++" STRIP=${CROSS_TARGET}-strip -f makefile ${JOBS}
    install -v -m755 unrar ${SYSDIR}/sysroot/usr/bin
popd
```

#### Zip
```sh
tar xvf ${DOWNLOADDIR}/zip30.tgz -C ${BUILDDIR}
pushd ${BUILDDIR}/zip30
    make -f unix/Makefile CC="${CROSS_TARGET}-gcc -DLARGE_FILE_SUPPORT" generic ${JOBS}
    make prefix=${SYSDIR}/sysroot/usr MANDIR=${SYSDIR}/sysroot/usr/share/man/man1 \
         -f unix/Makefile install
popd
```

#### UnZip
```sh
tar xvf ${DOWNLOADDIR}/unzip60.tgz -C ${BUILDDIR}
pushd ${BUILDDIR}/unzip60
    sed -i "s@-DNO_LCHMOD@@g" unix/configure
    make -f unix/Makefile CC="${CROSS_TARGET}-gcc \
            -DLARGE_FILE_SUPPORT -DUNICODE_WCHAR -DUNICODE_SUPPORT" generic ${JOBS}
    make prefix=${SYSDIR}/sysroot/usr MANDIR=${SYSDIR}/sysroot/usr/share/man/man1 \
         -f unix/Makefile install
popd
```

#### CPIO
```sh
tar xvf ${DOWNLOADDIR}/cpio-2.13.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/cpio-2.13
    sed -i '/The name/,+2 d' src/global.c
    ./configure --prefix=/usr --build=${CROSS_HOST} \
                --host=${CROSS_TARGET} --enable-mt \
                --with-rmt=/usr/libexec/rmt
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Libmnl
```sh
tar xvf ${DOWNLOADDIR}/libmnl-1.0.5.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/libmnl-1.0.5
    ./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
                --host=${CROSS_TARGET}
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Ethtool
```sh
tar xvf ${DOWNLOADDIR}/ethtool-6.2.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/ethtool-6.2
    ./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Boost
```sh
tar xvf ${DOWNLOADDIR}/boost_1_81_0.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/boost_1_81_0
    ./bootstrap.sh ICU_ROOT=${SYSDIR}/sysroot/usr --prefix=/usr --libdir=/usr/lib64 --with-python=python3
    sed -i "/using gcc/s@using gcc@& : loongarch64 : ${CROSS_TARGET}-gcc@g" project-config.jam
    sed -i "s@mips @mips1 @g" libs/log/build/log-arch-config.jam
    ./b2 stage threading=multi link=shared address-model=64 toolset=gcc-loongarch64
    ./b2 install --prefix=${SYSDIR}/sysroot/usr --libdir=${SYSDIR}/sysroot/usr/lib64 \
             threading=multi link=shared address-model=64 toolset=gcc-loongarch64
popd
```

#### Libsigc++3
```sh
tar xvf ${DOWNLOADDIR}/libsigc++-3.4.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libsigc++-3.4.0
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
tar xvf ${DOWNLOADDIR}/glibmm-2.76.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/glibmm-2.76.0
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
tar xvf ${DOWNLOADDIR}/libpng-1.6.39.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libpng-1.6.39
    gzip -cd ${DOWNLOADDIR}/libpng-1.6.37-apng.patch.gz | patch -p1
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET}
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libpng16.la
popd
```

#### LibJPEG-Turbo
```sh
tar xvf ${DOWNLOADDIR}/libjpeg-turbo-2.1.91.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libjpeg-turbo-2.1.91
    mkdir build
    pushd build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -DCMAKE_INSTALL_PREFIX=/usr \
              -DCMAKE_BUILD_TYPE=RELEASE -DWITH_JPEG8=ON \
              -DCMAKE_INSTALL_DEFAULT_LIBDIR=lib64 ..
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
popd
```

#### TIFF
```sh
tar xvf ${DOWNLOADDIR}/tiff-4.5.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/tiff-4.5.0
    mkdir cross-build
    pushd cross-build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -DCMAKE_INSTALL_PREFIX=/usr \
              -DCMAKE_BUILD_TYPE=RELEASE \
              -DCMAKE_INSTALL_LIBDIR=lib64 ..
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
        sed -i /Version/s/\$/$(cat ../VERSION)/ \
               ${SYSDIR}/sysroot/usr/lib64/pkgconfig/libtiff-4.pc
    popd
popd
```

#### LCMS2
```sh
tar xvf ${DOWNLOADDIR}/lcms2-2.15.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/lcms2-2.15
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET}
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### OpenJPEG
```sh
tar xvf ${DOWNLOADDIR}/openjpeg-2.5.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/openjpeg-2.5.0
    mkdir cross-build
    pushd cross-build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -DCMAKE_INSTALL_PREFIX=/usr \
              -DCMAKE_BUILD_TYPE=RELEASE \
              -DOPENJPEG_INSTALL_LIB_DIR=lib64 ..
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
popd
```

#### Jasper
```sh
tar xvf ${DOWNLOADDIR}/jasper-4.0.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/jasper-4.0.0
    mkdir cross-build
    pushd cross-build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -DCMAKE_INSTALL_PREFIX=/usr \
              -DCMAKE_BUILD_TYPE=Release \
              -DCMAKE_SKIP_INSTALL_RPATH=YES \
              -DJAS_CROSSCOMPILING=True -DJAS_STDC_VERSION=201710L \
              -DJAS_ENABLE_DOC=NO ..
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
popd
```

#### LibRaw
```sh
tar xvf ${DOWNLOADDIR}/LibRaw-0.21.1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/LibRaw-0.21.1
    autoreconf -ifv
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --enable-jpeg --enable-jasper --enable-lcms
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Libmng
```sh
tar xvf ${DOWNLOADDIR}/libmng-2.0.3.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libmng-2.0.3
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET}
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### FreeType
```sh
tar xvf ${DOWNLOADDIR}/freetype-2.13.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/freetype-2.13.0
    sed -ri "s:.*(AUX_MODULES.*valid):\1:" modules.cfg
    sed -r "s:.*(#.*SUBPIXEL_RENDERING) .*:\1:" \
           -i include/freetype/config/ftoption.h
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --enable-freetype-config
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
sed -i -e "s@/opt/mylaos/cross-tools/bin@/usr/bin@g" \
       -e "s@loongarch64-unknown-linux-gnu-@@g" \
       /opt/mylaos/sysroot/usr/bin/freetype-config
```

#### Gobject-Introspection
```sh
tar xvf ${DOWNLOADDIR}/gobject-introspection-1.76.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/gobject-introspection-1.76.1
    sed -i -e "/gircompiler_command/s@gircompiler,@'${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-g-ir-compiler',@g" \
           -e "/g-ir-scanner/s@'g-ir-scanner'@'${CROSS_TARGET}-g-ir-scanner'@g" \
           gir/meson.build
    mkdir cross-build
    pushd cross-build
        PATH=${SYSDIR}/cross-tools/tmp/bin:${PATH} \
        PYTHON=${SYSDIR}/cross-tools/bin/python3 \
        _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_${CROSS_TARGET} \
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release -Dgi_cross_use_prebuilt_gi=true \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        CC="${CROSS_TARGET}-gcc" ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### HarfBuzz
```sh
tar xvf ${DOWNLOADDIR}/harfbuzz-7.1.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/harfbuzz-7.1.0
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release -Dbenchmark=disabled -Dintrospection=enabled -Dgraphite2=disabled \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        sed -i -e "s@\(${SYSDIR}/\)sysroot/usr\(.*\)\(g-ir-compiler\|g-ir-scanner\)@\1cross-tools\2${CROSS_TARGET}-\3@g" build.ninja
        CC="${CROSS_TARGET}-gcc" ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Graphite
```sh
tar xvf ${DOWNLOADDIR}/graphite-1.3.14.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/graphite-1.3.14
    sed -i "/mfpmath/d" src/CMakeLists.txt
    mkdir cross-build
    pushd cross-build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -DCMAKE_INSTALL_PREFIX=/usr -DLIB_SUFFIX=64 \
              -DCMAKE_BUILD_TYPE=Release \
              ..
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
popd
```

#### HarfBuzz(第二次)
　　这次编译是加入对Graphite的支持。

```sh
tar xvf ${DOWNLOADDIR}/harfbuzz-7.1.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/harfbuzz-7.1.0
    mkdir cross-build-2
    pushd cross-build-2
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release -Dbenchmark=disabled -Dintrospection=enabled -Dgraphite2=enabled \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        sed -i -e "s@\(${SYSDIR}/\)sysroot/usr\(.*\)\(g-ir-compiler\|g-ir-scanner\)@\1cross-tools\2${CROSS_TARGET}-\3@g" build.ninja
        CC="${CROSS_TARGET}-gcc" ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### FreeType(第二次)
　　这次编译是加入对HarfBuzz的支持。

```sh
tar xvf ${DOWNLOADDIR}/freetype-2.13.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/freetype-2.13.0
    sed -ri "s:.*(AUX_MODULES.*valid):\1:" modules.cfg
    sed -r "s:.*(#.*SUBPIXEL_RENDERING) .*:\1:" \
           -i include/freetype/config/ftoption.h
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --enable-freetype-config
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libfreetype.la
popd
```

#### Fontconfig
```sh
tar xvf ${DOWNLOADDIR}/fontconfig-2.14.2.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/fontconfig-2.14.2
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --sysconfdir=/etc --localstatedir=/var --disable-docs
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libfontconfig.la
popd
```

#### Fribidi
```sh
tar xvf ${DOWNLOADDIR}/fribidi-1.0.12.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/fribidi-1.0.12
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
tar xvf ${DOWNLOADDIR}/nettle-3.8.1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/nettle-3.8.1
    cp ${SYSDIR}/sysroot/usr/share/automake-*/config.* ./
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET}
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Libunistring
```sh
tar xvf ${DOWNLOADDIR}/libunistring-1.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libunistring-1.1
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET}
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libunistring.la
popd
```

#### Gc
```sh
tar xvf ${DOWNLOADDIR}/gc-8.2.2.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/gc-8.2.2
    patch -Np1 -i ${DOWNLOADDIR}/gc-8.0.6-add-loongarch.patch
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --enable-cplusplus --with-libatomic-ops=none
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libgc*.la
popd
```

#### Guile
```sh
tar xvf ${DOWNLOADDIR}/guile-3.0.9.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/guile-3.0.9
    patch -Np1 -i ${DOWNLOADDIR}/guile-3.0.8-add-loongarch64.patch
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --with-libgmp-prefix=${SYSDIR}/sysroot/usr/lib64 \
                --with-libunistring-prefix=${SYSDIR}/sysroot/usr/lib64
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libguile*.la
popd
```

#### Autogen
```sh
tar xvf ${DOWNLOADDIR}/autogen-5.18.16.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/autogen-5.18.16
    sed -i "/_guile_versions_to_search/s@\"2.2@\"3.0 2.2@g" configure
    sed -i "s@203000@308000@g" agen5/guile-iface.h
    sed -i -e "/exe=\`cd/s@exe=.*\$2@exe=/usr/bin/\$2@g" build-aux/run-ag.sh
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} --host=${CROSS_TARGET} \
	            --without-libregex --disable-dependency-tracking \
	            --with-libxml2-libs=${SYSDIR}/sysroot/usr/lib64 \
	            ag_cv_run_strcspn=yes
	make CC="${CROSS_TARGET}-gcc -Wno-error=dangling-pointer" ${JOBS}
	make CC="${CROSS_TARGET}-gcc -Wno-error=dangling-pointer" DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Libtasn1
```sh
tar xvf ${DOWNLOADDIR}/libtasn1-4.19.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libtasn1-4.19.0
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET}
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libtasn1.la
popd
```

#### P11-Kit
```sh
tar xvf ${DOWNLOADDIR}/p11-kit-0.24.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/p11-kit-0.24.1
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

#### Brotli
https://github.com/google/brotli/archive/v1.0.9/brotli-1.0.9.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/brotli-1.0.9.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/brotli-1.0.9
    ./bootstrap
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET}
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot//usr/lib64/libbrotli*.la
popd
```



#### GnuTLS
```sh
tar xvf ${DOWNLOADDIR}/gnutls-3.7.4.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/gnutls-3.7.4
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --enable-openssl-compatibility --enable-ssl3-support \
                --with-default-trust-store-pkcs11="pkcs11:" \
                --with-libz-prefix=${SYSDIR}/sysroot/usr \
                --disable-guile --disable-doc
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
rm -v ${SYSDIR}/sysroot/usr/lib64/libgnutls*.la
```

#### Vala
```sh
tar xvf ${DOWNLOADDIR}/vala-0.56.5.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/vala-0.56.5
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --disable-valadoc
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### LibUSB
```sh
tar xvf ${DOWNLOADDIR}/libusb-1.0.26.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/libusb-1.0.26
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --build=${CROSS_HOST} --host=${CROSS_TARGET}
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### USBUtils
```sh
tar xvf ${DOWNLOADDIR}/usbutils-015.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/usbutils-015
   ./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --datadir=/usr/share/hwdata
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    mkdir -v ${SYSDIR}/sysroot/usr/share/hwdata/
    wget http://www.linux-usb.org/usb.ids -O ${SYSDIR}/sysroot/usr/share/hwdata/usb.ids
popd
```

#### LibGUSB
```sh
tar xvf ${DOWNLOADDIR}/libgusb-0.4.5.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libgusb-0.4.5
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release -Ddocs=false \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        sed -i -e "s@\(${SYSDIR}/\)sysroot/usr\(.*\)\(g-ir-compiler\|g-ir-scanner\)@\1cross-tools\2${CROSS_TARGET}-\3@g" build.ninja
        CC="${CROSS_TARGET}-gcc" ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### LibGUdev
```sh
tar xvf ${DOWNLOADDIR}/libgudev-237.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libgudev-237
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 --buildtype=release  \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        sed -i -e "s@\(${SYSDIR}/\)sysroot/usr\(.*\)\(g-ir-compiler\|g-ir-scanner\)@\1cross-tools\2${CROSS_TARGET}-\3@g" build.ninja
        CC="${CROSS_TARGET}-gcc" ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### 编译环境设置
　　此步骤不是必须的，但可以简化后续的制作步骤。

```sh
export COMMON_CONFIG="--prefix=/usr --sysconfdir=/etc --localstatedir=/var --libdir=/usr/lib64 \
                      --build=${CROSS_HOST} --host=${CROSS_TARGET}"
export JOBS="-j8"
```
　　这里设置了2个环境变量：

　　“COMMON_CONFIG":用来为配置软件包提供通用参数。  
　　“JOBS”：用来给make命令提供并行编译的数量设置。

#### Util-Macros
https://www.x.org/archive/individual/util/util-macros-1.20.0.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/util-macros-1.20.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/util-macros-1.20.0
    ./configure $COMMON_CONFIG
    make DESTDIR=${SYSDIR}/sysroot install
popd
cp -v /opt/mylaos/sysroot/usr/share/aclocal/xorg-macros.m4 ${SYSDIR}/cross-tools/share/aclocal/
```

#### XorgProto
https://xorg.freedesktop.org/archive/individual/proto/xorgproto-2022.2.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/xorgproto-2022.2.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/xorgproto-2022.2
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr -Dlegacy=true \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### LibXau
https://www.x.org/archive/individual/lib/libXau-1.0.11.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libXau-1.0.11.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libXau-1.0.11
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libXau.la
popd
```

#### LibXdmcp
https://www.x.org/archive/individual/lib/libXdmcp-1.1.4.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libXdmcp-1.1.4.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libXdmcp-1.1.4
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libXdmcp.la
popd
```

#### XCB-Proto
https://xorg.freedesktop.org/archive/individual/proto/xcb-proto-1.15.2.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/xcb-proto-1.15.2.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/xcb-proto-1.15.2
    PYTHON=python3 ./configure $COMMON_CONFIG
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Libxcb
https://xorg.freedesktop.org/archive/individual/lib/libxcb-1.15.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libxcb-1.15.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libxcb-1.15
    rm build-aux/config.{sub,guess}
    automake -a
    PYTHON=python3 ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libxcb*.la
popd
```

#### Xorg-Libs
Xorg-libs-packages.txt

下载软件包：

```sh
cat ${DOWNLOADDIR}/Xorg-libs-packages.txt | \
    wget -i- -c -B https://www.x.org/pub/individual/lib/ -P ${DOWNLOADDIR}/
```

制作脚本：

```sh
mkdir -pv ${BUILDDIR}/xorg-lib
for package in xtrans libX11 libXext libFS libICE libSM libXScrnSaver \
               libXt libXmu libXpm libXaw libXfixes \
               libXcomposite libXrender libXcursor libXdamage libfontenc \
               libXfont2 libXft libXi libXinerama libXrandr libXres \
               libXtst libXv libXvMC libXxf86dga libXxf86vm libdmx \
               libpciaccess libxkbfile libxshmfence
do
    tar xvf ${DOWNLOADDIR}/$(grep -E "$package-[0-9]" ${DOWNLOADDIR}/Xorg-libs-packages.txt) \
            -C ${BUILDDIR}/xorg-lib/
    pushd ${BUILDDIR}/xorg-lib/$(grep -E "$package-[0-9]" ${DOWNLOADDIR}/Xorg-libs-packages.txt | \
                                  awk -F'.tar' '{ print $1 }')
        for i in $(dirname $(find -name "config.sub"))
        do
            pushd $(dirname ./$i)
                rm -f config.{sub,guess}
                cp ${SYSDIR}/sysroot/usr/share/automake-*/config.* ./
            popd
        done
        case $package in
        libX11)
            ./configure $COMMON_CONFIG --with-keysymdefdir=${SYSDIR}/sysroot/usr/include/X11 --enable-malloc0returnsnull
            ;;
         libXpm)
            ./configure $COMMON_CONFIG  ac_cv_path_XPM_PATH_COMPRESS=no ac_cv_path_XPM_PATH_UNCOMPRESS=no --enable-malloc0returnsnull
            ;;
        * )
            ./configure $COMMON_CONFIG --enable-malloc0returnsnull
            ;;
        esac
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
        if [ -f ${SYSDIR}/sysroot/usr/lib64/$package.la ]; then
            rm -v ${SYSDIR}/sysroot/usr/lib64/$package*.la
        fi
    popd
done
```


#### Xorg-Xcb
Xorg-xcb-packages.txt

下载软件包：

```sh
cat ${DOWNLOADDIR}/Xorg-xcb-packages.txt | \
    wget -i- -c -B https://xcb.freedesktop.org/dist/ -P ${DOWNLOADDIR}/
```

制作脚本：

```sh
mkdir -pv ${BUILDDIR}/xcb-package
for package in xcb-util xcb-util-image xcb-util-keysyms \
               xcb-util-renderutil xcb-util-wm xcb-util-cursor
do
    tar xvf ${DOWNLOADDIR}/$(grep -E "$package-[0-9]" ${DOWNLOADDIR}/Xorg-xcb-packages.txt) \
            -C ${BUILDDIR}/xcb-package/
    pushd ${BUILDDIR}/xcb-package/$(grep -E "$package-[0-9]" ${DOWNLOADDIR}/Xorg-xcb-packages.txt | \
                                  awk -F'.tar' '{ print $1 }')
        for i in $(dirname $(find -name "config.sub"))
        do
            pushd $(dirname ./$i)
                rm -f config.{sub,guess}
                cp ${SYSDIR}/sysroot/usr/share/automake-*/config.* ./
            popd
        done
        ./configure $COMMON_CONFIG
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
        rm -v ${SYSDIR}/sysroot/usr/lib64/libxcb-*.la
    popd
done
```


#### Libxcb 第二次
https://xorg.freedesktop.org/archive/individual/lib/libxcb-1.15.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libxcb-1.15.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libxcb-1.15
    rm build-aux/config.{sub,guess}
    automake -a
    PYTHON=python3 ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm ${SYSDIR}/sysroot/usr/lib64/libxcb*.la
popd
```


https://dri.freedesktop.org/libdrm/libdrm-2.4.115.tar.xz
#### LibDRM
```sh
tar xvf ${DOWNLOADDIR}/libdrm-2.4.115.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libdrm-2.4.115
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              -Detnaviv=enabled -Dudev=true \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Wayland
https://wayland.freedesktop.org/releases/wayland-1.21.0.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/wayland-1.21.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/wayland-1.21.0
    sed -i "/wayland_scanner_for_build =/s@find\(.*\)\$@wayland_scanner@g" src/meson.build
    sed -i -e "/scanner_dep =/s@, native: true@@g" src/meson.build
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 --buildtype=release \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```


#### Wayland-Protocols
https://wayland.freedesktop.org/releases/wayland-protocols-1.31.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/wayland-protocols-1.31.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/wayland-protocols-1.31
    sed -i -e "/dep_scanner =/s@, native: true@@g" \
           -e "/prog_scanner =/s@find_program\(.*\)\$@find_program('wayland-scanner')@g" \
           tests/meson.build
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


#### LLVM

```sh
tar xvf ${DOWNLOADDIR}/llvm-project-16.0.0.src.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/llvm-project-16.0.0.src/llvm
    mkdir cross-build
    pushd cross-build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake .. -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release \
              -DBUILD_SHARED_LIBS:BOOL=OFF -DLLVM_ENABLE_LIBCXX:BOOL=OFF \
              -DLLVM_LIBDIR_SUFFIX=64 \
              -DCMAKE_C_FLAGS="-DNDEBUG" -DCMAKE_CXX_FLAGS="-DNDEBUG" \
              -DLLVM_BUILD_RUNTIME:BOOL=ON -DLLVM_ENABLE_RTTI:BOOL=ON \
              -DLLVM_ENABLE_ZLIB:BOOL=ON -DLLVM_ENABLE_FFI:BOOL=ON \
              -DLLVM_ENABLE_TERMINFO:BOOL=OFF \
              -DLLVM_TABLEGEN:PATH=${SYSDIR}/cross-tools/bin/llvm-tblgen \
              -DLLVM_BUILD_LLVM_DYLIB:BOOL=ON \
              -DLLVM_LINK_LLVM_DYLIB:BOOL=ON -DLLVM_BUILD_EXTERNAL_COMPILER_RT:BOOL=ON \
              -DLLVM_INSTALL_TOOLCHAIN_ONLY:BOOL=OFF \
              -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD="LoongArch" \
              -DLLVM_TARGET_ARCH=LoongArch -DLLVM_DEFAULT_TARGET_TRIPLE=${CROSS_TARGET} 
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Clang

```sh
tar xvf ${DOWNLOADDIR}/llvm-project-16.0.0.src.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/llvm-project-16.0.0.src/clang
    mkdir cross-build
    pushd cross-build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake .. -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release \
              -DLLVM_CONFIG=${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-llvm-config \
              -DBUILD_SHARED_LIBS:BOOL=OFF -DLLVM_ENABLE_LIBCXX:BOOL=OFF \
              -DLLVM_LIBDIR_SUFFIX=64 \
              -DCMAKE_C_FLAGS="-DNDEBUG" -DCMAKE_CXX_FLAGS="-DNDEBUG" \
              -DLLVM_ENABLE_RTTI:BOOL=ON \
              -DLLVM_ENABLE_ZLIB:BOOL=ON \
              -DCLANG_TABLEGEN:PATH=${SYSDIR}/cross-tools/bin/clang-tblgen \
              -DLLVM_TABLEGEN_EXE:FILEPATH=${SYSDIR}/cross-tools/bin/llvm-tblgen \
              -DLLVM_ENABLE_TERMINFO:BOOL=OFF \
              -DLLVM_LINK_LLVM_DYLIB:BOOL=ON -DLLVM_BUILD_EXTERNAL_COMPILER_RT:BOOL=ON \
              -DLLVM_INSTALL_TOOLCHAIN_ONLY:BOOL=OFF \
              -DLLVM_HOST_TRIPLE=${CROSS_TARGET}
        sed -i "s@${PWD}/bin/clang-ast-dump@qemu-loongarch64 ${PWD}/bin/clang-ast-dump@g" build.ninja
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```


#### Rust
https://static.rust-lang.org/dist/rustc-1.68.1-src.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/rustc-1.68.1-src.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/rustc-1.68.1-src
    rm -rf src/llvm-project
    tar xvf ${DOWNLOADDIR}/llvm-project-16.0.0.src.tar.xz -C src/
    mv src/llvm-project-16.0.0.src src/llvm-project
    patch -Np1 -i ${DOWNLOADDIR}/rustc-1.65.0-add-loongarch-support.patch
    patch -Np1 -i ${DOWNLOADDIR}/0001-Rustc-1.67.1-vendor-linux-raw-sys-add-loongarch64.patch
    sed -i "s@ifdef LLVM_RUSTLLVM@if 0@g" compiler/rustc_llvm/llvm-wrapper/PassWrapper.cpp
    find vendor -name .cargo-checksum.json \
          -exec sed -i.uncheck -e 's/"files":{[^}]*}/"files":{ }/' '{}' '+'
    LDFLAGS="" \
    PKG_CONFIG_SYSROOT_DIR="" \
    ./configure --host=${CROSS_TARGET} --target=${CROSS_TARGET} \
                --prefix=/usr --libdir=/usr/lib64 --sysconfdir=/etc \
                --local-rust-root=${SYSDIR}/cross-tools \
                --enable-extended --enable-vendor --release-channel=stable \
                --disable-codegen-tests --experimental-targets=""
    LDFLAGS="" \
    PKG_CONFIG_SYSROOT_DIR="" \
    RUSTFLAGS="$RUSTFLAGS -C link-args=-lz" \
    make HOST_CC="gcc" CC="${CROSS_TARGET}-gcc" \
         HOST_CXX="g++" CXX="${CROSS_TARGET}-g++" \
         LOONGARCH64_UNKNOWN_LINUX_GNU_OPENSSL_INCLUDE_DIR=${SYSDIR}/sysroot/usr/include \
         LOONGARCH64_UNKNOWN_LINUX_GNU_OPENSSL_LIB_DIR=${SYSDIR}/sysroot/usr/lib64 \
         ${JOBS}
    LDFLAGS="" \
    PKG_CONFIG_SYSROOT_DIR="" \
    RUSTFLAGS="$RUSTFLAGS -C link-args=-lz" \
    make HOST_CC="gcc" CC="${CROSS_TARGET}-gcc" \
         HOST_CXX="g++" CXX="${CROSS_TARGET}-g++" \
         LOONGARCH64_UNKNOWN_LINUX_GNU_OPENSSL_INCLUDE_DIR=${SYSDIR}/sysroot/usr/include \
         LOONGARCH64_UNKNOWN_LINUX_GNU_OPENSSL_LIB_DIR=${SYSDIR}/sysroot/usr/lib64 \
         DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Libvdpau
https://gitlab.freedesktop.org/vdpau/libvdpau/-/archive/1.5/libvdpau-1.5.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/libvdpau-1.5.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/libvdpau-1.5
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 --buildtype=release \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Libva
https://github.com/intel/libva/releases/download/2.17.0/libva-2.17.0.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/libva-2.17.0.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/libva-2.17.0
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libva*.la
popd
```

#### Libglvnd
https://gitlab.freedesktop.org/glvnd/libglvnd/-/archive/v1.6.0/libglvnd-v1.6.0.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/libglvnd-v1.6.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libglvnd-v1.6.0
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 --buildtype=release \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Mako
https://files.pythonhosted.org/packages/source/M/Mako/Mako-1.2.4.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/Mako-1.2.4.tar.gz
pushd ${BUILDDIR}/Mako-1.2.4
    ${SYSDIR}/cross-tools/bin/python3 setup.py build
    python3 setup.py install --optimize=1
    ${SYSDIR}/cross-tools/bin/python3 setup.py install \
             --optimize=1 --root=${SYSDIR}/sysroot --prefix=/usr
popd
```

#### Mesa
https://archive.mesa3d.org/mesa-23.0.1.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/mesa-23.0.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/mesa-23.0.1
    sed -i -e "/dep_wl_scanner/s@, native: true@@g" \
           -e "/prog_wl_scanner/s@find_program\(.*\)\$@'wayland-scanner'@g" meson.build
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 --buildtype=release \
              -Dgallium-drivers="nouveau,r600,radeonsi,etnaviv,swrast,virgl" \
              -Dglx=dri -Dopengl=true -Degl=enabled -Dglvnd=true \
              -Dshared-glapi=enabled -Dgles2=enabled -Dgallium-vdpau=enabled \
              -Dlibunwind=disabled -Dvulkan-drivers="amd,swrast, virtio-experimental" \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Glew
https://downloads.sourceforge.net/glew/glew-2.2.0.tgz

```sh
tar xvf ${DOWNLOADDIR}/glew-2.2.0.tgz -C ${BUILDDIR}
pushd ${BUILDDIR}/glew-2.2.0
    sed -i "s@ -s @ @g" Makefile
    make CC="${CROSS_TARGET}-gcc" LD="${CROSS_TARGET}-gcc" \
         STRIP="${CROSS_TARGET}-strip" \
         CFLAGS.EXTRA="-Wl,-rpath-link=/opt/mylaos/sysroot/usr/lib64"
    make PKGDIR=/usr/lib64/pkgconfig DESTDIR=${SYSDIR}/sysroot install
popd
```

#### GLU
ftp://ftp.freedesktop.org/pub/mesa/glu/glu-9.0.2.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/glu-9.0.2.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/glu-9.0.2
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 --buildtype=release \
              -Dgl_provider=gl \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Mesa-Demos
ftp://ftp.freedesktop.org/pub/mesa/demos/mesa-demos-9.0.0.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/mesa-demos-9.0.0.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/mesa-demos-9.0.0
    sed -i -e "/dep_wl_scanner =/s@, native: true@@g" \
           -e "/prog_wl_scanner =/s@find_program\(.*\)\$@find_program('wayland-scanner')@g" \
           meson.build
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

#### Xbitmap
https://www.x.org/archive/individual/data/xbitmaps-1.1.3.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/xbitmaps-1.1.3.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/xbitmaps-1.1.3
    ./configure $COMMON_CONFIG
    make DESTDIR=${SYSDIR}/sysroot install
popd
```


#### Xorg-Apps
Xorg-apps-packages.txt

下载软件包：

```sh
cat ${DOWNLOADDIR}/Xorg-apps-packages.txt | \
    wget -i- -c -B https://www.x.org/archive//individual/app/ -P ${DOWNLOADDIR}/
```

制作脚本：

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
                                  awk -F'.tar' '{ print $1 }')
        for i in $(dirname $(find -name "config.sub"))
        do
            pushd $(dirname ./$i)
                rm -f config.{sub,guess}
                cp ${SYSDIR}/sysroot/usr/share/automake-*/config.* ./
            popd
        done
        case $package in
           luit )
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
https://www.x.org/archive/individual/data/xcursor-themes-1.0.7.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/xcursor-themes-1.0.7.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/xcursor-themes-1.0.7
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```


#### Xorg-Fonts
Xorg-fonts-packages.txt

下载软件包：

```sh
cat ${DOWNLOADDIR}/Xorg-fonts-packages.txt | \
    wget -i- -c -B https://www.x.org/pub/individual/font/ -P ${DOWNLOADDIR}/
```

制作脚本：

```sh
mkdir -pv ${BUILDDIR}/xorg-fonts-package
for package in font-util encodings font-alias font-adobe-utopia-type1 \
               font-bh-ttf font-bh-type1 font-ibm-type1 font-misc-ethiopic \
               font-xfree86-type1
do
    tar xvf ${DOWNLOADDIR}/$(grep -E "$package-[0-9]" ${DOWNLOADDIR}/Xorg-fonts-packages.txt) \
            -C ${BUILDDIR}/xorg-fonts-package/
    pushd ${BUILDDIR}/xorg-fonts-package/$(grep -E "$package-[0-9]" ${DOWNLOADDIR}/Xorg-fonts-packages.txt | \
                                  awk -F'.tar' '{ print $1 }')
        for i in $(dirname $(find -name "config.sub"))
        do
            pushd $(dirname ./$i)
                rm -f config.{sub,guess}
                cp ${SYSDIR}/sysroot/usr/share/automake-*/config.* ./
            popd
        done
        ./configure $COMMON_CONFIG
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
done
```

#### 文泉驿正黑
http://downloads.sourceforge.net/wqy/wqy-zenhei-0.9.45.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/wqy-zenhei-0.9.45.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/wqy-zenhei
    mkdir -pv ${SYSDIR}/sysroot/usr/share/fonts/wenquanyi/
    cp -av wqy-zenhei.ttc ${SYSDIR}/sysroot/usr/share/fonts/wenquanyi/
    sed -i "7,11d" 44-wqy-zenhei.conf
    cp -av 44-wqy-zenhei.conf ${SYSDIR}/sysroot/etc/fonts/conf.d/
popd
```

#### Xkeyboard-Config
https://www.x.org/archive/individual/data/xkeyboard-config/xkeyboard-config-2.38.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/xkeyboard-config-2.38.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/xkeyboard-config-2.38
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


#### Pixman
https://www.cairographics.org/releases/pixman-0.42.2.tar.gz
```sh
tar xvf ${DOWNLOADDIR}/pixman-0.42.2.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/pixman-0.42.2
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
https://github.com/anholt/libepoxy/archive/1.5.10/libepoxy-1.5.10.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/libepoxy-1.5.10.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libepoxy-1.5.10
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

#### Libxcvt
https://www.x.org/pub/individual/lib/libxcvt-0.1.2.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libxcvt-0.1.2.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libxcvt-0.1.2
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

#### Libtirpc
https://downloads.sourceforge.net/libtirpc/libtirpc-1.3.3.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/libtirpc-1.3.3.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/libtirpc-1.3.3
    cp ${SYSDIR}/sysroot/usr/share/automake-*/config.* ./
    ./configure $COMMON_CONFIG --disable-gssapi
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libtirpc.la
popd
```


#### Xwayland
https://www.x.org/archive/individual/xserver/xwayland-23.1.0.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/xwayland-23.1.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/xwayland-23.1.0
    sed -i -e "/scanner_dep/s@, native: true@@g" \
           -e "/scanner =/s@find_program\(.*\)\$@find_program('wayland-scanner')@g" \
           hw/xwayland/meson.build 
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              -Dxvfb=false -Dxkb_output_dir=/var/lib/xkb \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
mkdir -pv ${SYSDIR}/sysroot/etc/X11/xorg.conf.d
```

#### Xorg-Server
https://www.x.org/archive/individual/xserver/xorg-server-21.1.7.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/xorg-server-21.1.7.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/xorg-server-21.1.7
    patch -Np1 -i ${DOWNLOADDIR}/xorg-server-21.1.3-fix-x11perf-segment-fault.patch
    ./configure $COMMON_CONFIG --enable-glamor \
            --enable-suid-wrapper --disable-selective-werror \
            --with-xkb-output=/var/lib/xkb \
            --with-xkb-bin-directory=/usr/bin --with-xkb-path=/usr/share/X11/xkb 
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
cp -v /opt/mylaos/sysroot/usr/share/aclocal/xorg-server.m4 ${SYSDIR}/cross-tools/share/aclocal/
cat >> ${SYSDIR}/sysroot/etc/sysconfig/createfiles << "EOF"
/tmp/.ICE-unix dir 1777 root root
/tmp/.X11-unix dir 1777 root root
EOF
```


#### MTDev
https://bitmath.org/code/mtdev/mtdev-1.1.6.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/mtdev-1.1.6.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/mtdev-1.1.6
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```


#### Libevdev
https://www.freedesktop.org/software/libevdev/libevdev-1.13.0.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libevdev-1.13.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libevdev-1.13.0
    PYTHON=python3 ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```


#### Libwacom
https://github.com/linuxwacom/libwacom/releases/download/libwacom-2.6.0/libwacom-2.6.0.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libwacom-2.6.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libwacom-2.6.0
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
https://github.com/linuxwacom/xf86-input-wacom/releases/download/xf86-input-wacom-1.1.0/xf86-input-wacom-1.1.0.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/xf86-input-wacom-1.1.0.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/xf86-input-wacom-1.1.0
    cp ${SYSDIR}/sysroot/usr/share/automake-*/config.* ./
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Libinput
https://gitlab.freedesktop.org/libinput/libinput/-/archive/1.23.0/libinput-1.23.0.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/libinput-1.23.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libinput-1.23.0
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

内核配置中请将以下选项选上：

```sh
Device Drivers --->
  Input device support --->
    Miscellaneous Devices --->
    <*/M>   User level driver support        [CONFIG_INPUT_UINPUT]
```

#### Xorg-Dirvers
Xorg-drivers-packages.txt
https://www.linuxfromscratch.org/patches/blfs/svn/xf86-video-ati-19.1.0-upstream_fixes-1.patch

下载软件包：

```sh
cat ${DOWNLOADDIR}/Xorg-drivers-packages.txt | \
    wget -i- -c -B https://www.x.org/pub/individual/driver/ -P ${DOWNLOADDIR}/
```

制作脚本：

```sh
mkdir -pv ${BUILDDIR}/xorg-drivers-package
for package in xf86-input-evdev xf86-input-libinput xf86-input-synaptics \
               xf86-video-amdgpu xf86-video-ati xf86-video-fbdev
do
    tar xvf ${DOWNLOADDIR}/$(grep -E "$package-[0-9]" ${DOWNLOADDIR}/Xorg-drivers-packages.txt) \
            -C ${BUILDDIR}/xorg-drivers-package/
    pushd ${BUILDDIR}/xorg-drivers-package/$(grep -E "$package-[0-9]" ${DOWNLOADDIR}/Xorg-drivers-packages.txt | \
                                  awk -F'.tar' '{ print $1 }')
        for i in $(dirname $(find -name "config.sub"))
        do
            pushd $(dirname ./$i)
                rm -f config.{sub,guess}
                cp ${SYSDIR}/sysroot/usr/share/automake-*/config.* ./
            popd
        done
        case $package in
           xf86-video-ati )
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
https://www.x.org/archive/individual/app/twm-1.0.12.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/twm-1.0.12.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/twm-1.0.12
    sed -i -e '/^rcdir =/s,^\(rcdir = \).*,\1/etc/X11/app-defaults,' src/Makefile.in
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```


#### Dejavu-Fonts
https://sourceforge.net/projects/dejavu/files/dejavu/2.37/dejavu-fonts-ttf-2.37.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/dejavu-fonts-ttf-2.37.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/dejavu-fonts-ttf-2.37
    cp fontconfig/*.conf ${SYSDIR}/sysroot/usr/share/fontconfig/conf.avail/
    install -dv ${SYSDIR}/sysroot/usr/share/fonts/DejaVu/
    cp -v ttf/* ${SYSDIR}/sysroot/usr/share/fonts/DejaVu/
popd
```


#### XTerm
https://invisible-mirror.net/archives/xterm/xterm-379.tgz

```sh
tar xvf ${DOWNLOADDIR}/xterm-379.tgz -C ${BUILDDIR}
pushd ${BUILDDIR}/xterm-379
    sed -i '/v0/{n;s/new:/new:kb=^?:/}' termcap
    printf '\tkbs=\\177,\n' >> terminfo
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
https://www.x.org/archive/individual/app/xinit-1.4.2.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/xinit-1.4.2.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/xinit-1.4.2
    ./configure $COMMON_CONFIG --with-xinitdir=/etc/X11/app-defaults
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Shared-Mime-Info
https://gitlab.freedesktop.org/xdg/shared-mime-info/-/archive/2.2/shared-mime-info-2.2.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/shared-mime-info-2.2.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/shared-mime-info-2.2
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd

echo "qemu-loongarch64 /opt/mylaos/sysroot/usr/bin/update-mime-database \"\$@\"" \
                > ${SYSDIR}/cross-tools/bin/update-mime-database
chmod +x ${SYSDIR}/cross-tools/bin/update-mime-database
```

#### GDK-Pixbuf
https://download.gnome.org/sources/gdk-pixbuf/2.42/gdk-pixbuf-2.42.10.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/gdk-pixbuf-2.42.10.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/gdk-pixbuf-2.42.10
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release --wrap-mode=nofallback -Dintrospection=enabled \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        sed -i -e "s@\(${SYSDIR}/\)sysroot/usr\(.*\)\(g-ir-compiler\|g-ir-scanner\)@\1cross-tools\2${CROSS_TARGET}-\3@g" build.ninja
        CC="${CROSS_TARGET}-gcc" ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd

echo "qemu-loongarch64 /opt/mylaos/sysroot/usr/bin/gdk-pixbuf-csource \"\$@\"" \
                > ${SYSDIR}/cross-tools/bin/gdk-pixbuf-csource
chmod +x ${SYSDIR}/cross-tools/bin/gdk-pixbuf-csource
```

#### GDK-Pixbuf-Xlib
https://download.gnome.org/sources/gdk-pixbuf-xlib/2.40/gdk-pixbuf-xlib-2.40.2.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/gdk-pixbuf-xlib-2.40.2.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/gdk-pixbuf-xlib-2.40.2
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


#### Graphene
https://github.com/ebassi/graphene/archive/1.10.8/graphene-1.10.8.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/graphene-1.10.8.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/graphene-1.10.8
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release -Dintrospection=enabled \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        sed -i -e "s@\(${SYSDIR}/\)sysroot/usr\(.*\)\(g-ir-compiler\|g-ir-scanner\)@\1cross-tools\2${CROSS_TARGET}-\3@g" build.ninja
        CC="${CROSS_TARGET}-gcc" ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Cairo
https://download.gnome.org/sources/cairo/1.17/cairo-1.17.6.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/cairo-1.17.6.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/cairo-1.17.6
    cp ${SYSDIR}/sysroot/usr/share/automake-*/config.* build/
    ./configure $COMMON_CONFIG --enable-tee --enable-gl --enable-xlib-xcb --disable-trace
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libcairo*.la
popd
```

#### Pango
https://download.gnome.org/sources/pango/1.50/pango-1.50.14.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/pango-1.50.14.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/pango-1.50.14
    mkdir cross-prebuild
    pushd cross-prebuild
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release --wrap-mode=nofallback -Dintrospection=disabled \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        CC="${CROSS_TARGET}-gcc" ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release --wrap-mode=nofallback -Dintrospection=enabled \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        sed -i -e "s@\(${SYSDIR}/\)sysroot/usr\(.*\)\(g-ir-compiler\|g-ir-scanner\)@\1cross-tools\2${CROSS_TARGET}-\3@g" build.ninja
        CC="${CROSS_TARGET}-gcc" ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```


#### Dbus-Glib
https://dbus.freedesktop.org/releases/dbus-glib/dbus-glib-0.112.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/dbus-glib-0.112.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/dbus-glib-0.112
    ./configure $COMMON_CONFIG
    make DBUS_BINDING_TOOL=/bin/dbus-binding-tool ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Libxkbcommon
https://xkbcommon.org/download/libxkbcommon-1.5.0.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libxkbcommon-1.5.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libxkbcommon-1.5.0
    sed -i -e "/wayland_scanner_dep =/s@, native: true@@g" \
           -e "/wayland_scanner =/s@find_program\(.*\)\$@find_program('wayland-scanner')@g" \
           meson.build
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


#### Xdg-Utils
https://portland.freedesktop.org/download/xdg-utils-1.1.3.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/xdg-utils-1.1.3.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/xdg-utils-1.1.3
    ./configure $COMMON_CONFIG 
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```


#### xdg-user-dirs
https://user-dirs.freedesktop.org/releases/xdg-user-dirs-0.18.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/xdg-user-dirs-0.18.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/xdg-user-dirs-0.18
    ./configure $COMMON_CONFIG 
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Libpaper
https://ftp.debian.org/debian/pool/main/libp/libpaper/libpaper_1.1.29.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/libpaper_1.1.29.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libpaper-1.1.29
    autoreconf -ifv
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
mkdir -pv ${SYSDIR}/sysroot/etc/libpaper.d
cat > ${SYSDIR}/sysroot/etc/papersize << "EOF"
a4
EOF
```

#### CUPS
https://github.com/OpenPrinting/cups/releases/download/v2.4.2/cups-2.4.2-source.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/cups-2.4.2-source.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/cups-2.4.2
    sed -i 's#@CUPS_HTMLVIEW@#firefox#' desktop/cups.desktop.in
    ./configure $COMMON_CONFIG --with-rcdir=/tmp/cupsinit   \
            --with-system-groups=lpadmin
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -rf ${SYSDIR}/sysroot/tmp/cupsinit
    echo "ServerName /run/cups/cups.sock" > ${SYSDIR}/sysroot/etc/cups/client.conf
popd

cp -iv ${SYSDIR}/sysroot/bin/cups-config ${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-cups-config
sed -i "s@/opt/mylaos/sysroot@@g" /opt/mylaos/sysroot/usr/bin/cups-config
```

#### ISO-Codes
http://ftp.debian.org/debian/pool/main/i/iso-codes/iso-codes_4.13.0.orig.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/iso-codes_4.13.0.orig.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/iso-codes-4.13.0
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### ATK
https://download.gnome.org/sources/atk/2.38/atk-2.38.0.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/atk-2.38.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/atk-2.38.0
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        sed -i -e "s@\(${SYSDIR}/\)sysroot/usr\(.*\)\(g-ir-compiler\|g-ir-scanner\)@\1cross-tools\2${CROSS_TARGET}-\3@g" build.ninja
        CC=${CROSS_TARGET}-gcc ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### At-Spi2-Core
https://download.gnome.org/sources/at-spi2-core/2.48/at-spi2-core-2.48.0.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/at-spi2-core-2.48.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/at-spi2-core-2.48.0
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        sed -i -e "s@\(${SYSDIR}/\)sysroot/usr\(.*\)\(g-ir-compiler\|g-ir-scanner\)@\1cross-tools\2${CROSS_TARGET}-\3@g" build.ninja
        CC=${CROSS_TARGET}-gcc ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

####At-Spi2-Atk
https://download.gnome.org/sources/at-spi2-atk/2.38/at-spi2-atk-2.38.0.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/at-spi2-atk-2.38.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/at-spi2-atk-2.38.0
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

#### Adwaita-Icon-Theme
https://download.gnome.org/sources/adwaita-icon-theme/44/adwaita-icon-theme-44.0.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/adwaita-icon-theme-44.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/adwaita-icon-theme-44.0
    cp ${SYSDIR}/sysroot/usr/share/automake-*/config.* ./
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Libsass
https://github.com/sass/libsass/archive/3.6.5/libsass-3.6.5.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/libsass-3.6.5.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libsass-3.6.5
    autoreconf -ifv
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Sassc
https://github.com/sass/sassc/archive/3.6.2/sassc-3.6.2.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/sassc-3.6.2.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/sassc-3.6.2
    autoreconf -ifv
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### GTK+2
https://download.gnome.org/sources/gtk+/2.24/gtk+-2.24.33.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/gtk+-2.24.33.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/gtk+-2.24.33
    cp -v ${SYSDIR}/sysroot/usr/share/automake-*/config.* ./
    sed -i.orig -e "s@gtk-builder-convert@@g" \
        -e "/\tgtk-update-icon-cache\$(EXEEXT)/s@gtk-update-icon-cache\$(EXEEXT)@@g" \
        gtk/Makefile.in
    mkdir cross-prebuild
    pushd cross-prebuild
        ../configure $COMMON_CONFIG --disable-introspection \
                     ac_cv_func_httpGetAuthString=yes ac_cv_func_mmap_fixed_mapped=yes \
                     ac_cv_header_cups_cups_h=yes
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install-exec
    popd
    mkdir cross-build
    pushd cross-build
        ../configure $COMMON_CONFIG \
                     ac_cv_func_httpGetAuthString=yes ac_cv_func_mmap_fixed_mapped=yes \
                     ac_cv_header_cups_cups_h=yes
        sed -i "/SRC_SUBDIRS/s@ demos@ @g" Makefile
        make INTROSPECTION_SCANNER=${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-g-ir-scanner \
             INTROSPECTION_COMPILER=${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-g-ir-compiler ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
        rm -v ${SYSDIR}/sysroot/usr/lib64/libg*-x11*.la
    popd
popd

cat > ${SYSDIR}/sysroot/etc/gtk-2.0/gtkrc << "EOF"
include "/usr/share/themes/Clearlooks/gtk-2.0/gtkrc"
gtk-icon-theme-name = "elementary"
EOF
```

#### GTK+3
https://download.gnome.org/sources/gtk+/3.24/gtk+-3.24.37.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/gtk+-3.24.37.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/gtk+-3.24.37
    mkdir cross-prebuild
    pushd cross-prebuild
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              -Dbroadway_backend=true -Dintrospection=false \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        CC="${CROSS_TARGET}-gcc" ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              -Dbroadway_backend=true -Dintrospection=true \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        sed -i -e "s@\(${SYSDIR}/\)sysroot/usr\(.*\)\(g-ir-compiler\|g-ir-scanner\)@\1cross-tools\2${CROSS_TARGET}-\3@g" build.ninja
        CC="${CROSS_TARGET}-gcc" ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd

cat >  ${SYSDIR}/sysroot/etc/gtk-3.0/settings.ini << "EOF"
[Settings]
gtk-theme-name = Adwaita
gtk-icon-theme-name = oxygen
gtk-font-name = DejaVu Sans 12
gtk-cursor-theme-size = 18
gtk-toolbar-style = GTK_TOOLBAR_BOTH_HORIZ
gtk-xft-antialias = 1
gtk-xft-hinting = 1
gtk-xft-hintstyle = hintslight
gtk-xft-rgba = rgb
gtk-cursor-theme-name = Adwaita
EOF
```

#### GStreamer
https://gstreamer.freedesktop.org/src/gstreamer/gstreamer-1.22.1.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/gstreamer-1.22.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/gstreamer-1.22.1
    patch -Np1 -i ${DOWNLOADDIR}/gstreamer-1.20.0-add-loongarch64.patch
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

#### gst-plugins-base
https://gstreamer.freedesktop.org/src/gst-plugins-base/gst-plugins-base-1.22.1.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/gst-plugins-base-1.22.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/gst-plugins-base-1.22.1
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release --wrap-mode=nodownload \
              -Dtests=disabled \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```


#### GTK-Engines
https://download.gnome.org/sources/gtk-engines/2.20/gtk-engines-2.20.2.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/gtk-engines-2.20.2.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/gtk-engines-2.20.2
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Libcroco
https://download.gnome.org/sources/libcroco/0.6/libcroco-0.6.13.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libcroco-0.6.13.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libcroco-0.6.13
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libcroco-*.la
popd
```

#### Librsvg
https://download.gnome.org/sources/librsvg/2.54/librsvg-2.54.5.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/librsvg-2.54.5.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/librsvg-2.54.5
    patch -Np1 -i ${DOWNLOADDIR}/0001-librsvg-2.54.5-fix-loongarch64-support.patch
    find vendor -name .cargo-checksum.json \
          -exec sed -i.uncheck -e 's/"files":{[^}]*}/"files":{ }/' '{}' '+'
    mkdir cross-prebuild
    pushd cross-prebuild
        ../configure $COMMON_CONFIG --disable-introspection
        RUSTFLAGS="$RUSTFLAGS -C linker=${CROSS_TARGET}-gcc" \
        make ${JOBS}
        RUSTFLAGS="$RUSTFLAGS -C linker=${CROSS_TARGET}-gcc" \
        make DESTDIR=${SYSDIR}/sysroot install-exec
    popd
    mkdir cross-build
    pushd cross-build
        ../configure $COMMON_CONFIG --enable-vala
        RUSTFLAGS="$RUSTFLAGS -C linker=${CROSS_TARGET}-gcc" \
        make INTROSPECTION_SCANNER=${CROSS_TARGET}-g-ir-scanner \
             INTROSPECTION_COMPILER=${CROSS_TARGET}-g-ir-compiler \
             VAPIGEN=vapigen ${JOBS}
        RUSTFLAGS="$RUSTFLAGS -C linker=${CROSS_TARGET}-gcc" \
        make VAPIGEN=vapigen DESTDIR=${SYSDIR}/sysroot install
        rm -v ${SYSDIR}/sysroot/usr/lib64/librsvg*.la
    popd
popd
```

#### keybinder
https://github.com/kupferlauncher/keybinder/releases/download/v0.3.1/keybinder-0.3.1.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/keybinder-0.3.1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/keybinder-0.3.1
    mkdir cross-prebuild
    pushd cross-prebuild
        ../configure $COMMON_CONFIG --disable-python --disable-lua --disable-introspection
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
    mkdir cross-build
    pushd cross-build
        ../configure $COMMON_CONFIG --disable-python --disable-lua
        make INTROSPECTION_SCANNER=${CROSS_TARGET}-g-ir-scanner ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
        rm -v ${SYSDIR}/sysroot/usr/lib64/libkeybinder*.la
    popd
popd
```

#### Keybinder3
https://github.com/kupferlauncher/keybinder/releases/download/keybinder-3.0-v0.3.2/keybinder-3.0-0.3.2.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/keybinder-3.0-0.3.2.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/keybinder-3.0-0.3.2
    mkdir cross-prebuild
    pushd cross-prebuild
        ../configure $COMMON_CONFIG --disable-introspection
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
    mkdir cross-build
    pushd cross-build
        ../configure $COMMON_CONFIG --enable-introspection
        make INTROSPECTION_SCANNER=${CROSS_TARGET}-g-ir-scanner ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
        rm -v ${SYSDIR}/sysroot/usr/lib64/libkeybinder-3.0.la
    popd
popd
```

#### Imlib2
https://downloads.sourceforge.net/enlightenment/imlib2-1.11.0.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/imlib2-1.11.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/imlib2-1.11.0
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libImlib2.la 
popd
```

#### Libnotify
https://download.gnome.org/sources/libnotify/0.8/libnotify-0.8.2.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libnotify-0.8.2.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libnotify-0.8.2
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release -Dgtk_doc=false -Dman=false \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        sed -i -e "s@\(${SYSDIR}/\)sysroot/usr\(.*\)\(g-ir-compiler\|g-ir-scanner\)@\1cross-tools\2${CROSS_TARGET}-\3@g" build.ninja
        CC=${CROSS_TARGET}-gcc ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Alsa-Lib
https://www.alsa-project.org/files/pub/lib/alsa-lib-1.2.8.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/alsa-lib-1.2.8.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/alsa-lib-1.2.8
    cp -v ${SYSDIR}/sysroot/usr/share/automake-*/config.* ./
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libasound*.la
popd
```

#### Libogg
https://ftp.osuosl.org/pub/xiph/releases/ogg/libogg-1.3.5.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libogg-1.3.5.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libogg-1.3.5
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libogg.la
popd
```

#### FLAC
https://ftp.osuosl.org/pub/xiph/releases/flac/flac-1.4.2.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/flac-1.4.2.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/flac-1.4.2
    cp -v ${SYSDIR}/sysroot/usr/share/automake-*/config.* ./
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libFLAC.la
popd
```

#### Opus
https://archive.mozilla.org/pub/opus/opus-1.3.1.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/opus-1.3.1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/opus-1.3.1
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libopus.la
popd
```

#### Libvorbis
https://ftp.osuosl.org/pub/xiph/releases/vorbis/libvorbis-1.3.7.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libvorbis-1.3.7.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libvorbis-1.3.7
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libvorbis*.la
popd
```

#### Speex
https://ftp.osuosl.org/pub/xiph/releases/speex/speex-1.2.1.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/speex-1.2.1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/speex-1.2.1
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### SpeexDSP
https://ftp.osuosl.org/pub/xiph/releases/speex/speexdsp-1.2.1.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/speexdsp-1.2.1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/speexdsp-1.2.1
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Libsndfile
https://github.com/libsndfile/libsndfile/releases/download/1.2.0/libsndfile-1.2.0.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libsndfile-1.2.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libsndfile-1.2.0
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libsndfile.la
popd
```

#### Libsamplerate
https://github.com/libsndfile/libsamplerate/releases/download/0.2.2/libsamplerate-0.2.2.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libsamplerate-0.2.2.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libsamplerate-0.2.2
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libsamplerate.la
popd
```

#### PluseAudio
https://www.freedesktop.org/software/pulseaudio/releases/pulseaudio-16.1.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/pulseaudio-16.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/pulseaudio-16.1
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release -Ddatabase=gdbm -Dbluez5=disabled \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
rm -fv ${SYSDIR}/sysroot/etc/dbus-1/system.d/pulseaudio-system.conf
```

#### SDL2
https://www.libsdl.org/release/SDL2-2.26.4.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/SDL2-2.26.4.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/SDL2-2.26.4
    ./configure $COMMON_CONFIG
    make WAYLAND_SCANNER=wayland-scanner ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libSDL*.la
popd
```

#### Snappy
https://github.com/google/snappy/archive/1.1.10/snappy-1.1.10.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/snappy-1.1.10.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/snappy-1.1.10
    mkdir cross-build
    pushd cross-build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
              -DSNAPPY_BUILD_TESTS=OFF  -DSNAPPY_BUILD_BENCHMARKS=OFF \
              -DCMAKE_INSTALL_PREFIX=/usr -Wno-dev ..
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
popd
```   

#### Libass
https://github.com/libass/libass/releases/download/0.17.1/libass-0.17.1.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libass-0.17.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libass-0.17.1
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libass.la
popd
```

#### Fdk-Aac
https://downloads.sourceforge.net/opencore-amr/fdk-aac-2.0.2.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/fdk-aac-2.0.2.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/fdk-aac-2.0.2
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libfdk-aac.la
popd
```

#### LAME
https://downloads.sourceforge.net/lame/lame-3.100.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/lame-3.100.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/lame-3.100
    ./configure $COMMON_CONFIG --enable-mp3rtp
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libmp3lame.la
popd
```

#### Libtheora
https://ftp.osuosl.org/pub/xiph/releases/theora/libtheora-1.1.1.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libtheora-1.1.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libtheora-1.1.1
    sed -i 's/png_\(sizeof\)/\1/g' examples/png2theora.c
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libtheora*.la
popd
```

#### Libvpx
https://github.com/webmproject/libvpx/archive/v1.13.0/libvpx-1.13.0.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/libvpx-1.13.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libvpx-1.13.0
    sed -i 's/cp -p/cp/' build/make/Makefile
    mkdir cross-build
    pushd cross-build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        ../configure --prefix=/usr --libdir=/usr/lib64 \
                     --target=generic-gnu --enable-shared
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
popd
```

#### Libwebp
http://downloads.webmproject.org/releases/webp/libwebp-1.3.0.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/libwebp-1.3.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libwebp-1.3.0
    ./configure $COMMON_CONFIG \
            --enable-libwebpmux --enable-libwebpdemux \
            --enable-libwebpdecoder --enable-libwebpextras \
            --enable-swap-16bit-csp
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libwebp*.la
popd
```

#### X264
https://anduin.linuxfromscratch.org/BLFS/x264/x264-20230215.tar.xz
https://code.videolan.org/videolan/x264.git

```sh
tar xvf ${DOWNLOADDIR}/x264-20230215.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/x264-20230215
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --cross-prefix=${CROSS_TARGET}- --sysroot=${SYSDIR}/sysroot \
                --host=${CROSS_TARGET} --enable-shared --disable-cli \
                --enable-pic --enable-lto
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### X265
https://anduin.linuxfromscratch.org/BLFS/x265/x265-20230215.tar.xz
https://bitbucket.org/multicoreware/x265_git/downloads/
http://ftp.videolan.org/pub/videolan/x265/
https://bitbucket.org/multicoreware/x265_git.git

```sh
tar xvf ${DOWNLOADDIR}/x265-20230215.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/x265-20230215
    mkdir cross-build
    pushd cross-build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
              -DCMAKE_INSTALL_PREFIX=/usr -DLIB_INSTALL_DIR=/usr/lib64 \
              -DGIT_ARCHETYPE=1 ../source
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
popd
```

#### FFMpeg
https://ffmpeg.org/releases/ffmpeg-6.0.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/ffmpeg-6.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/ffmpeg-6.0
    ./configure --prefix=/usr --libdir=/usr/lib64 \
                --cross-prefix=${CROSS_TARGET}- --sysroot=${SYSDIR}/sysroot \
                --enable-gpl         \
                --enable-version3    \
                --enable-nonfree     \
                --disable-static     \
                --enable-shared      \
                --disable-debug      \
                --enable-libass      \
                --enable-libfdk-aac  \
                --enable-libfreetype \
                --enable-libmp3lame  \
                --enable-libopus     \
                --enable-libtheora   \
                --enable-libvorbis   \
                --enable-libvpx      \
                --enable-libx264     \
                --enable-libx265     \
                --enable-openssl --enable-libpulse --enable-libdrm \
                --arch=loongarch64 --target-os=linux --cc=${CROSS_TARGET}-gcc --host-cc=gcc
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### GTK4
https://download.gnome.org/sources/gtk/4.10/gtk-4.10.1.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/gtk-4.10.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/gtk-4.10.1
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release -Dbroadway-backend=true \
              -Dmedia-gstreamer=disabled -Dintrospection=enabled -Dbuild-tests=false \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        sed -i -e "s@\(${SYSDIR}/\)sysroot/usr\(.*\)\(g-ir-compiler\|g-ir-scanner\)@\1cross-tools\2${CROSS_TARGET}-\3@g" build.ninja
        CC="${CROSS_TARGET}-gcc" ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```


#### Alsa-Plugins
https://www.alsa-project.org/files/pub/plugins/alsa-plugins-1.2.7.1.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/alsa-plugins-1.2.7.1.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/alsa-plugins-1.2.7.1
    cp ${SYSDIR}/sysroot/usr/share/automake-*/config.* ./
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Alsa-Utils
https://www.alsa-project.org/files/pub/utils/alsa-utils-1.2.8.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/alsa-utils-1.2.8.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/alsa-utils-1.2.8
    cp ${SYSDIR}/sysroot/usr/share/automake-*/config.* ./
    ./configure $COMMON_CONFIG --disable-alsaconf --disable-bat \
                --disable-xmlto --with-curses=ncursesw
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Hicolor-Icon-Theme
https://icon-theme.freedesktop.org/releases/hicolor-icon-theme-0.17.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/hicolor-icon-theme-0.17.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/hicolor-icon-theme-0.17
    cp ${SYSDIR}/sysroot/usr/share/automake-*/config.* ./
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Desktop-File-Utils
https://www.freedesktop.org/software/desktop-file-utils/releases/desktop-file-utils-0.26.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/desktop-file-utils-0.26.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/desktop-file-utils-0.26
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

#### Fltk
https://www.fltk.org/pub/fltk/1.3.8/fltk-1.3.8-source.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/fltk-1.3.8-source.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/fltk-1.3.8
    sed -i "/^DIRS/s@test@@g" Makefile
    ./configure $COMMON_CONFIG --enable-shared
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    cp -v ${SYSDIR}/sysroot/usr/bin/fltk-config ${SYSDIR}/cross-tools/bin/
popd
```

#### Alsa-Tools
https://www.alsa-project.org/files/pub/tools/alsa-tools-1.2.5.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/alsa-tools-1.2.5.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/alsa-tools-1.2.5
    cp ${SYSDIR}/sysroot/usr/share/automake-*/config.* ld10k1/
    sed -i.orig -e "s@envy24control@@g" -e "s@rmedigicontrol@@g" \
                -e "s@seq@@g" -e "s@echomixer@@g" -e"s@qlo10k1@@g" Makefile
    make configure CONFIGURE_ARGS="$COMMON_CONFIG" ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Alsa-Firmware
https://www.alsa-project.org/files/pub/firmware/alsa-firmware-1.2.4.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/alsa-firmware-1.2.4.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/alsa-firmware-1.2.4
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### AudioFile
https://download.gnome.org/sources/audiofile/0.3/audiofile-0.3.6.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/audiofile-0.3.6.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/audiofile-0.3.6
    CXXFLAGS="-fpermissive -O2" ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Libzip
https://libzip.org/download/libzip-1.9.2.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libzip-1.9.2.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libzip-1.9.2
    mkdir cross-build
    pushd cross-build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
              -DCMAKE_INSTALL_PREFIX=/usr -DLIB_INSTALL_DIR=/usr/lib64 ..
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
popd
```

#### Slang
https://www.jedsoft.org/releases/slang/slang-2.3.3.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/slang-2.3.3.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/slang-2.3.3
    ./configure $COMMON_CONFIG --with-readline=gnu
    make -j1
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Libexif
https://github.com/libexif/libexif/releases/download/v0.6.24/libexif-0.6.24.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/libexif-0.6.24.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/libexif-0.6.24
    cp ${SYSDIR}/sysroot/usr/share/automake-*/config.* ./
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Startup-Notification
https://www.freedesktop.org/software/startup-notification/releases/startup-notification-0.12.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/startup-notification-0.12.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/startup-notification-0.12
    ./configure $COMMON_CONFIG lf_cv_sane_realloc=yes
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libstartup-notification-1.la
popd
```

#### Libunique
https://download.gnome.org/sources/libunique/3.0/libunique-3.0.2.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libunique-3.0.2.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libunique-3.0.2
    mkdir cross-prebuild
    pushd cross-prebuild
        ../configure $COMMON_CONFIG --disable-introspection
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
    mkdir cross-build
    pushd cross-build
        ../configure $COMMON_CONFIG --enable-introspection
        make INTROSPECTION_SCANNER=${CROSS_TARGET}-g-ir-scanner \
             INTROSPECTION_COMPILER=${CROSS_TARGET}-g-ir-compiler ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
	popd
popd
```

#### Giflib
https://sourceforge.net/projects/giflib/files/giflib-5.2.1.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/giflib-5.2.1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/giflib-5.2.1
    CC="${CROSS_TARGET}-gcc" make ${JOBS}
    make PREFIX=/usr LIBDIR=/usr/lib64 DESTDIR=${SYSDIR}/sysroot install
popd
```

#### RPCSVC-Proto
https://github.com/thkukuk/rpcsvc-proto/releases/download/v1.4.3/rpcsvc-proto-1.4.3.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/rpcsvc-proto-1.4.3.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/rpcsvc-proto-1.4.3
    ./configure --sysconfdir=/etc
    make ${JOBS}
    make -C rpcsvc DESTDIR=${SYSDIR}/sysroot install
    make distclean
    ./configure ${COMMON_CONFIG}
    make -C rpcgen ${JOBS}
    make -C rpcgen DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Libnsl
https://github.com/thkukuk/libnsl/releases/download/v2.0.0/libnsl-2.0.0.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libnsl-2.0.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libnsl-2.0.0
    cp ${SYSDIR}/sysroot/usr/share/automake-*/config.* ./
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libnsl.la
popd
```

#### Sharutils
https://ftp.gnu.org/gnu/sharutils/sharutils-4.15.2.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/sharutils-4.15.2.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/sharutils-4.15.2
    sed -i 's/BUFSIZ/rw_base_size/' src/unshar.c
    sed -i '/program_name/s/^/extern /' src/*opts.h
    sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c
    echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### CrackLib
https://github.com/cracklib/cracklib/releases/download/v2.9.10/cracklib-2.9.10.tar.bz2
https://github.com/cracklib/cracklib/releases/download/v2.9.10/cracklib-words-2.9.10.gz

```sh
tar xvf ${DOWNLOADDIR}/cracklib-2.9.10.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/cracklib-2.9.10
    cp -v ${SYSDIR}/cross-tools/share/automake-*/config.* ./
    autoreconf -ifv
    PYTHON=python3 ./configure $COMMON_CONFIG --with-default-dict=/usr/lib/cracklib/pw_dict
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    install -v -m644 -D  ${DOWNLOADDIR}/cracklib-words-2.9.10.gz \
                         ${SYSDIR}/sysroot/usr/share/dict/cracklib-words.gz
    gunzip -v ${SYSDIR}/sysroot/usr/share/dict/cracklib-words.gz
    install -v -m755 -d ${SYSDIR}/sysroot/usr/lib/cracklib
popd
```

#### Linux-PAM
https://github.com/linux-pam/linux-pam/releases/download/v1.5.2/Linux-PAM-1.5.2.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/Linux-PAM-1.5.2.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/Linux-PAM-1.5.2
    ./configure $COMMON_CONFIG --enable-securedir=/usr/lib64/security \
                ac_cv_func_yp_get_default_domain=no
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    chmod -v 4755 ${SYSDIR}/sysroot/usr/sbin/unix_chkpwd
popd

mkdir -pv ${SYSDIR}/sysroot/etc/pam.d

cat > ${SYSDIR}/sysroot/etc/pam.d/system-account << "EOF"
account   required    pam_unix.so
EOF

cat > ${SYSDIR}/sysroot/etc/pam.d/system-auth << "EOF"
auth      required    pam_unix.so
EOF

cat > ${SYSDIR}/sysroot/etc/pam.d/system-session << "EOF"
session   required    pam_unix.so
EOF
cat > ${SYSDIR}/sysroot/etc/pam.d/system-password << "EOF"
password  required    pam_unix.so       sha512 shadow try_first_pass
EOF

cat > ${SYSDIR}/sysroot/etc/pam.d/other << EOF
auth            required        pam_unix.so     nullok
account         required        pam_unix.so
session         required        pam_unix.so
password        required        pam_unix.so     nullok
EOF

```


Mozjs-91
https://archive.mozilla.org/pub/firefox/releases/91.13.0esr/source/firefox-91.13.0esr.source.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/firefox-91.13.0esr.source.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/firefox-91.13.0
    patch -Np1 -i ${DOWNLOADDIR}/0001-mozjs-91-add-loongarch64-supprot.patch
    cp -v ${SYSDIR}/sysroot/usr/share/automake-*/config.* build/autoconf/
    mkdir cross-build
    pushd cross-build
    	chmod +x ../js/src/configure.in
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        ../js/src/configure.in --prefix=/usr --libdir=/usr/lib64 \
                    --target=loongarch64-unknown-linux-gnu \
                    --with-intl-api --with-system-zlib --with-system-icu \
                    --disable-jemalloc --disable-debug-symbols --enable-readline
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
        rm -v ${SYSDIR}/sysroot/usr/lib64/libjs_static.ajs
        sed -i '/@NSPR_CFLAGS@/d' ${SYSDIR}/sysroot/usr/bin/js91-config
    popd
popd
```

#### PolKit
https://www.freedesktop.org/software/polkit/releases/polkit-121.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/polkit-121.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/polkit-121

    mkdir cross-prebuild
    pushd cross-prebuild
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              -Dsession_tracking=libsystemd-login -Djs_engine=mozjs -Dintrospection=disabled \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        CC="${CROSS_TARGET}-gcc" ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              -Dsession_tracking=libsystemd-login -Djs_engine=mozjs -Dintrospection=enabled \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        sed -i -e "s@\(${SYSDIR}/\)sysroot/usr\(.*\)\(g-ir-compiler\|g-ir-scanner\)@\1cross-tools\2${CROSS_TARGET}-\3@g" build.ninja
        CC="${CROSS_TARGET}-gcc" ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd

cat > ${SYSDIR}/sysroot/etc/pam.d/polkit-1 << "EOF"
# Begin /etc/pam.d/polkit-1

auth     include        system-auth
account  include        system-account
password include        system-password
session  include        system-session

# End /etc/pam.d/polkit-1
EOF

```


#### Libpwquality
https://github.com/libpwquality/libpwquality/releases/download/libpwquality-1.4.5/libpwquality-1.4.5.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/libpwquality-1.4.5.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/libpwquality-1.4.5
    cp -v ${SYSDIR}/cross-tools/share/automake-*/config.* ./
    _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_${CROSS_TARGET} \
    ./configure $COMMON_CONFIG --with-securedir=/usr/lib/security \
                --with-python-binary=python3
    _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_${CROSS_TARGET} \
    make ${JOBS}
    _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_${CROSS_TARGET} \
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Krb5
https://kerberos.org/dist/krb5/1.20/krb5-1.20.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/krb5-1.20.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/krb5-1.20/src
    cp ${SYSDIR}/sysroot/usr/share/automake-*/config.* config/
    sed -i "s@error=discarded-qualifiers@@g" configure
    ./configure ${COMMON_CONFIG} --runstatedir=/run \
                --with-system-ss --with-system-verto=no \
                --enable-dns-for-realm \
                krb5_cv_attr_constructor_destructor=yes,yes \
                ac_cv_func_regcomp=yes ac_cv_printf_positional=yes
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
cp -v ${SYSDIR}/sysroot/usr/bin/krb5-config ${SYSDIR}/cross-tools/bin/krb5-config
sed -i "s@-L\$libdir@@g" ${SYSDIR}/cross-tools/bin/krb5-config
```

#### Cyrus-Sasl
https://github.com/cyrusimap/cyrus-sasl/releases/download/cyrus-sasl-2.1.28/cyrus-sasl-2.1.28.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/cyrus-sasl-2.1.28.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/cyrus-sasl-2.1.28
    ./configure ${COMMON_CONFIG} --enable-auth-sasldb --with-sphinx-build=no \
            --with-dbpath=/var/lib/sasl/sasldb2 --with-saslauthd=/var/run/saslauthd \
            ac_cv_gssapi_supports_spnego=yes
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Elogind
https://github.com/elogind/elogind/archive/v246.10/elogind-246.10.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/elogind-246.10.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/elogind-246.10
    patch -Np1 -i ${DOWNLOADDIR}/elogind-246-add-loongarch64.patch
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release -Dcgroup-controller=elogind \
              -Ddbuspolicydir=/etc/dbus-1/system.d \
              -Ddefault-kill-user-processes=false \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### LZip
http://download.savannah.gnu.org/releases/lzip/lzip-1.23.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/lzip-1.23.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/lzip-1.23
	./configure CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" --prefix=/usr
	make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### LZ4
https://github.com/lz4/lz4/archive/v1.9.4/lz4-1.9.4.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/lz4-1.9.4.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/lz4-1.9.4
    make CC=${CROSS_TARGET}-gcc PREFIX=/usr LIBDIR=/usr/lib64 ${JOBS}
    make CC=${CROSS_TARGET}-gcc PREFIX=/usr LIBDIR=/usr/lib64 DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Protobuf3
https://github.com/protocolbuffers/protobuf/releases/download/v3.20.3/protobuf-all-3.20.3.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/protobuf-all-3.20.3.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/protobuf-3.20.3
	./autogen.sh
	./configure $COMMON_CONFIG
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Mosh
https://mosh.org/mosh-1.4.0.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/mosh-1.4.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/mosh-1.4.0
	./configure $COMMON_CONFIG ac_cv_path_PROTOC="qemu-loongarch64 ${SYSDIR}/sysroot/usr/bin/protoc"
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Emacs
https://ftp.gnu.org/gnu/emacs/emacs-28.2.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/emacs-28.2.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/emacs-28.2
	sed -i "s@)\$(libsrc)/make-docfile@) qemu-loongarch64 \$\(libsrc\)/make-docfile@g" src/Makefile.in
	sed -i -e "s@bootstrap_exe = \(.*\)@ bootstrap_exe = /bin/emacs@g" src/Makefile.in
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET} \
	            --with-dumping=none
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Apr
https://archive.apache.org/dist/apr/apr-1.7.2.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/apr-1.7.2.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/apr-1.7.2
    sed -e "/shift/i \
            \    if (xt->tm_mon < 0 || xt->tm_mon >= 12) return APR_EBADDATE;" \
        -i.orig time/unix/time.c
    cp ${SYSDIR}/cross-tools/share/automake-1.16/config.* build/
    sed -i.orig -e "/hasposixser/s@0@1@g" \
           -e "/hasprocpthreadser/s@0@1@g" \
           -e "/have_iovec/s@0@1@g" \
           -e "/havemmapzero/s@0@1@g" configure
    ./configure $COMMON_CONFIG \
            --disable-static \
            --with-installbuilddir=/usr/share/apr-1/build \
            ac_cv_file__dev_zero=yes ac_cv_func_setpgrp_void=yes apr_cv_process_shared_works=yes \
            apr_cv_mutex_robust_shared=yes apr_cv_tcp_nodelay_with_cork=yes ac_cv_sizeof_pid_t=4 \
            ac_cv_o_nonblock_inherited=no ac_cv_struct_rlimit=yes
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm ${SYSDIR}/sysroot/usr/lib64/libapr-1.la
    cp -v ${SYSDIR}/sysroot/usr/bin/apr-1-config ${SYSDIR}/cross-tools/bin/
    sed -i "/APR_TARGET_DIR=/s@APR_TARGET_DIR=.*@APR_TARGET_DIR=${SYSDIR}/sysroot ;;@g" ${SYSDIR}/cross-tools/bin/apr-1-config
popd
```

#### Apr-Util
https://archive.apache.org/dist/apr/apr-util-1.6.3.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/apr-util-1.6.3.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/apr-util-1.6.3
    ./configure $COMMON_CONFIG \
            --with-apr=${SYSDIR}/cross-tools \
            --with-gdbm=${SYSDIR}/sysroot/usr \
            --with-openssl=${SYSDIR}/sysroot/usr \
            --with-crypto
    cp -v $(apr-1-config --installbuilddir)/apr_rules.mk build/rules.mk
    sed -i "/^apr_build/s@=\/usr@=${SYSDIR}/sysroot/usr@g" build/rules.mk
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm ${SYSDIR}/sysroot/usr/lib64/libaprutil-1.la
    cp -v ${SYSDIR}/sysroot/usr/bin/apu-1-config ${SYSDIR}/cross-tools/bin/
popd
```

#### Scons
https://downloads.sourceforge.net/scons/SCons-4.5.2.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/SCons-4.5.2.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/SCons-4.5.2
    ${SYSDIR}/cross-tools/bin/python3 setup.py build
    python3 setup.py install --optimize=1
    ${SYSDIR}/cross-tools/bin/python3 setup.py install \
             --optimize=1 --root=${SYSDIR}/sysroot --prefix=/usr \
             --install-data=/usr/share/man/man1
popd
```

#### Serf
https://archive.apache.org/dist/serf/serf-1.3.9.tar.bz2
https://www.linuxfromscratch.org/patches/blfs/svn/serf-1.3.9-openssl3_fixes-1.patch

```sh
tar xvf ${DOWNLOADDIR}/serf-1.3.9.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/serf-1.3.9
    patch -Np1 -i ${DOWNLOADDIR}/serf-1.3.9-openssl3_fixes-1.patch
    sed -i "/Append/s:RPATH=libdir,::"          SConstruct
    sed -i "/Default/s:lib_static,::"           SConstruct
    sed -i "/Alias/s:install_static,::"         SConstruct
    sed -i "/  print/{s/print/print(/; s/$/)/}" SConstruct
    sed -i "/get_contents()/s/,/.decode()&/"    SConstruct
    scons PREFIX=/usr LIBDIR=/usr/lib64 APR=${SYSDIR}/cross-tools \
          APU=${SYSDIR}/cross-tools ZLIB=${SYSDIR}/sysroot/usr OPENSSL=${SYSDIR}/sysroot/usr \
          CC="${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-gcc"
    scons PREFIX=${SYSDIR}/sysroot/usr LIBDIR=${SYSDIR}/sysroot/usr/lib64 APR=${SYSDIR}/cross-tools \
          APU=${SYSDIR}/cross-tools ZLIB=${SYSDIR}/sysroot/usr OPENSSL=${SYSDIR}/sysroot/usr \
          CC="${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-gcc" install
popd
```

#### Subversion
https://archive.apache.org/dist/subversion/subversion-1.14.2.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/subversion-1.14.2.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/subversion-1.14.2
    PYTHON=python3 \
    ./configure $COMMON_CONFIG --disable-static \
                --with-apache-libexecdir --with-lz4=internal \
                --with-serf=${SYSDIR}/sysroot/usr --with-utf8proc=internal
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### QT
https://download.qt.io/archive/qt/5.15/5.15.8/single/qt-everywhere-opensource-src-5.15.8.tar.xz
https://www.linuxfromscratch.org/patches/blfs/svn/qt-everywhere-opensource-src-5.15.8-kf5-1.patch

```sh
tar xvf ${DOWNLOADDIR}/qt-everywhere-opensource-src-5.15.8.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/qt-everywhere-src-5.15.8
    patch -Np1 -i ${DOWNLOADDIR}/qt-everywhere-opensource-src-5.15.8-kf5-1.patch
    patch -Np1 -i ${DOWNLOADDIR}/qt-everywhere-src-5.15.2-add-loongarch-config.patch
    patch -Np1 -i ${DOWNLOADDIR}/qt-everywhere-src-5.15.6-fix-for-gcc13.patch
    patch -Np1 -i ${DOWNLOADDIR}/0001-QT-5.15.8-add-loongarch64-support.patch
    cp qtbase/src/corelib/thread/qtsan_impl.h qtbase/include/QtCore/
    mkdir pre-build
    pushd pre-build
        PKG_CONFIG_LIBDIR=${SYSDIR}/sysroot/usr/lib64/pkgconfig:${SYSDIR}/sysroot/usr/share/pkgconfig \
        ../configure -hostprefix ${SYSDIR}/cross-tools \
                -prefix /usr -sysconfdir /etc/xdg \
                -libdir /usr/lib64 -archdatadir /usr/lib64/qt5 \
                -bindir /usr/bin \
                -plugindir /usr/lib64/qt5/plugins \
                -importdir /usr/lib64/qt5/imports \
                -headerdir /usr/include/qt5 \
                -datadir /usr/share/qt5 \
                -docdir /usr/share/doc/qt5 \
                -translationdir /usr/share/qt5/translations \
                -confirm-license -opensource \
                -system-sqlite \
                -nomake examples -no-rpath \
                -dbus-linked -journald \
                -skip qtwebengine \
                -sysroot ${SYSDIR}/sysroot \
                -xplatform linux-loongarch64-gnu-g++
        make ${JOBS}
        make install
    popd
    mkdir cross-build
    pushd cross-build
       ../configure -external-hostbindir ${SYSDIR}/cross-tools/bin \
                -prefix /usr -sysconfdir /etc/xdg \
                -libdir /usr/lib64 -archdatadir /usr/lib64/qt5 \
                -bindir /usr/bin \
                -plugindir /usr/lib64/qt5/plugins \
                -importdir /usr/lib64/qt5/imports \
                -headerdir /usr/include/qt5 \
                -datadir /usr/share/qt5 \
                -docdir /usr/share/doc/qt5 \
                -translationdir /usr/share/qt5/translations \
                -confirm-license -opensource \
                -openssl-linked -system-harfbuzz -system-sqlite \
                -nomake examples -no-rpath \
                -dbus-linked -journald \
                -skip qtwebengine \
                -platform linux-loongarch64-gnu-g++
        make ${JOBS}
        make INSTALL_ROOT=${SYSDIR}/sysroot install
    popd
popd
```

#### SIP
https://www.riverbankcomputing.com/static/Downloads/sip/4.19.25/sip-4.19.25.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/sip-4.19.25.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/sip-4.19.25
    patch -Np1 -i ${DOWNLOADDIR}/sip-add-loongarch64.patch
    mkdir native-build
    pushd native-build
        ${SYSDIR}/cross-tools/bin/python3 ../configure.py
        make ${JOBS}
        make install
    popd
    mkdir cross-build
    pushd cross-build
        ${SYSDIR}/cross-tools/bin/python3 \
        ../configure.py --platform=linux-loongarch64-gnu-g++ \
                     --sysroot=${SYSDIR}/sysroot/usr
        make ${JOBS}
        make install
    popd
popd
```


#### PyQt5
https://files.pythonhosted.org/packages/5c/46/b4b6eae1e24d9432905ef1d4e7c28b6610e28252527cdc38f2a75997d8b5/PyQt5-5.15.9.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/PyQt5-5.15.9.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/PyQt5-5.15.9
    patch -Np1 -i ${DOWNLOADDIR}/pyqt-5.15.6-cross_compiler.patch
    patch -Np1 -i ${DOWNLOADDIR}/pyqt-5.15.6-fix-sip.patch
    sed -i "s,@MinimumSipVersion@,4.19.25," configure.py
    _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_${CROSS_TARGET} \
    ${SYSDIR}/cross-tools/bin/python3 ./configure.py --confirm-license \
              --bindir=/usr/bin --sipdir=/usr/share/sip/PyQt5 \
              --destdir=/usr/lib64/python3.10/site-packages \
              --stubsdir=/usr/lib64/python3.10/site-packages/PyQt5 \
              --sip-incdir=${SYSDIR}/sysroot/usr/include/python3.10
    make ${JOBS}
    make INSTALL_ROOT=${SYSDIR}/sysroot install
popd
```

#### Libgpg-error
https://www.gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.46.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/libgpg-error-1.46.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/libgpg-error-1.46
    cp ${SYSDIR}/sysroot/usr/share/automake-*/config.* build-aux/
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libgpg-error*.la
popd
```

#### Libgcrypt
https://www.gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-1.10.1.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/libgcrypt-1.10.1.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/libgcrypt-1.10.1
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libgcrypt*.la
    cp -av ${SYSDIR}/sysroot/bin/libgcrypt-config ${SYSDIR}/cross-tools/bin/
popd
```

#### Libsecret
https://download.gnome.org/sources/libsecret/0.20/libsecret-0.20.5.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libsecret-0.20.5.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libsecret-0.20.5
    mkdir cross-prebuild
    pushd cross-prebuild
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              -Dgtk_doc=false -Dintrospection=false \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              -Dgtk_doc=false \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        sed -i -e "s@\(${SYSDIR}/\)sysroot/usr\(.*\)\(g-ir-compiler\|g-ir-scanner\)@\1cross-tools\2${CROSS_TARGET}-\3@g" build.ninja
        CC="${CROSS_TARGET}-gcc" ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Gcr
https://download.gnome.org/sources/gcr/4.1/gcr-4.1.0.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/gcr-4.1.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/gcr-4.1.0
    find . -name meson.build | xargs sed -i /packages.\*deps/d
    sed -i 's:"/desktop:"/org:' schema/*.xml
    sed -e '208 s/@BASENAME@/gcr-viewer.desktop/'   \
        -e '231 s/@BASENAME@/gcr-prompter.desktop/' \
        -i ui/meson.build
    mkdir cross-prebuild
    pushd cross-prebuild
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              -Dgtk_doc=false -Dintrospection=false \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              -Dgtk_doc=false \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        sed -i -e "s@\(${SYSDIR}/\)sysroot/usr\(.*\)\(g-ir-compiler\|g-ir-scanner\)@\1cross-tools\2${CROSS_TARGET}-\3@g" build.ninja
        sed -i -e "s@\(${SYSDIR}/\)cross-tools/bin/vapigen@\1cross-tools/bin/${CROSS_TARGET}-vapigen@g" build.ninja
        CC="${CROSS_TARGET}-gcc" ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### gnome-keyring
https://download.gnome.org/sources/gnome-keyring/42/gnome-keyring-42.1.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/gnome-keyring-42.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/gnome-keyring-42.1
    cp ${SYSDIR}/sysroot/usr/share/automake-*/config.* build/
    sed -i 's:"/desktop:"/org:' schema/*.xml
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

##### libgnome-keyring-1
https://download.gnome.org/sources/libgnome-keyring/3.12/libgnome-keyring-3.12.0.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libgnome-keyring-3.12.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libgnome-keyring-3.12.0
    sed -i.orig "s/unlock skip/@unlock skip/g" library/GnomeKeyring-1.0.metadata
    mkdir cross-prebuild
    pushd cross-prebuild
        ../configure $COMMON_CONFIG --disable-introspection
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install-exec
    popd
    mkdir cross-build
    pushd cross-build
        ../configure $COMMON_CONFIG
        make INTROSPECTION_SCANNER=${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-g-ir-scanner \
             INTROSPECTION_COMPILER=${SYSDIR}/cross-tools/bin/g-ir-compiler \
             VAPIGEN=vapigen ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
        rm -v ${SYSDIR}/sysroot/usr/lib64/libgnome-keyring*.la
    popd
popd
```


#### UPower
https://gitlab.freedesktop.org/upower/upower/-/archive/v1.90.0/upower-v1.90.0.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/upower-v1.90.0.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/upower-v1.90.0
    mkdir cross-prebuild
    pushd cross-prebuild
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              -Dgtk-doc=false -Dman=false -Dintrospection=disabled \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release -Dgtk-doc=false -Dman=false \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        sed -i -e "s@\(${SYSDIR}/\)sysroot/usr\(.*\)\(g-ir-compiler\|g-ir-scanner\)@\1cross-tools\2${CROSS_TARGET}-\3@g" build.ninja
        CC="${CROSS_TARGET}-gcc" ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Jansson
https://digip.org/jansson/releases/jansson-2.13.1.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/jansson-2.13.1.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/jansson-2.13.1
    cp ${SYSDIR}/sysroot/usr/share/automake-*/config.* ./
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libjansson.la
popd
```

#### Libndp
http://libndp.org/files/libndp-1.8.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/libndp-1.8.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libndp-1.8
    cp ${SYSDIR}/sysroot/usr/share/automake-*/config.* build-aux/
    ./configure $COMMON_CONFIG ac_cv_func_malloc_0_nonnull=yes \
	            ac_cv_func_realloc_0_nonnull=yes
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libndp.la
popd
```

#### Libmbim
https://www.freedesktop.org/software/libmbim/libmbim-1.26.4.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libmbim-1.26.4.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libmbim-1.26.4
    mkdir cross-prebuild
    pushd cross-prebuild
        ../configure $COMMON_CONFIG --disable-introspection
	    make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install-exec
    popd
    mkdir cross-build
    pushd cross-build
        ../configure $COMMON_CONFIG --enable-introspection
        make INTROSPECTION_SCANNER=${CROSS_TARGET}-g-ir-scanner \
             INTROSPECTION_COMPILER=${CROSS_TARGET}-g-ir-compiler ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
        rm -v ${SYSDIR}/sysroot/usr/lib64/libmbim*.la
    popd
popd
```

#### Libqmi
https://www.freedesktop.org/software/libqmi/libqmi-1.30.8.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libqmi-1.30.8.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libqmi-1.30.8
    mkdir cross-prebuild
    pushd cross-prebuild
        ../configure $COMMON_CONFIG --disable-introspection
	    make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install-exec
    popd
    mkdir cross-build
    pushd cross-build
        ../configure $COMMON_CONFIG --enable-introspection
        make INTROSPECTION_SCANNER=${CROSS_TARGET}-g-ir-scanner \
             INTROSPECTION_COMPILER=${CROSS_TARGET}-g-ir-compiler ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
        rm -v ${SYSDIR}/sysroot/usr/lib64/libqmi*.la
    popd
popd
```

#### ModemManager
https://www.freedesktop.org/software/ModemManager/ModemManager-1.18.12.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/ModemManager-1.18.12.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/ModemManager-1.18.12
    mkdir cross-prebuild
    pushd cross-prebuild
        ../configure $COMMON_CONFIG --with-systemd-journal=no     \
                     --with-systemd-suspend-resume  --disable-introspection
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install-exec
    popd
    mkdir cross-build
    pushd cross-build
        ../configure $COMMON_CONFIG --with-systemd-journal=no     \
                     --with-systemd-suspend-resume  --enable-introspection
        make INTROSPECTION_SCANNER=${CROSS_TARGET}-g-ir-scanner \
             INTROSPECTION_COMPILER=${CROSS_TARGET}-g-ir-compiler \
             VAPIGEN=${CROSS_TARGET}-vapigen ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
        rm -v ${SYSDIR}/sysroot/usr/lib64/libmm-*.la
    popd
popd
```

#### Mobile-Broadband-Provider-Info
https://download.gnome.org/sources/mobile-broadband-provider-info/20221107/mobile-broadband-provider-info-20221107.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/mobile-broadband-provider-info-20221107.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/mobile-broadband-provider-info-20221107
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Libidn2
https://ftp.gnu.org/gnu/libidn/libidn2-2.3.4.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/libidn2-2.3.4.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libidn2-2.3.4
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libidn2.la
popd
```

#### Libpsl
https://github.com/rockdaboot/libpsl/releases/download/0.21.2/libpsl-0.21.2.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/libpsl-0.21.2.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libpsl-0.21.2
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libpsl.la
popd
```

#### Popt
http://ftp.rpm.org/popt/releases/popt-1.x/popt-1.19.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/popt-1.19.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/popt-1.19
    cp ${SYSDIR}/sysroot/usr/share/automake-*/config.* build-aux/
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    rm -v ${SYSDIR}/sysroot/usr/lib64/libpopt.la
popd
```

#### Newt
https://releases.pagure.org/newt/newt-0.52.23.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/newt-0.52.23.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/newt-0.52.23
    ./configure $COMMON_CONFIG --with-gpm-support --without-python
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### NetworkManager
https://download.gnome.org/sources/NetworkManager/1.43/NetworkManager-1.43.4.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/NetworkManager-1.43.4.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/NetworkManager-1.43.4
    sed -i "s@jansson_libdir,@'${SYSDIR}/sysroot' + &@g" meson.build
    mkdir cross-prebuild
    pushd cross-prebuild
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              -Dlibaudit=no -Dnmtui=true -Dselinux=false -Dppp=false \
              -Dmodem_manager=true -Dqt=false -Dsession_tracking=systemd \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        sed -i -e "s@\(${SYSDIR}/\)sysroot/usr\(.*\)\(g-ir-compiler\|g-ir-scanner\)@\1cross-tools\2${CROSS_TARGET}-\3@g" build.ninja
        CC=${CROSS_TARGET}-gcc ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### ZSH
https://www.zsh.org/pub/zsh-5.9.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/zsh-5.9.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/zsh-5.9
    cp ${SYSDIR}/sysroot/usr/share/automake-*/config.* ./
    ./configure --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                --prefix=/usr --sysconfdir=/etc/zsh \
                --enable-etcdir=/etc/zsh
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Fish
https://github.com/fish-shell/fish-shell/releases/download/3.6.1/fish-3.6.1.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/fish-3.6.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/fish-3.6.1
    mkdir cross-build
    pushd cross-build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
              -DCURSES_LIBRARY="-lncursesw" -DCURSES_TINFO="" \
              -DCMAKE_INSTALL_PREFIX=/usr -DLIB_INSTALL_DIR=/usr/lib64 ..
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
popd
```

#### Screen
https://ftp.gnu.org/gnu/screen/screen-4.9.0.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/screen-4.9.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/screen-4.9.0
    ./autogen.sh
    ./configure $COMMON_CONFIG --with-socket-dir=/run/screen \
            --with-pty-group=5 --with-sys-screenrc=/etc/screenrc
    sed -i -e "s%/usr/local/etc/screenrc%/etc/screenrc%" {etc,doc}/*
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    install -m 644 etc/etcscreenrc ${SYSDIR}/sysroot/etc/screenrc
popd
```

#### Tmux
https://github.com/tmux/tmux/releases/download/3.3a/tmux-3.3a.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/tmux-3.3a.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/tmux-3.3a
    ./configure $COMMON_CONFIG --with-TERM=screen
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    install -m 644 example_tmux.conf ${SYSDIR}/sysroot/etc/example_tmux.conf
popd
```

#### Which
https://ftp.gnu.org/gnu/which/which-2.21.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/which-2.21.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/which-2.21
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### XScreenSaver
https://www.jwz.org/xscreensaver/xscreensaver-6.06.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/xscreensaver-6.06.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/xscreensaver-6.06
    cp ${SYSDIR}/sysroot/usr/share/automake-*/config.* ./
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make install_prefix=${SYSDIR}/sysroot install
popd
cat > ${SYSDIR}/sysroot/etc/pam.d/xscreensaver << "EOF"
# Begin /etc/pam.d/xscreensaver

auth    include system-auth
account include system-account

# End /etc/pam.d/xscreensaver
EOF
```

#### Colord
https://www.freedesktop.org/software/colord/releases/colord-1.4.6.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/colord-1.4.6.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/colord-1.4.6
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              -Ddaemon_user=colord -Dvapi=true -Dsystemd=false \
              -Dlibcolordcompat=true -Dargyllcms_sensor=false \
              -Dbash_completion=false -Ddocs=false -Dman=false \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        sed -i -e "s@\(${SYSDIR}/\)sysroot/usr\(.*\)\(g-ir-compiler\|g-ir-scanner\)@\1cross-tools\2${CROSS_TARGET}-\3@g" build.ninja
        CC="${CROSS_TARGET}-gcc" ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Pipewire
https://github.com/PipeWire/pipewire/archive/0.3.67/pipewire-0.3.67.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/pipewire-0.3.67.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/pipewire-0.3.67
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              -Dsession-managers= \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Weston
https://wayland.freedesktop.org/releases/weston-11.0.1.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/weston-11.0.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/weston-11.0.1
    sed -i -e "/dep_scanner =/s@, native: true@@g" \
           -e "/prog_scanner =/s@find_program\(.*\)\$@find_program('wayland-scanner')@g" \
           protocol/meson.build
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 --buildtype=release \
              -Ddoc=false -Dbackend-rdp=false \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Libxklavier
https://people.freedesktop.org/~svu/libxklavier-5.4.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/libxklavier-5.4.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/libxklavier-5.4
    mkdir cross-prebuild
    pushd cross-prebuild
        ../configure $COMMON_CONFIG --disable-introspection
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install-exec
    popd
    mkdir cross-build
    pushd cross-build
        ../configure $COMMON_CONFIG --enable-introspection=yes
        make INTROSPECTION_SCANNER=${CROSS_TARGET}-g-ir-scanner \
             INTROSPECTION_COMPILER=${CROSS_TARGET}-g-ir-compiler \
             VAPIGEN=vapigen ${JOBS}
        make VAPIGEN=vapigen DESTDIR=${SYSDIR}/sysroot install
        rm -v ${SYSDIR}/sysroot/usr/lib64/libxklavier*.la
    popd
popd
```

#### Cldr-emoji-annotation
https://github.com/fujiwarat/cldr-emoji-annotation/releases/download/38-alpha1.0_13.0_0_1/cldr-emoji-annotation-38-alpha1.0_13.0_0_1.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/cldr-emoji-annotation-38-alpha1.0_13.0_0_1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/cldr-emoji-annotation-38-alpha1.0_13.0_0_1
    ./configure $COMMON_CONFIG --enable-dtd
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Fmt
https://github.com/fmtlib/fmt/archive/9.1.0/fmt-9.1.0.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/fmt-9.1.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/fmt-9.1.0
    mkdir cross-build
    pushd cross-build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
              -DFMT_TEST=false \
              -DCMAKE_INSTALL_PREFIX=/usr ..
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
popd
```

#### Extra-cmake-modules
https://download.kde.org/stable/frameworks/5.104/extra-cmake-modules-5.104.0.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/extra-cmake-modules-5.104.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/extra-cmake-modules-5.104.0
    mkdir cross-build
    pushd cross-build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
              -DCMAKE_INSTALL_PREFIX=/usr -DLIB_INSTALL_DIR=/usr/lib64 ..
        make DESTDIR=${SYSDIR}/sysroot install
    popd
popd
```

#### Xcb-imdkit
https://github.com/fcitx/xcb-imdkit/archive/1.0.5/xcb-imdkit-1.0.5.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/xcb-imdkit-1.0.5.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/xcb-imdkit-1.0.5
    mkdir cross-build
    pushd cross-build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
              -DCMAKE_INSTALL_PREFIX=/usr ..
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
popd
```

#### Json-C
https://s3.amazonaws.com/json-c_releases/releases/json-c-0.16.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/json-c-0.16.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/json-c-0.16
    mkdir cross-build
    pushd cross-build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
              -DCMAKE_INSTALL_PREFIX=/usr ..
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
popd
```

#### Enchant
https://github.com/AbiWord/enchant/releases/download/v2.3.4/enchant-2.3.4.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/enchant-2.3.4.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/enchant-2.3.4
    cp ${SYSDIR}/cross-tools/share/automake-1.16/config.* build-aux/
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### DConf
https://download.gnome.org/sources/dconf/0.40/dconf-0.40.0.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/dconf-0.40.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/dconf-0.40.0
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              -Dbash_completion=false \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Libhandy
https://download.gnome.org/sources/libhandy/1.8/libhandy-1.8.2.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libhandy-1.8.2.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libhandy-1.8.2
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

#### DConf-Editor
https://download.gnome.org/sources/dconf-editor/43/dconf-editor-43.0.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/dconf-editor-43.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/dconf-editor-43.0
    sed -e '/  desktop,/d' \
        -e '/  appdata,/d' \
        -i editor/meson.build
    mkdir cross-build
    pushd cross-build
        VALAC=${CROSS_TARGET}-valac \
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```


#### PyCairo
https://github.com/pygobject/pycairo/releases/download/v1.23.0/pycairo-1.23.0.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/pycairo-1.23.0.tar.gz -C ${BUILDDIR}
cp -a ${BUILDDIR}/pycairo-1.23.0{,-native}
pushd ${BUILDDIR}/pycairo-1.23.0-native
    PKG_CONFIG_PATH="" \
    LDFLAGS="" PKG_CONFIG_SYSROOT_DIR="" ${SYSDIR}/cross-tools/bin/python3 setup.py build
    PKG_CONFIG_PATH="" \
    LDFLAGS="" PKG_CONFIG_SYSROOT_DIR="" ${SYSDIR}/cross-tools/bin/python3 setup.py install --optimize=1
popd
pushd ${BUILDDIR}/pycairo-1.23.0
        _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_${CROSS_TARGET} \
        ${SYSDIR}/cross-tools/bin/python3 setup.py build
        _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_${CROSS_TARGET} \
        ${SYSDIR}/cross-tools/bin/python3 setup.py install --optimize=1 --root=${SYSDIR}/sysroot --prefix=/usr
popd
```

#### PyGobject
https://download.gnome.org/sources/pygobject/3.44/pygobject-3.44.1.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/pygobject-3.44.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/pygobject-3.44.1
    mkdir cross-build
    pushd cross-build
        PYTHON=${SYSDIR}/cross-tools/bin/python3 \
        _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_${CROSS_TARGET} \
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        sed -i -e "s@\(${SYSDIR}/\)sysroot/usr\(.*\)\(g-ir-compiler\|g-ir-scanner\)@\1cross-tools\2${CROSS_TARGET}-\3@g" build.ninja
        CC="${CROSS_TARGET}-gcc" ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### PyXDG
https://files.pythonhosted.org/packages/6f/2e/2251b5ae2f003d865beef79c8fcd517e907ed6a69f58c32403cec3eba9b2/pyxdg-0.28.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/pyxdg-0.28.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/pyxdg-0.28
    _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_${CROSS_TARGET} \
    ${SYSDIR}/cross-tools/bin/python3 setup.py build
    _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_${CROSS_TARGET} \
    ${SYSDIR}/cross-tools/bin/python3 setup.py install --optimize=1 --root=${SYSDIR}/sysroot --prefix=/usr
popd
```

#### DBus-Python
https://dbus.freedesktop.org/releases/dbus-python/dbus-python-1.3.2.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/dbus-python-1.3.2.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/dbus-python-1.3.2
    mkdir python3
    pushd python3
        PYTHON=${SYSDIR}/cross-tools/bin/python3 \
        ../configure $COMMON_CONFIG --docdir=/usr/share/doc/dbus-python
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
popd
```

#### Systemd (再次编译)
```sh
tar xvf ${DOWNLOADDIR}/systemd-253.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/systemd-253
	pushd src/basic
        python3 missing_syscalls.py missing_syscall_def.h $(ls syscalls-*.txt)
	popd
	sed -i -e 's/GROUP="render"/GROUP="video"/' \
           -e 's/GROUP="sgx", //' rules.d/50-udev-default.rules.in
	mkdir -p cross-build
	pushd cross-build
		meson --prefix=/usr --libdir=/usr/lib64 --sysconfdir=/etc --localstatedir=/var \
		      -Dbuildtype=release -Ddefault-dnssec=no -Dfirstboot=false \
		      -Dinstall-tests=false -Dldconfig=false -Dsysusers=false \
		      -Drpmmacrosdir=no -Dhomed=false -Duserdb=false -Dman=false -Dmode=release \
		      -Dpamconfdir=/etc/pam.d -Ddefault-kill-user-processes=false \
		      --cross-file ${BUILDDIR}/meson-cross.txt ..
		ninja
		DESTDIR=${SYSDIR}/sysroot ninja install
	popd
popd

cat >> ${SYSDIR}/sysroot/etc/pam.d/system-session << "EOF"
session  required    pam_loginuid.so
session  optional    pam_systemd.so
EOF

cat > ${SYSDIR}/sysroot/etc/pam.d/systemd-user << "EOF"
account  required    pam_access.so
account  include     system-account

session  required    pam_env.so
session  required    pam_limits.so
session  required    pam_unix.so
session  required    pam_loginuid.so
session  optional    pam_keyinit.so force revoke
session  optional    pam_systemd.so

auth     required    pam_deny.so
password required    pam_deny.so
EOF

```

#### Util-Linux(再次编译)
```sh
tar xvf ${DOWNLOADDIR}/util-linux-2.38.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/util-linux-2.38.1
	cp ${SYSDIR}/sysroot/usr/share/automake-1.16/config.* config/
	./configure  --build=${CROSS_HOST} --host=${CROSS_TARGET} \
        ADJTIME_PATH=/var/lib/hwclock/adjtime \
        --libdir=/usr/lib64 \
        --disable-chfn-chsh --disable-login --disable-nologin \
        --disable-su --disable-setpriv --disable-runuser \
        --disable-pylibmount --disable-static --without-python \
        --disable-makeinstall-chown \
        runstatedir=/run
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
	rm -v ${SYSDIR}/sysroot/usr/lib64/lib{blkid,fdisk,mount,smartcols,uuid}.la
popd
```

#### D-Bus(再次编译)
```sh
tar xvf ${DOWNLOADDIR}/dbus-1.15.4.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/dbus-1.15.4
	./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
	            --host=${CROSS_TARGET} --sysconfdir=/etc --localstatedir=/var --runstatedir=/run \
	            --enable-user-session \
	            --disable-static --disable-doxygen-docs --disable-xml-docs \
	            --with-console-auth-dir=/run/console \
	            --with-system-socket=/run/dbus/system_bus_socket
	make ${JOBS}
	make DESTDIR=${SYSDIR}/sysroot install
	rm -v ${SYSDIR}/sysroot/usr/lib64/libdbus-1.la
    chmod -v 4750 ${SYSDIR}/sysroot/usr/libexec/dbus-daemon-launch-helper
popd
```

#### DBus-Broker
https://github.com/bus1/dbus-broker/releases/download/v33/dbus-broker-33.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/dbus-broker-33.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/dbus-broker-33
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

#### Lua

```sh
tar xvf ${DOWNLOADDIR}/lua-5.4.4.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/lua-5.4.4
    patch -Np1 -i ${DOWNLOADDIR}/lua-5.4.4-shared_library-1.patch
    sed -i '/#define LUA_ROOT/s:/usr/local/:/usr/:' src/luaconf.h
    make CC=${CROSS_TARGET}-gcc MYCFLAGS="-fPIC" linux ${JOBS}
    make TO_LIB="liblua.so liblua.so.5.4 liblua.so.5.4.4" \
         INSTALL_TOP=${SYSDIR}/sysroot/usr \
         INSTALL_LIB=${SYSDIR}/sysroot/usr/lib64 \
         INSTALL_MAN=${SYSDIR}/sysroot/usr/share/man/man1 install
    ln -sf liblua.so.5.4.4 ${SYSDIR}/sysroot/usr/lib64/liblua.so.5.4
    ln -sf liblua.so.5.4 ${SYSDIR}/sysroot/usr/lib64/liblua.so
popd

cat > ${SYSDIR}/sysroot/usr/lib64/pkgconfig/lua.pc << "EOF"
prefix=/usr
exec_prefix=${prefix}
libdir=${exec_prefix}/lib64
includedir=${prefix}/include/lua

Name: Lua
Description: An Extensible Extension Language
Version: ${R}
Requires:
Libs: -L${libdir} -llua -lm -ldl
Cflags: -I${includedir}
EOF
```

#### IBus
https://github.com/ibus/ibus/releases/download/1.5.28/ibus-1.5.28.tar.gz
https://www.unicode.org/Public/zipped/15.0.0/UCD.zip
https://www.unicode.org/Public/UCD/latest/ucd/emoji/emoji-data.txt
https://www.unicode.org/Public/UCD/latest/ucd/emoji/emoji-variation-sequences.txt
https://www.unicode.org/Public/emoji/latest/emoji-sequences.txt
https://www.unicode.org/Public/emoji/latest/emoji-zwj-sequences.txt
https://www.unicode.org/Public/emoji/latest/emoji-test.txt

```sh
tar xvf ${DOWNLOADDIR}/ibus-1.5.28.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/ibus-1.5.28
    mkdir -pv ${SYSDIR}/sysroot/usr/share/unicode/ucd
    unzip -uo ${DOWNLOADDIR}/UCD.zip -d ${SYSDIR}/sysroot/usr/share/unicode/ucd
    mkdir -pv ${SYSDIR}/sysroot/usr/share/unicode/emoji
    cp -av ${DOWNLOADDIR}/emoji-*.txt ${SYSDIR}/sysroot/usr/share/unicode/emoji
    sed -i 's@/desktop/ibus@/org/freedesktop/ibus@g' \
           data/dconf/org.freedesktop.ibus.gschema.xml
    patch -Np1 -i ${DOWNLOADDIR}/0001-ibus-1.5.28-change-for-cross-compiler.patch
    autoreconf -ifv
    cp ${SYSDIR}/cross-tools/share/automake-1.16/config.* ./
    mkdir cross-prebuild
    pushd cross-prebuild
        ../configure --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                     --prefix=/usr --libdir=/usr/lib64 --sysconfdir=/etc \
                     --disable-emoji-dict --disable-unicode-dict --enable-introspection=no
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install-exec
    popd
    mkdir cross-build
    pushd cross-build
        ../configure --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                     --prefix=/usr --libdir=/usr/lib64 --sysconfdir=/etc \
                     --disable-emoji-dict --disable-unicode-dict \
                     --enable-xim --enable-gtk4 --enable-wayland \
                     --disable-python2 --with-python=${SYSDIR}/cross-tools/bin/python3
        sed -i "/pyoverridesdir/s@${SYSDIR}/cross-tools@/usr@g" bindings/pygobject/Makefile
        make INTROSPECTION_SCANNER=${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-g-ir-scanner \
             INTROSPECTION_COMPILER=${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-g-ir-compiler \
             VAPIGEN=${CROSS_TARGET}-vapigen ${JOBS}
        make VAPIGEN=${CROSS_TARGET}-vapigen DESTDIR=${SYSDIR}/sysroot install
    popd
popd
rm -v ${SYSDIR}/sysroot/usr/lib64/libibus*.la

cat > ${SYSDIR}/sysroot/etc/xdg/autostart/ibus.desktoop << "EOF"
[Desktop Entry]
Exec=/usr/bin/ibus-daemon --xim
Type=Application
Terminal=false
X-KDE-autostart-after=panel
X-KDE-StartupNotify=false
X-DBUS-StartupType=Unique
Name=IBus
EOF
```

#### Pyzy
https://code.google.com/archive/p/pyzy/downloads
https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/pyzy/pyzy-0.1.0.tar.gz
https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/pyzy/pyzy-database-1.0.0.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/pyzy-0.1.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/pyzy-0.1.0
    cp ${DOWNLOADDIR}/pyzy-database-1.0.0.tar.bz2 data/db/open-phrase
    ./configure $COMMON_CONFIG --enable-db-open-phrase --disable-db-android
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
rm -v ${SYSDIR}/sysroot/usr/lib64/libpyzy*.la
```

#### IBus-Pinyin
https://code.google.com/archive/p/ibus/downloads
https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/ibus/ibus-pinyin-1.5.0.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/ibus-pinyin-1.5.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/ibus-pinyin-1.5.0
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Dmidecode
http://download.savannah.gnu.org/releases/dmidecode/dmidecode-3.5.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/dmidecode-3.5.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/dmidecode-3.5
    make CC=${CROSS_TARGET}-gcc prefix=/usr ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot CC=${CROSS_TARGET}-gcc prefix=/usr install
popd
```

#### Rust-Cbindgen
https://github.com/eqrion/cbindgen/archive/v0.24.3/cbindgen-0.24.3.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/cbindgen-0.24.3.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/cbindgen-0.24.3
    cargo build --release
    install -Dm755 target/release/cbindgen ${SYSDIR}/cross-tools/bin/
popd
```

#### RipGrep
https://github.com/BurntSushi/ripgrep/archive/13.0.0/ripgrep-13.0.0.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/ripgrep-13.0.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/ripgrep-13.0.0
    RUSTFLAGS="$RUSTFLAGS -C linker=${CROSS_TARGET}-gcc" \
    cargo build --release --target ${CROSS_TARGET}
    install -Dm755 target/${CROSS_TARGET}/release/rg ${SYSDIR}/sysroot/usr/bin/
popd
```

#### A52dec
https://liba52.sourceforge.io/files/a52dec-0.7.4.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/a52dec-0.7.4.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/a52dec-0.7.4
    ./configure $COMMON_CONFIG --mandir=/usr/share/man CFLAGS="-fPIC"
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Taglib
https://taglib.org/releases/taglib-1.13.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/taglib-1.13.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/taglib-1.13
    mkdir cross-build
    pushd cross-build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
              -DPKG_CONFIG_EXECUTABLE=${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-pkg-config \
              -DCMAKE_SYSROOT=${SYSDIR}/sysroot \
              -DCMAKE_FIND_ROOT_PATH=${SYSDIR}/sysroot/usr \
              -DCMAKE_INSTALL_PREFIX=/usr -DLIB_SUFFIX=64 \
              -DBUILD_SHARED_LIBS=ON ..
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
popd
```

#### LMDB
https://github.com/LMDB/lmdb/archive/LMDB_0.9.29.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/LMDB_0.9.29.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/lmdb-LMDB_0.9.29
    pushd libraries/liblmdb
        make CC=${CROSS_TARGET}-gcc prefix=/usr libdir=/usr/lib64 ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot prefix=/usr libdir=/usr/lib64 install
    popd
popd
```

#### Qrencode
https://fukuchi.org/works/qrencode/qrencode-4.1.1.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/qrencode-4.1.1.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/qrencode-4.1.1
    ./configure $COMMON_CONFIG 
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Libical
https://github.com/libical/libical/releases/download/v3.0.16/libical-3.0.16.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/libical-3.0.16.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libical-3.0.16
    sed -i "s@COMMAND \${ical-glib-src-generator_EXE}@COMMAND qemu-loongarch64 ../../bin/ical-glib-src-generator@g" \
           src/libical-glib/CMakeLists.txt
    mkdir cross-prebuild
    pushd cross-prebuild
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
              -DCMAKE_INSTALL_PREFIX=/usr \
              -DSHARED_ONLY=yes -DICAL_BUILD_DOCS=false \
              -DGOBJECT_INTROSPECTION=false \
              -DICAL_GLIB_VAPI=false ..  
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
    mkdir cross-build
    pushd cross-build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
              -DCMAKE_INSTALL_PREFIX=/usr \
              -DSHARED_ONLY=yes -DICAL_BUILD_DOCS=false \
              -DGObjectIntrospection_SCANNER=${CROSS_TARGET}-g-ir-scanner \
              -DGObjectIntrospection_COMPILER=${CROSS_TARGET}-g-ir-compiler \
              -DGOBJECT_INTROSPECTION=true \
              -DICAL_GLIB_VAPI=true ..
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
popd
```

#### XXHash
https://github.com/Cyan4973/xxHash/archive/v0.8.1/xxHash-0.8.1.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/xxHash-0.8.1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/xxHash-0.8.1
    make CC=${CROSS_TARGET}-gcc PREFIX=/usr LIBDIR=/usr/lib64 ${JOBS}
    make CC=${CROSS_TARGET}-gcc PREFIX=/usr LIBDIR=/usr/lib64 DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Rsync
https://www.samba.org/ftp/rsync/src/rsync-3.2.7.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/rsync-3.2.7.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/rsync-3.2.7
    cp ${SYSDIR}/cross-tools/share/automake-*/config.* ./
    ./configure $COMMON_CONFIG --disable-simd
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Cscope
https://sourceforge.net/projects/cscope/files/cscope-15.9.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/cscope-15.9.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/cscope-15.9
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Lit
https://files.pythonhosted.org/packages/90/d8/acc8162b58aa44e899f6d4a4607650290624db71564e9b168716900510af/lit-16.0.0.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/lit-16.0.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/lit-16.0.0
    ${SYSDIR}/cross-tools/bin/python3 setup.py build
    ${SYSDIR}/cross-tools/bin/python3 setup.py install --root=${SYSDIR}/sysroot --prefix=/usr
    sed -i "s@${SYSDIR}/cross-tools@@g" ${SYSDIR}/sysroot/bin/lit
popd
```

#### Libarchive
https://github.com/libarchive/libarchive/releases/download/v3.6.2/libarchive-3.6.2.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libarchive-3.6.2.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libarchive-3.6.2
    sed -i "/linux\/fs.h/d" libarchive/archive_read_disk_posix.c
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Mlt
https://github.com/mltframework/mlt/releases/download/v7.14.0/mlt-7.14.0.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/mlt-7.14.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/mlt-7.14.0
    mkdir cross-build
    pushd cross-build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
              -DPKG_CONFIG_EXECUTABLE=${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-pkg-config \
              -DCMAKE_SYSROOT=${SYSDIR}/sysroot \
              -DCMAKE_FIND_ROOT_PATH=${SYSDIR}/sysroot/usr \
              -DCMAKE_INSTALL_PREFIX=/usr \
              -DBUILD_TESTING=OFF -Wno-dev ..
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
popd
```

#### Xapian-Core
https://oligarchy.co.uk/xapian/1.4.22/xapian-core-1.4.22.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/xapian-core-1.4.22.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/xapian-core-1.4.22
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Libssh2
https://www.libssh2.org/download/libssh2-1.10.0.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/libssh2-1.10.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libssh2-1.10.0
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Exiv2
https://github.com/Exiv2/exiv2/releases/download/v0.27.6/exiv2-0.27.6-Source.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/exiv2-0.27.6-Source.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/exiv2-0.27.6-Source
    mkdir cross-build
    pushd cross-build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
              -DPKG_CONFIG_EXECUTABLE=${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-pkg-config \
              -DCMAKE_SYSROOT=${SYSDIR}/sysroot \
              -DCMAKE_FIND_ROOT_PATH=${SYSDIR}/sysroot/usr \
              -DCMAKE_INSTALL_PREFIX=/usr \
              -DGETTEXT_MSGFMT_EXECUTABLE=/bin/msgfmt \
              -DGETTEXT_MSGMERGE_EXECUTABLE=/bin/msgmerge \
              -DEXIV2_ENABLE_VIDEO=yes -DEXIV2_ENABLE_WEBREADY=yes \
              -DEXIV2_ENABLE_CURL=yes -DEXIV2_BUILD_SAMPLES=no -DEXIV2_ENABLE_NLS=yes \
              ..
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
popd
```

#### Lm-Sensors
https://github.com/lm-sensors/lm-sensors/archive/V3-6-0/lm-sensors-3-6-0.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/lm-sensors-3-6-0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/lm-sensors-3-6-0
    make CC=${CROSS_TARGET}-gcc PREFIX=/usr LIBDIR=/usr/lib64 MANDIR=/usr/share/man ${JOBS}
    make CC=${CROSS_TARGET}-gcc PREFIX=/usr LIBDIR=/usr/lib64 MANDIR=/usr/share/man \
         DESTDIR=${SYSDIR}/sysroot install
popd
```

在内核的配置选项中将以下选项选上：

```sh
Bus options (PCI etc.)  --->
  [*] PCI support                         [CONFIG_PCI]

[*] Enable loadable module support  --->  [CONFIG_MODULES]

Device Drivers  --->
  I2C support --->
    <*/M> I2C device interface            [CONFIG_I2C_CHARDEV]
    I2C Hardware Bus support  --->
      <M> (configure all of them as modules)
  <*/M> Hardware Monitoring support  ---> [CONFIG_HWMON]
    <M> (configure all of them as modules)
```


#### Libqalculate
https://github.com/Qalculate/libqalculate/releases/download/v4.6.0/libqalculate-4.6.0.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/libqalculate-4.6.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libqalculate-4.6.0
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Libcanberra
http://0pointer.de/lennart/projects/libcanberra/libcanberra-0.30.tar.xz
https://www.linuxfromscratch.org/patches/blfs/svn/libcanberra-0.30-wayland-1.patch

```sh
tar xvf ${DOWNLOADDIR}/libcanberra-0.30.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libcanberra-0.30
    patch -Np1 -i ${DOWNLOADDIR}/libcanberra-0.30-wayland-1.patch
    ./configure $COMMON_CONFIG --disable-oss
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Libnma
https://download.gnome.org/sources/libnma/1.10/libnma-1.10.6.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libnma-1.10.6.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libnma-1.10.6
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              -Dgtk_doc=false -Dlibnma_gtk4=true -Dmobile_broadband_provider_info=false \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        sed -i -e "s@\(${SYSDIR}/\)sysroot/usr\(.*\)\(g-ir-compiler\|g-ir-scanner\)@\1cross-tools\2${CROSS_TARGET}-\3@g" build.ninja
        sed -i -e "s@\(${SYSDIR}/\)cross-tools/bin/vapigen@\1cross-tools/bin/${CROSS_TARGET}-vapigen@g" build.ninja
        CC=${CROSS_TARGET}-gcc ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Network-Manager-Applet
https://download.gnome.org/sources/network-manager-applet/1.30/network-manager-applet-1.30.0.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/network-manager-applet-1.30.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/network-manager-applet-1.30.0
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              -Dappindicator=no -Dselinux=false \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Lxml
https://files.pythonhosted.org/packages/source/l/lxml/lxml-4.9.2.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/lxml-4.9.2.tar.gz -C ${BUILDDIR}
cp -a ${BUILDDIR}/lxml-4.9.2{,.native}
pushd ${BUILDDIR}/lxml-4.9.2.native
    PKG_CONFIG="" PKG_CONFIG_PATH="" \
    LDFLAGS="" PKG_CONFIG_SYSROOT_DIR="" ${SYSDIR}/cross-tools/bin/python3 setup.py build
    PKG_CONFIG="" PKG_CONFIG_PATH="" \
    LDFLAGS="" PKG_CONFIG_SYSROOT_DIR="" ${SYSDIR}/cross-tools/bin/python3 setup.py install --optimize=1
popd
pushd ${BUILDDIR}/lxml-4.9.2
    _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_${CROSS_TARGET} \
    ${SYSDIR}/cross-tools/bin/python3 setup.py build
    _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_${CROSS_TARGET} \
    ${SYSDIR}/cross-tools/bin/python3 setup.py install --optimize=1 --root=${SYSDIR}/sysroot --prefix=/usr
popd
```

#### Sphinx
https://github.com/sphinx-doc/sphinx/archive/v5.1.1/sphinx-5.1.1.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/sphinx-5.1.1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/sphinx-5.1.1
    _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_${CROSS_TARGET} \
    ${SYSDIR}/cross-tools/bin/python3 setup.py build
    _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_${CROSS_TARGET} \
    ${SYSDIR}/cross-tools/bin/python3 setup.py install --optimize=1 --root=${SYSDIR}/sysroot --prefix=/usr
popd
```

#### Docutils
https://downloads.sourceforge.net/docutils/docutils-0.19.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/docutils-0.19.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/docutils-0.19
    _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_${CROSS_TARGET} \
    ${SYSDIR}/cross-tools/bin/python3 setup.py build
    _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_${CROSS_TARGET} \
    ${SYSDIR}/cross-tools/bin/python3 setup.py install --optimize=1 --root=${SYSDIR}/sysroot --prefix=/usr
popd
```

#### Sgml-Common
https://sourceware.org/ftp/docbook-tools/new-trials/SOURCES/sgml-common-0.6.3.tgz
https://www.linuxfromscratch.org/patches/blfs/svn/sgml-common-0.6.3-manpage-1.patch

```sh
tar xvf ${DOWNLOADDIR}/sgml-common-0.6.3.tgz -C ${BUILDDIR}
pushd ${BUILDDIR}/sgml-common-0.6.3
    patch -Np1 -i ${DOWNLOADDIR}/sgml-common-0.6.3-manpage-1.patch
    autoreconf -ifv
    ./configure ${COMMON_CONFIG}
    make ${JOBS}
    make docdir=/usr/share/doc DESTDIR=${SYSDIR}/sysroot install
popd
cp -iv ${SYSDIR}/sysroot/usr/bin/install-catalog ${SYSDIR}/cross-tools/bin/
sed -i "s@ /etc@ ${SYSDIR}/sysroot/etc@g" ${SYSDIR}/cross-tools/bin/install-catalog
${SYSDIR}/cross-tools/bin/install-catalog --add ${SYSDIR}/sysroot/etc/sgml/sgml-ent.cat \
    ${SYSDIR}/sysroot/usr/share/sgml/sgml-iso-entities-8879.1986/catalog
${SYSDIR}/cross-tools/bin/install-catalog --add ${SYSDIR}/sysroot/etc/sgml/sgml-docbook.cat \
    ${SYSDIR}/sysroot/etc/sgml/sgml-ent.cat
sed -i "s@${SYSDIR}/sysroot@@g" ${SYSDIR}/sysroot/etc/sgml/*
```

#### Docbook SGML DTD
https://docbook.org/sgml/3.1/docbk31.zip
https://docbook.org/sgml/4.5/docbook-4.5.zip

```sh
mkdir -pv ${BUILDDIR}/docbook-3.1
pushd ${BUILDDIR}/docbook-3.1
    unzip ${DOWNLOADDIR}/docbk31.zip
    sed -i -e '/ISO 8879/d' \
           -e 's|DTDDECL "-//OASIS//DTD DocBook V3.1//EN"|SGMLDECL|g' \
           docbook.cat
    install -v -d -m755 ${SYSDIR}/sysroot/usr/share/sgml/docbook/sgml-dtd-3.1
    install -v docbook.cat ${SYSDIR}/sysroot/usr/share/sgml/docbook/sgml-dtd-3.1/catalog
    cp -v -af *.dtd *.mod *.dcl ${SYSDIR}/sysroot/usr/share/sgml/docbook/sgml-dtd-3.1

    install-catalog --add ${SYSDIR}/sysroot/etc/sgml/sgml-docbook-dtd-3.1.cat \
        ${SYSDIR}/sysroot/usr/share/sgml/docbook/sgml-dtd-3.1/catalog
    install-catalog --add ${SYSDIR}/sysroot/etc/sgml/sgml-docbook-dtd-3.1.cat \
        ${SYSDIR}/sysroot/etc/sgml/sgml-docbook.cat
    
    cat >> ${SYSDIR}/sysroot/usr/share/sgml/docbook/sgml-dtd-3.1/catalog << "EOF"
PUBLIC "-//Davenport//DTD DocBook V3.0//EN" "docbook.dtd"
EOF
popd

mkdir -pv ${BUILDDIR}/docbook-dtd-4.5
pushd ${BUILDDIR}/docbook-dtd-4.5
    unzip ${DOWNLOADDIR}/docbook-4.5.zip
    sed -i -e '/ISO 8879/d' \
           -e '/gml/d' docbook.cat
    install -v -d ${SYSDIR}/sysroot/usr/share/sgml/docbook/sgml-dtd-4.5
    install -v docbook.cat ${SYSDIR}/sysroot/usr/share/sgml/docbook/sgml-dtd-4.5/catalog
    cp -v -af *.dtd *.mod *.dcl ${SYSDIR}/sysroot/usr/share/sgml/docbook/sgml-dtd-4.5

    install-catalog --add ${SYSDIR}/sysroot/etc/sgml/sgml-docbook-dtd-4.5.cat \
        ${SYSDIR}/sysroot/usr/share/sgml/docbook/sgml-dtd-4.5/catalog

    install-catalog --add ${SYSDIR}/sysroot/etc/sgml/sgml-docbook-dtd-4.5.cat \
        ${SYSDIR}/sysroot/etc/sgml/sgml-docbook.cat

    cat >> ${SYSDIR}/sysroot/usr/share/sgml/docbook/sgml-dtd-4.5/catalog << "EOF"
PUBLIC "-//OASIS//DTD DocBook V4.4//EN" "docbook.dtd"
PUBLIC "-//OASIS//DTD DocBook V4.3//EN" "docbook.dtd"
PUBLIC "-//OASIS//DTD DocBook V4.2//EN" "docbook.dtd"
PUBLIC "-//OASIS//DTD DocBook V4.1//EN" "docbook.dtd"
PUBLIC "-//OASIS//DTD DocBook V4.0//EN" "docbook.dtd"
EOF
popd

sed -i "s@${SYSDIR}/sysroot@@g" ${SYSDIR}/sysroot/etc/sgml/*
```

#### Docbook Dsssl
https://downloads.sourceforge.net/docbook/docbook-dsssl-1.79.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/docbook-dsssl-1.79.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/docbook-dsssl-1.79
    install -v -m755 bin/collateindex.pl ${SYSDIR}/sysroot/usr/bin
    install -v -m644 bin/collateindex.pl.1 ${SYSDIR}/sysroot/usr/share/man/man1
    install -v -d -m755 ${SYSDIR}/sysroot/usr/share/sgml/docbook/dsssl-stylesheets-1.79
    cp -v -R * ${SYSDIR}/sysroot/usr/share/sgml/docbook/dsssl-stylesheets-1.79

    install-catalog --add ${SYSDIR}/sysroot/etc/sgml/dsssl-docbook-stylesheets.cat \
        ${SYSDIR}/sysroot/usr/share/sgml/docbook/dsssl-stylesheets-1.79/catalog
    install-catalog --add ${SYSDIR}/sysroot/etc/sgml/dsssl-docbook-stylesheets.cat \
        ${SYSDIR}/sysroot/usr/share/sgml/docbook/dsssl-stylesheets-1.79/common/catalog
    install-catalog --add /etc/sgml/sgml-docbook.cat \
        ${SYSDIR}/sysroot/etc/sgml/dsssl-docbook-stylesheets.cat
popd
sed -i "s@${SYSDIR}/sysroot@@g" ${SYSDIR}/sysroot/etc/sgml/*
```

#### Docbook XSL
https://github.com/docbook/xslt10-stylesheets/releases/download/release%2F1.79.2/docbook-xsl-1.79.2.tar.bz2
https://github.com/docbook/xslt10-stylesheets/releases/download/release%2F1.79.2/docbook-xsl-nons-1.79.2.tar.bz2
https://www.linuxfromscratch.org/patches/blfs/svn/docbook-xsl-nons-1.79.2-stack_fix-1.patch

```sh
tar xvf ${DOWNLOADDIR}/docbook-xsl-1.79.2.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/docbook-xsl-1.79.2
    install -v -m755 -d ${SYSDIR}/sysroot/usr/share/xml/docbook/xsl-stylesheets
    cp -v -R VERSION assembly common eclipse epub epub3 extensions fo \
         highlighting html htmlhelp images javahelp lib manpages params \
         profiling roundtrip slides template tests tools webhelp website \
         xhtml xhtml-1_1 xhtml5 \
         ${SYSDIR}/sysroot/usr/share/xml/docbook/xsl-stylesheets

    ln -s VERSION ${SYSDIR}/sysroot/usr/share/xml/docbook/xsl-stylesheets/VERSION.xsl
    install -v -m644 -D README \
                    ${SYSDIR}/sysroot/usr/share/doc/docbook-xsl/README.txt
    install -v -m644    RELEASE-NOTES* NEWS* \
                    ${SYSDIR}/sysroot/usr/share/doc/docbook-xsl
popd
ln -sv ../../xml/docbook/xsl-stylesheets ${SYSDIR}/sysroot/usr/share/sgml/docbook/

tar xvf ${DOWNLOADDIR}/docbook-xsl-nons-1.79.2.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/docbook-xsl-nons-1.79.2
    patch -Np1 -i ${DOWNLOADDIR}/docbook-xsl-nons-1.79.2-stack_fix-1.patch
    install -v -m755 -d ${SYSDIR}/sysroot/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2
    cp -v -R VERSION assembly common eclipse epub epub3 extensions fo \
         highlighting html htmlhelp images javahelp lib manpages params \
         profiling roundtrip slides template tests tools webhelp website \
         xhtml xhtml-1_1 xhtml5 \
         ${SYSDIR}/sysroot/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2

    ln -s VERSION ${SYSDIR}/sysroot/usr/share/xml/docbook/xsl-stylesheets-nons-1.79.2/VERSION.xsl
    install -v -m644 -D README \
                    ${SYSDIR}/sysroot/usr/share/doc/docbook-xsl-nons-1.79.2/README.txt
    install -v -m644    RELEASE-NOTES* NEWS* \
                    ${SYSDIR}/sysroot/usr/share/doc/docbook-xsl-nons-1.79.2
popd
```

#### Docbook XML
https://docbook.org/xml/4.5/docbook-xml-4.5.zip
https://docbook.org/xml/5.0.1/docbook-5.0.1.zip
https://docbook.org/xml/5.1/docbook-v5.1-os.zip

```sh
install -v -d -m755 ${SYSDIR}/sysroot/etc/xml

mkdir -pv ${BUILDDIR}/docbook-xml-4.5
pushd ${BUILDDIR}/docbook-xml-4.5
    unzip ${DOWNLOADDIR}/docbook-xml-4.5.zip
    install -v -d -m755 ${SYSDIR}/sysroot/usr/share/xml/docbook/xml-dtd-4.5
    cp -v -af docbook.cat *.dtd ent/ *.mod \
         ${SYSDIR}/sysroot/usr/share/xml/docbook/xml-dtd-4.5
    if [ ! -e ${SYSDIR}/sysroot/etc/xml/docbook ]; then
        xmlcatalog --noout --create ${SYSDIR}/sysroot/etc/xml/docbook
    fi
    xmlcatalog --noout --add "public" \
        "-//OASIS//DTD DocBook XML V4.5//EN" \
        "http://www.oasis-open.org/docbook/xml/4.5/docbookx.dtd" \
        ${SYSDIR}/sysroot/etc/xml/docbook
    xmlcatalog --noout --add "public" \
        "-//OASIS//DTD DocBook XML CALS Table Model V4.5//EN" \
        "file:///usr/share/xml/docbook/xml-dtd-4.5/calstblx.dtd" \
        ${SYSDIR}/sysroot/etc/xml/docbook
    xmlcatalog --noout --add "public" \
        "-//OASIS//DTD XML Exchange Table Model 19990315//EN" \
        "file:///usr/share/xml/docbook/xml-dtd-4.5/soextblx.dtd" \
        ${SYSDIR}/sysroot/etc/xml/docbook
    xmlcatalog --noout --add "public" \
        "-//OASIS//ELEMENTS DocBook XML Information Pool V4.5//EN" \
        "file:///usr/share/xml/docbook/xml-dtd-4.5/dbpoolx.mod" \
        ${SYSDIR}/sysroot/etc/xml/docbook
    xmlcatalog --noout --add "public" \
        "-//OASIS//ELEMENTS DocBook XML Document Hierarchy V4.5//EN" \
        "file:///usr/share/xml/docbook/xml-dtd-4.5/dbhierx.mod" \
        ${SYSDIR}/sysroot/etc/xml/docbook
    xmlcatalog --noout --add "public" \
        "-//OASIS//ELEMENTS DocBook XML HTML Tables V4.5//EN" \
        "file:///usr/share/xml/docbook/xml-dtd-4.5/htmltblx.mod" \
        ${SYSDIR}/sysroot/etc/xml/docbook
    xmlcatalog --noout --add "public" \
        "-//OASIS//ENTITIES DocBook XML Notations V4.5//EN" \
        "file:///usr/share/xml/docbook/xml-dtd-4.5/dbnotnx.mod" \
        ${SYSDIR}/sysroot/etc/xml/docbook
    xmlcatalog --noout --add "public" \
        "-//OASIS//ENTITIES DocBook XML Character Entities V4.5//EN" \
        "file:///usr/share/xml/docbook/xml-dtd-4.5/dbcentx.mod" \
        ${SYSDIR}/sysroot/etc/xml/docbook
    xmlcatalog --noout --add "public" \
        "-//OASIS//ENTITIES DocBook XML Additional General Entities V4.5//EN" \
        "file:///usr/share/xml/docbook/xml-dtd-4.5/dbgenent.mod" \
        ${SYSDIR}/sysroot/etc/xml/docbook
    xmlcatalog --noout --add "rewriteSystem" \
        "http://www.oasis-open.org/docbook/xml/4.5" \
        "file:///usr/share/xml/docbook/xml-dtd-4.5" \
        ${SYSDIR}/sysroot/etc/xml/docbook
    xmlcatalog --noout --add "rewriteURI" \
        "http://www.oasis-open.org/docbook/xml/4.5" \
        "file:///usr/share/xml/docbook/xml-dtd-4.5" \
        ${SYSDIR}/sysroot/etc/xml/docbook

    if [ ! -e ${SYSDIR}/sysroot/etc/xml/catalog ]; then
        xmlcatalog --noout --create ${SYSDIR}/sysroot/etc/xml/catalog
    fi
    xmlcatalog --noout --add "delegatePublic" \
        "-//OASIS//ENTITIES DocBook XML" \
        "file:///etc/xml/docbook" \
        ${SYSDIR}/sysroot/etc/xml/catalog &&
    xmlcatalog --noout --add "delegatePublic" \
        "-//OASIS//DTD DocBook XML" \
        "file:///etc/xml/docbook" \
        ${SYSDIR}/sysroot/etc/xml/catalog &&
    xmlcatalog --noout --add "delegateSystem" \
        "http://www.oasis-open.org/docbook/" \
        "file:///etc/xml/docbook" \
        ${SYSDIR}/sysroot/etc/xml/catalog &&
    xmlcatalog --noout --add "delegateURI" \
        "http://www.oasis-open.org/docbook/" \
        "file:///etc/xml/docbook" \
        ${SYSDIR}/sysroot/etc/xml/catalog

    for DTDVERSION in 4.1.2 4.2 4.3 4.4
    do
        xmlcatalog --noout --add "public" \
            "-//OASIS//DTD DocBook XML V$DTDVERSION//EN" \
            "http://www.oasis-open.org/docbook/xml/$DTDVERSION/docbookx.dtd" \
            ${SYSDIR}/sysroot/etc/xml/docbook
        xmlcatalog --noout --add "rewriteSystem" \
            "http://www.oasis-open.org/docbook/xml/$DTDVERSION" \
            "file:///usr/share/xml/docbook/xml-dtd-4.5" \
            ${SYSDIR}/sysroot/etc/xml/docbook
        xmlcatalog --noout --add "rewriteURI" \
            "http://www.oasis-open.org/docbook/xml/$DTDVERSION" \
            "file:///usr/share/xml/docbook/xml-dtd-4.5" \
            ${SYSDIR}/sysroot/etc/xml/docbook
        xmlcatalog --noout --add "delegateSystem" \
            "http://www.oasis-open.org/docbook/xml/$DTDVERSION/" \
            "file:///etc/xml/docbook" \
            ${SYSDIR}/sysroot/etc/xml/catalog
        xmlcatalog --noout --add "delegateURI" \
            "http://www.oasis-open.org/docbook/xml/$DTDVERSION/" \
            "file:///etc/xml/docbook" \
            ${SYSDIR}/sysroot/etc/xml/catalog
    done
popd    
ln -sv ../../xml/docbook/xml-dtd-4.5 ${SYSDIR}/sysroot/usr/share/sgml/docbook/

pushd ${BUILDDIR}
unzip ${DOWNLOADDIR}/docbook-5.0.1.zip
pushd ${BUILDDIR}/docbook-5.0.1
    install -vdm755 ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/{dtd,rng,sch,xsd}/5.0
    install -vm644  dtd/* ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/dtd/5.0
    install -vm644  rng/* ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/rng/5.0
    install -vm644  sch/* ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/sch/5.0
    install -vm644  xsd/* ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/xsd/5.0

    if [ ! -e ${SYSDIR}/sysroot/etc/xml/docbook-5.0 ]; then
        xmlcatalog --noout --create ${SYSDIR}/sysroot/etc/xml/docbook-5.0
    fi

    xmlcatalog --noout --add "public" \
        "-//OASIS//DTD DocBook XML 5.0//EN" \
        "file:///usr/share/xml/docbook/schema/dtd/5.0/docbook.dtd" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.0
    xmlcatalog --noout --add "system" \
        "http://www.oasis-open.org/docbook/xml/5.0/dtd/docbook.dtd" \
        "file:///usr/share/xml/docbook/schema/dtd/5.0/docbook.dtd" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.0
    xmlcatalog --noout --add "system" \
        "http://docbook.org/xml/5.0/dtd/docbook.dtd" \
        "file:///usr/share/xml/docbook/schema/dtd/5.0/docbook.dtd" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.0

    xmlcatalog --noout --add "uri" \
        "http://www.oasis-open.org/docbook/xml/5.0/rng/docbook.rng" \
        "file:///usr/share/xml/docbook/schema/rng/5.0/docbook.rng" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.0
    xmlcatalog --noout --add "uri" \
        "http://docbook.org/xml/5.0/rng/docbook.rng" \
        "file:///usr/share/xml/docbook/schema/rng/5.0/docbook.rng" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.0
    xmlcatalog --noout --add "uri" \
        "http://www.oasis-open.org/docbook/xml/5.0/rng/docbookxi.rng" \
        "file:///usr/share/xml/docbook/schema/rng/5.0/docbookxi.rng" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.0
    xmlcatalog --noout --add "uri" \
        "http://docbook.org/xml/5.0/rng/docbookxi.rng" \
        "file:///usr/share/xml/docbook/schema/rng/5.0/docbookxi.rng" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.0
    xmlcatalog --noout --add "uri" \
        "http://www.oasis-open.org/docbook/xml/5.0/rnc/docbook.rnc" \
        "file:///usr/share/xml/docbook/schema/rng/5.0/docbook.rnc" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.0
    xmlcatalog --noout --add "uri" \
        "http://docbook.org/xml/5.0/rng/docbook.rnc" \
        "file:///usr/share/xml/docbook/schema/rng/5.0/docbook.rnc" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.0
    xmlcatalog --noout --add "uri" \
        "http://www.oasis-open.org/docbook/xml/5.0/rnc/docbookxi.rnc" \
        "file:///usr/share/xml/docbook/schema/rng/5.0/docbookxi.rnc" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.0
    xmlcatalog --noout --add "uri" \
        "http://docbook.org/xml/5.0/rng/docbookxi.rnc" \
        "file:///usr/share/xml/docbook/schema/rng/5.0/docbookxi.rnc" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.0

    xmlcatalog --noout --add "uri" \
        "http://www.oasis-open.org/docbook/xml/5.0/xsd/docbook.xsd" \
        "file:///usr/share/xml/docbook/schema/xsd/5.0/docbook.xsd" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.0
    xmlcatalog --noout --add "uri" \
        "http://docbook.org/xml/5.0/xsd/docbook.xsd" \
        "file:///usr/share/xml/docbook/schema/xsd/5.0/docbook.xsd" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.0
    xmlcatalog --noout --add "uri" \
        "http://www.oasis-open.org/docbook/xml/5.0/xsd/docbookxi.xsd" \
        "file:///usr/share/xml/docbook/schema/xsd/5.0/docbookxi.xsd" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.0
    xmlcatalog --noout --add "uri" \
        "http://docbook.org/xml/5.0/xsd/docbookxi.xsd" \
        "file:///usr/share/xml/docbook/schema/xsd/5.0/docbookxi.xsd" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.0
    xmlcatalog --noout --add "uri" \
        "http://www.oasis-open.org/docbook/xml/5.0/xsd/xi.xsd" \
        "file:///usr/share/xml/docbook/schema/xsd/5.0/xi.xsd" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.0
    xmlcatalog --noout --add "uri" \
        "http://docbook.org/xml/5.0/xsd/xi.xsd" \
        "file:///usr/share/xml/docbook/schema/xsd/5.0/xi.xsd" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.0
    xmlcatalog --noout --add "uri" \
        "http://www.oasis-open.org/docbook/xml/5.0/xsd/xlink.xsd" \
        "file:///usr/share/xml/docbook/schema/xsd/5.0/xlink.xsd" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.0
    xmlcatalog --noout --add "uri" \
        "http://docbook.org/xml/5.0/xsd/xlink.xsd" \
        "file:///usr/share/xml/docbook/schema/xsd/5.0/xlink.xsd" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.0
    xmlcatalog --noout --add "uri" \
        "http://www.oasis-open.org/docbook/xml/5.0/xsd/xml.xsd" \
        "file:///usr/share/xml/docbook/schema/xsd/5.0/xml.xsd" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.0
    xmlcatalog --noout --add "uri" \
        "http://docbook.org/xml/5.0/xsd/xml.xsd" \
        "file:///usr/share/xml/docbook/schema/xsd/5.0/xml.xsd" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.0

    xmlcatalog --noout --add "uri" \
        "http://www.oasis-open.org/docbook/xml/5.0/sch/docbook.sch" \
        "file:///usr/share/xml/docbook/schema/sch/5.0/docbook.sch" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.0
    xmlcatalog --noout --add "uri" \
        "http://docbook.org/xml/5.0/sch/docbook.sch" \
        "file:///usr/share/xml/docbook/schema/sch/5.0/docbook.sch" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.0

    xmlcatalog --noout --create ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/dtd/5.0/catalog.xml
    xmlcatalog --noout --add "public" \
        "-//OASIS//DTD DocBook XML 5.0//EN" \
        "docbook.dtd" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/dtd/5.0/catalog.xml
    xmlcatalog --noout --add "system" \
        "http://www.oasis-open.org/docbook/xml/5.0/dtd/docbook.dtd" \
        "docbook.dtd" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/dtd/5.0/catalog.xml

    xmlcatalog --noout --create ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/rng/5.0/catalog.xml
    xmlcatalog --noout --add "uri" \
        "http://docbook.org/xml/5.0/rng/docbook.rng" \
        "docbook.rng" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/rng/5.0/catalog.xml
    xmlcatalog --noout --add "uri" \
        "http://www.oasis-open.org/docbook/xml/5.0/rng/docbook.rng" \
        "docbook.rng" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/rng/5.0/catalog.xml
    xmlcatalog --noout --add "uri" \
        "http://docbook.org/xml/5.0/rng/docbookxi.rng" \
        "docbookxi.rng" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/rng/5.0/catalog.xml
    xmlcatalog --noout --add "uri" \
        "http://www.oasis-open.org/docbook/xml/5.0/rng/docbookxi.rng" \
        "docbookxi.rng" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/rng/5.0/catalog.xml
    xmlcatalog --noout --add "uri" \
        "http://docbook.org/xml/5.0/rng/docbook.rnc" \
        "docbook.rnc" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/rng/5.0/catalog.xml
    xmlcatalog --noout --add "uri" \
        "http://www.oasis-open.org/docbook/xml/5.0/rng/docbook.rnc" \
        "docbook.rnc" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/rng/5.0/catalog.xml
    xmlcatalog --noout --add "uri" \
        "http://docbook.org/xml/5.0/rng/docbookxi.rnc" \
        "docbookxi.rnc" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/rng/5.0/catalog.xml
    xmlcatalog --noout --add "uri" \
        "http://www.oasis-open.org/docbook/xml/5.0/rng/docbookxi.rnc" \
        "docbookxi.rnc" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/rng/5.0/catalog.xml

    xmlcatalog --noout --create ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/sch/5.0/catalog.xml
    xmlcatalog --noout --add "uri" \
        "http://docbook.org/xml/5.0/sch/docbook.sch" \
        "docbook.sch" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/sch/5.0/catalog.xml
    xmlcatalog --noout --add "uri" \
        "http://www.oasis-open.org/docbook/xml/5.0/sch/docbook.sch" \
        "docbook.sch" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/sch/5.0/catalog.xml

    xmlcatalog --noout --create ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/xsd/5.0/catalog.xml
    xmlcatalog --noout --add "uri" \
        "http://docbook.org/xml/5.0/xsd/docbook.xsd" \
        "docbook.xsd" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/xsd/5.0/catalog.xml
    xmlcatalog --noout --add "uri" \
        "http://www.oasis-open.org/docbook/xml/5.0/xsd/docbook.xsd" \
        "docbook.xsd" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/xsd/5.0/catalog.xml
    xmlcatalog --noout --add "uri" \
        "http://docbook.org/xml/5.0/xsd/docbookxi.xsd" \
        "docbookxi.xsd" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/xsd/5.0/catalog.xml
    xmlcatalog --noout --add "uri" \
        "http://www.oasis-open.org/docbook/xml/5.0/xsd/docbookxi.xsd" \
        "docbookxi.xsd" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/xsd/5.0/catalog.xml
    xmlcatalog --noout --add "uri" \
        "http://docbook.org/xml/5.0/xsd/xlink.xsd" \
        "xlink.xsd" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/xsd/5.0/catalog.xml
    xmlcatalog --noout --add "uri" \
        "http://www.oasis-open.org/docbook/xml/5.0/xsd/xlink.xsd" \
        "xlink.xsd" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/xsd/5.0/catalog.xml
    xmlcatalog --noout --add "uri" \
        "http://docbook.org/xml/5.0/xsd/xml.xsd" \
        "xml.xsd" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/xsd/5.0/catalog.xml
    xmlcatalog --noout --add "uri" \
        "http://www.oasis-open.org/docbook/xml/5.0/xsd/xml.xsd" \
        "xml.xsd" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/xsd/5.0/catalog.xml

    if [ ! -e ${SYSDIR}/sysroot/etc/xml/catalog ]; then
        xmlcatalog --noout --create ${SYSDIR}/sysroot/etc/xml/catalog
    fi
    xmlcatalog --noout --add "delegatePublic" \
        "-//OASIS//DTD DocBook XML 5.0//EN" \
        "file:///usr/share/xml/docbook/schema/dtd/5.0/catalog.xml" \
        ${SYSDIR}/sysroot/etc/xml/catalog
    xmlcatalog --noout --add "delegateSystem" \
        "http://docbook.org/xml/5.0/dtd/" \
        "file:///usr/share/xml/docbook/schema/dtd/5.0/catalog.xml" \
        ${SYSDIR}/sysroot/etc/xml/catalog
    xmlcatalog --noout --add "delegateURI" \
        "http://docbook.org/xml/5.0/dtd/" \
        "file:///usr/share/xml/docbook/schema/dtd/5.0/catalog.xml" \
        ${SYSDIR}/sysroot/etc/xml/catalog
    xmlcatalog --noout --add "delegateURI" \
        "http://docbook.org/xml/5.0/rng/"  \
        "file:///usr/share/xml/docbook/schema/rng/5.0/catalog.xml" \
        ${SYSDIR}/sysroot/etc/xml/catalog
    xmlcatalog --noout --add "delegateURI" \
        "http://docbook.org/xml/5.0/sch/"  \
        "file:///usr/share/xml/docbook/schema/sch/5.0/catalog.xml" \
        ${SYSDIR}/sysroot/etc/xml/catalog
    xmlcatalog --noout --add "delegateURI" \
        "http://docbook.org/xml/5.0/xsd/"  \
        "file:///usr/share/xml/docbook/schema/xsd/5.0/catalog.xml" \
        ${SYSDIR}/sysroot/etc/xml/catalog
popd
popd

mkdir -pv ${BUILDDIR}/docbook-5.1
pushd ${BUILDDIR}/docbook-5.1
    unzip ${DOWNLOADDIR}/docbook-v5.1-os.zip
    install -vdm755 ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/{rng,sch}/5.1
    install -m644   schemas/rng/* ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/rng/5.1
    install -m644   schemas/sch/* ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/sch/5.1
    install -m755   tools/db4-entities.pl ${SYSDIR}/sysroot/usr/bin
    install -vdm755 ${SYSDIR}/sysroot/usr/share/xml/docbook/stylesheet/docbook5
    install -m644   tools/db4-upgrade.xsl \
                ${SYSDIR}/sysroot/usr/share/xml/docbook/stylesheet/docbook5

    if [ ! -e ${SYSDIR}/sysroot/etc/xml/docbook-5.1 ]; then
        xmlcatalog --noout --create ${SYSDIR}/sysroot/etc/xml/docbook-5.1
    fi
    xmlcatalog --noout --add "uri" \
        "http://www.oasis-open.org/docbook/xml/5.1/rng/docbook.rng" \
        "file:///usr/share/xml/docbook/schema/rng/5.1/docbook.rng" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.1
    xmlcatalog --noout --add "uri" \
        "http://docbook.org/xml/5.1/rng/docbook.rng" \
        "file:///usr/share/xml/docbook/schema/rng/5.1/docbook.rng" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.1
    xmlcatalog --noout --add "uri" \
        "http://www.oasis-open.org/docbook/xml/5.1/rng/docbookxi.rng" \
        "file:///usr/share/xml/docbook/schema/rng/5.1/docbookxi.rng" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.1
    xmlcatalog --noout --add "uri" \
        "http://docbook.org/xml/5.1/rng/docbookxi.rng" \
        "file:///usr/share/xml/docbook/schema/rng/5.1/docbookxi.rng" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.1
    xmlcatalog --noout --add "uri" \
        "http://www.oasis-open.org/docbook/xml/5.1/rnc/docbook.rnc" \
        "file:///usr/share/xml/docbook/schema/rng/5.1/docbook.rnc" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.1
    xmlcatalog --noout --add "uri" \
        "http://docbook.org/xml/5.1/rng/docbook.rnc" \
        "file:///usr/share/xml/docbook/schema/rng/5.1/docbook.rnc" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.1
    xmlcatalog --noout --add "uri" \
        "http://www.oasis-open.org/docbook/xml/5.1/rnc/docbookxi.rnc" \
        "file:///usr/share/xml/docbook/schema/rng/5.1/docbookxi.rnc" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.1
    xmlcatalog --noout --add "uri" \
        "http://docbook.org/xml/5.1/rng/docbookxi.rnc" \
        "file:///usr/share/xml/docbook/schema/rng/5.1/docbookxi.rnc" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.1
    xmlcatalog --noout --add "uri" \
        "http://www.oasis-open.org/docbook/xml/5.1/sch/docbook.sch" \
        "file:///usr/share/xml/docbook/schema/sch/5.1/docbook.sch" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.1
    xmlcatalog --noout --add "uri" \
        "http://docbook.org/xml/5.1/sch/docbook.sch" \
        "file:///usr/share/xml/docbook/schema/sch/5.1/docbook.sch" \
        ${SYSDIR}/sysroot/etc/xml/docbook-5.1


    xmlcatalog --noout --create ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/rng/5.1/catalog.xml
    xmlcatalog --noout --add "uri" \
        "http://docbook.org/xml/5.1/schemas/rng/docbook.schemas/rng" \
        "docbook.schemas/rng" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/rng/5.1/catalog.xml
    xmlcatalog --noout --add "uri" \
        "http://www.oasis-open.org/docbook/xml/5.1/schemas/rng/docbook.schemas/rng" \
        "docbook.schemas/rng" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/rng/5.1/catalog.xml
    xmlcatalog --noout --add "uri" \
        "http://docbook.org/xml/5.1/schemas/rng/docbookxi.schemas/rng" \
        "docbookxi.schemas/rng" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/rng/5.1/catalog.xml
    xmlcatalog --noout --add "uri" \
        "http://www.oasis-open.org/docbook/xml/5.1/schemas/rng/docbookxi.schemas/rng" \
        "docbookxi.schemas/rng" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/rng/5.1/catalog.xml
    xmlcatalog --noout --add "uri" \
        "http://docbook.org/xml/5.1/schemas/rng/docbook.rnc" \
        "docbook.rnc" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/rng/5.1/catalog.xml
    xmlcatalog --noout --add "uri" \
        "http://www.oasis-open.org/docbook/xml/5.1/schemas/rng/docbook.rnc" \
        "docbook.rnc" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/rng/5.1/catalog.xml
    xmlcatalog --noout --add "uri" \
        "http://docbook.org/xml/5.1/schemas/rng/docbookxi.rnc" \
        "docbookxi.rnc" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/rng/5.1/catalog.xml
    xmlcatalog --noout --add "uri" \
        "http://www.oasis-open.org/docbook/xml/5.1/schemas/rng/docbookxi.rnc" \
        "docbookxi.rnc" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/rng/5.1/catalog.xml

    xmlcatalog --noout --create ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/sch/5.1/catalog.xml
    xmlcatalog --noout --add "uri" \
        "http://docbook.org/xml/5.1/schemas/sch/docbook.schemas/sch" \
        "docbook.schemas/sch" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/sch/5.1/catalog.xml
    xmlcatalog --noout --add "uri" \
        "http://www.oasis-open.org/docbook/xml/5.1/schemas/sch/docbook.schemas/sch" \
        "docbook.schemas/sch" ${SYSDIR}/sysroot/usr/share/xml/docbook/schema/sch/5.1/catalog.xml


    if [ ! -e ${SYSDIR}/sysroot/etc/xml/catalog ]; then
        xmlcatalog --noout --create ${SYSDIR}/sysroot/etc/xml/catalog
    fi
    xmlcatalog --noout --add "delegatePublic" \
        "-//OASIS//DTD DocBook XML 5.1//EN" \
        "file:///usr/share/xml/docbook/schema/dtd/5.1/catalog.xml" \
        ${SYSDIR}/sysroot/etc/xml/catalog
    xmlcatalog --noout --add "delegateSystem" \
        "http://docbook.org/xml/5.1/dtd/" \
        "file:///usr/share/xml/docbook/schema/dtd/5.1/catalog.xml" \
        ${SYSDIR}/sysroot/etc/xml/catalog
    xmlcatalog --noout --add "delegateURI" \
        "http://docbook.org/xml/5.1/dtd/" \
        "file:///usr/share/xml/docbook/schema/dtd/5.1/catalog.xml" \
        ${SYSDIR}/sysroot/etc/xml/catalog
    xmlcatalog --noout --add "delegateURI" \
        "http://docbook.org/xml/5.1/rng/"  \
        "file:///usr/share/xml/docbook/schema/rng/5.1/catalog.xml" \
        ${SYSDIR}/sysroot/etc/xml/catalog
    xmlcatalog --noout --add "delegateURI" \
        "http://docbook.org/xml/5.1/sch/"  \
        "file:///usr/share/xml/docbook/schema/sch/5.1/catalog.xml" \
        ${SYSDIR}/sysroot/etc/xml/catalog
    xmlcatalog --noout --add "delegateURI" \
        "http://docbook.org/xml/5.1/xsd/"  \
        "file:///usr/share/xml/docbook/schema/xsd/5.1/catalog.xml" \
        ${SYSDIR}/sysroot/etc/xml/catalog
popd
```

#### Itstools
http://files.itstool.org/itstool/itstool-2.0.7.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/itstool-2.0.7.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/itstool-2.0.7
    PYTHON=${SYSDIR}/cross-tools/bin/python3 ./configure ${COMMON_CONFIG}
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Xmlto
https://releases.pagure.org/xmlto/xmlto-0.0.28.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/xmlto-0.0.28.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/xmlto-0.0.28
    LINKS="/usr/bin/links" ./configure ${COMMON_CONFIG}
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Asciidoc
https://github.com/asciidoc-py/asciidoc-py/releases/download/10.2.0/asciidoc-10.2.0.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/asciidoc-10.2.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/asciidoc-10.2.0
    _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_${CROSS_TARGET} \
    ${SYSDIR}/cross-tools/bin/python3 setup.py build
    _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_${CROSS_TARGET} \
    ${SYSDIR}/cross-tools/bin/python3 setup.py install --optimize=1 --root=${SYSDIR}/sysroot --prefix=/usr
popd
```


#### Highlight
http://www.andre-simon.de/zip/highlight-4.5.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/highlight-4.5.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/highlight-4.5
    make CXX="${CROSS_TARGET}-g++" AR="${CROSS_TARGET}-ar" ${JOBS}
    make CXX="${CROSS_TARGET}-g++" AR="${CROSS_TARGET}-ar" gui ${JOBS}
    make CXX="${CROSS_TARGET}-g++" AR="${CROSS_TARGET}-ar" DESTDIR=${SYSDIR}/sysroot install
    make CXX="${CROSS_TARGET}-g++" AR="${CROSS_TARGET}-ar" DESTDIR=${SYSDIR}/sysroot install-gui
popd
```

#### LibZen
http://mediaarea.net/download/source/libzen/0.4.40/libzen_0.4.40.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/libzen_0.4.40.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/ZenLib/Project/GNU/Library
    autoreconf -ifv
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### LibMediainfo
http://mediaarea.net/download/source/libmediainfo/22.12/libmediainfo_22.12.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/libmediainfo_22.12.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/MediaInfoLib/Project/GNU/Library
    autoreconf -ifv
    ./configure $COMMON_CONFIG --enable-shared \
                --enable-visibility --with-libcurl --with-libmms
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Frei0r
https://github.com/dyne/frei0r/archive/v2.2.0/frei0r-2.2.0.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/frei0r-2.2.0.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/frei0r-2.2.0
    mkdir cross-build
    pushd cross-build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
              -DPKG_CONFIG_EXECUTABLE=${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-pkg-config \
              -DCMAKE_SYSROOT=${SYSDIR}/sysroot \
              -DCMAKE_FIND_ROOT_PATH=${SYSDIR}/sysroot/usr \
              -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=/usr/lib64 \
              -DGETTEXT_MSGFMT_EXECUTABLE=/bin/msgfmt \
              -DGETTEXT_MSGMERGE_EXECUTABLE=/bin/msgmerge \
              -DDOXYGEN_EXECUTABLE=/bin/doxygen \
              ..
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
popd
```

#### gsettings-desktop-schemas
https://download.gnome.org/sources/gsettings-desktop-schemas/44/gsettings-desktop-schemas-44.0.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/gsettings-desktop-schemas-44.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/gsettings-desktop-schemas-44.0
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        sed -i -e "s@\(${SYSDIR}/\)sysroot/usr\(.*\)\(g-ir-compiler\|g-ir-scanner\)@\1cross-tools\2${CROSS_TARGET}-\3@g" build.ninja
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Nghttp2
https://github.com/nghttp2/nghttp2/releases/download/v1.52.0/nghttp2-1.52.0.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/nghttp2-1.52.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/nghttp2-1.52.0
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Libproxy
https://github.com/libproxy/libproxy/archive/0.4.18/libproxy-0.4.18.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/libproxy-0.4.18.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libproxy-0.4.18
    mkdir cross-build
    pushd cross-build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
              -DPKG_CONFIG_EXECUTABLE=${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-pkg-config \
              -DCMAKE_SYSROOT=${SYSDIR}/sysroot \
              -DCMAKE_FIND_ROOT_PATH=${SYSDIR}/sysroot/usr \
              -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=/usr/lib64 \
              -DGETTEXT_MSGFMT_EXECUTABLE=/bin/msgfmt \
              -DGETTEXT_MSGMERGE_EXECUTABLE=/bin/msgmerge \
              -DDOXYGEN_EXECUTABLE=/bin/doxygen \
              ..
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
popd
```

#### glib-networking
https://download.gnome.org/sources/glib-networking/2.76/glib-networking-2.76.0.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/glib-networking-2.76.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/glib-networking-2.76.0
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

#### Libsoup
https://download.gnome.org/sources/libsoup/3.4/libsoup-3.4.0.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libsoup-3.4.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libsoup-3.4.0
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              -Dvapi=enabled -Dgssapi=disabled -Dsysprof=disabled -Ddocs=disabled \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        sed -i -e "s@\(${SYSDIR}/\)sysroot/usr\(.*\)\(g-ir-compiler\|g-ir-scanner\)@\1cross-tools\2${CROSS_TARGET}-\3@g" build.ninja
        CC=${CROSS_TARGET}-gcc ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Libwpe
https://wpewebkit.org/releases/libwpe-1.14.1.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/libwpe-1.14.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/libwpe-1.14.1
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        CC=${CROSS_TARGET}-gcc ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Wpebackend-Fdo
https://wpewebkit.org/releases/wpebackend-fdo-1.14.2.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/wpebackend-fdo-1.14.2.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/wpebackend-fdo-1.14.2
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        CC=${CROSS_TARGET}-gcc ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Ruby
https://cache.ruby-lang.org/pub/ruby/3.2/ruby-3.2.1.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/ruby-3.2.1.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/ruby-3.2.1
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Markdown
https://files.pythonhosted.org/packages/9d/80/cc67bfb7deb973d5ae662ee6454d2dafaa8f7c106feafd0d1572666ebde5/Markdown-3.4.3.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/Markdown-3.4.3.tar.gz -C ${BUILDDIR}
cp -a ${BUILDDIR}/Markdown-3.4.3{,.native}
pushd ${BUILDDIR}/Markdown-3.4.3.native
    PKG_CONFIG="" PKG_CONFIG_PATH="" \
    LDFLAGS="" PKG_CONFIG_SYSROOT_DIR="" ${SYSDIR}/cross-tools/bin/pip3 wheel -w dist --no-build-isolation --no-deps $PWD
    PKG_CONFIG="" PKG_CONFIG_PATH="" \
    LDFLAGS="" PKG_CONFIG_SYSROOT_DIR="" ${SYSDIR}/cross-tools/bin/pip3 install --no-index --find-links dist --no-cache-dir --force-reinstall --no-user Markdown
popd
pushd ${BUILDDIR}/Markdown-3.4.3
    _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_${CROSS_TARGET} \
    ${SYSDIR}/cross-tools/bin/pip3 wheel -w dist --no-build-isolation --no-deps $PWD
    _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_${CROSS_TARGET} \
    ${SYSDIR}/cross-tools/bin/pip3 install --no-index --find-links dist --no-cache-dir --force-reinstall --no-user Markdown --root=${SYSDIR}/sysroot --prefix=/usr
popd
```

#### Toml
https://files.pythonhosted.org/packages/be/ba/1f744cdc819428fc6b5084ec34d9b30660f6f9daaf70eead706e3203ec3c/toml-0.10.2.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/toml-0.10.2.tar.gz -C ${BUILDDIR}
cp -a ${BUILDDIR}/toml-0.10.2{,.native}
pushd ${BUILDDIR}/toml-0.10.2.native
    PKG_CONFIG="" PKG_CONFIG_PATH="" \
    LDFLAGS="" PKG_CONFIG_SYSROOT_DIR="" ${SYSDIR}/cross-tools/bin/python3 setup.py build
    PKG_CONFIG="" PKG_CONFIG_PATH="" \
    LDFLAGS="" PKG_CONFIG_SYSROOT_DIR="" ${SYSDIR}/cross-tools/bin/python3 setup.py install --optimize=1
popd
pushd ${BUILDDIR}/toml-0.10.2
    _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_${CROSS_TARGET} \
    ${SYSDIR}/cross-tools/bin/python3 setup.py build
    _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_${CROSS_TARGET} \
    ${SYSDIR}/cross-tools/bin/python3 setup.py install --optimize=1 --root=${SYSDIR}/sysroot --prefix=/usr
popd
```

#### Typogrify
https://files.pythonhosted.org/packages/8a/bf/64959d6187d42472acb846bcf462347c9124952c05bd57e5769d5f28f9a6/typogrify-2.0.7.tar.gz
```sh
tar xvf ${DOWNLOADDIR}/typogrify-2.0.7.tar.gz -C ${BUILDDIR}
cp -a ${BUILDDIR}/typogrify-2.0.7{,.native}
pushd ${BUILDDIR}/typogrify-2.0.7.native
    PKG_CONFIG="" PKG_CONFIG_PATH="" \
    LDFLAGS="" PKG_CONFIG_SYSROOT_DIR="" ${SYSDIR}/cross-tools/bin/python3 setup.py build
    PKG_CONFIG="" PKG_CONFIG_PATH="" \
    LDFLAGS="" PKG_CONFIG_SYSROOT_DIR="" ${SYSDIR}/cross-tools/bin/python3 setup.py install --optimize=1
popd
pushd ${BUILDDIR}/typogrify-2.0.7
    _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_${CROSS_TARGET} \
    ${SYSDIR}/cross-tools/bin/python3 setup.py build
    _PYTHON_SYSCONFIGDATA_NAME=_sysconfigdata__linux_${CROSS_TARGET} \
    ${SYSDIR}/cross-tools/bin/python3 setup.py install --optimize=1 --root=${SYSDIR}/sysroot --prefix=/usr
popd
```

#### Gi-Docgen
https://gitlab.gnome.org/GNOME/gi-docgen/-/archive/2023.1/gi-docgen-2023.1.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/gi-docgen-2023.1.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/gi-docgen-2023.1
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        sed -i -e "s@\(${SYSROOT_DIR}/\)usr\(.*\)/\(g-ir-compiler\|g-ir-scanner\)@${CROSSTOOLS_DIR}/\2${CROSS_TARGET}-\3@g" build.ninja
        CC=${CROSS_TARGET}-gcc ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
echo '#!/bin/bash -e
qemu-loongarch64 ${SYSDIR}/sysroot/usr/bin/gi-docgen "$@"' > ${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-gi-docgen
chmod +x ${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-gi-docgen
cp -a ${SYSDIR}/cross-tools/bin/{${CROSS_TARGET}-,}gi-docgen 
```

#### Unifdef
https://dotat.at/prog/unifdef/unifdef-2.12.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/unifdef-2.12.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/unifdef-2.12
    make prefix="/usr" CC=${CROSS_TARGET}-gcc
    make prefix="/usr" CC=${CROSS_TARGET}-gcc DESTDIR=${PWD}/dest install
    cp -av dest/usr/bin/* ${SYSROOT_DIR}/usr/bin/
    cp -av dest/usr/share/man/man* ${SYSROOT_DIR}/usr/share/man/
popd
echo '#!/bin/bash -e
qemu-loongarch64 ${SYSDIR}/sysroot/usr/bin/unifdef "$@"' > ${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-unifdef
chmod +x ${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-unifdef
cp -a ${SYSDIR}/cross-tools/bin/{${CROSS_TARGET}-,}unifdef
```

#### Libavif
https://github.com/AOMediaCodec/libavif/archive/v0.11.1/libavif-0.11.1.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/libavif-0.11.1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libavif-0.11.1
        mkdir cross-build
        pushd cross-build
                CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
                cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
                      -DPKG_CONFIG_EXECUTABLE=${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-pkg-config \
                      -DCMAKE_SYSROOT=${SYSDIR}/sysroot \
                      -DCMAKE_FIND_ROOT_PATH=${SYSDIR}/sysroot/usr \
                      -DGETTEXT_MSGFMT_EXECUTABLE=/bin/msgfmt \
                      -DGETTEXT_MSGMERGE_EXECUTABLE=/bin/msgmerge \
                      -DPython_EXECUTABLE=${CROSSTOOLS_DIR}/bin/python3 \
                      -DPERL_EXECUTABLE=${SYSDIR}/cross-tools/bin/perl \
                      -DRuby_EXECUTABLE=${SYSDIR}/cross-tools/bin/ruby \
                      -DGPERF_EXECUTABLE=/bin/gperf \
                      -DDOXYGEN_EXECUTABLE=/bin/doxygen \
                      -DCMAKE_INSTALL_LIBDIR=/usr/lib64 -DLIB_SUFFIX=64 \
                      -DCMAKE_INSTALL_PREFIX=/usr \
                      -DBUILD_SHARED_LIBS=ON \
                      -Wno-dev ..
	        make ${JOBS}
	        make DESTDIR=${SYSDIR}/sysroot install
        popd
        rm -f ${SYSDIR}/sysroot/usr/lib64/*.la
popd
```

#### WebKitGTK
https://webkitgtk.org/releases/webkitgtk-2.40.0.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/webkitgtk-2.40.0.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/webkitgtk-2.40.0
    mkdir cross-prebuild
    pushd cross-prebuild
        WK_USE_CCACHE=NO CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
              -DPKG_CONFIG_EXECUTABLE=${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-pkg-config \
              -DCMAKE_SYSROOT=${SYSDIR}/sysroot \
              -DCMAKE_FIND_ROOT_PATH=${SYSDIR}/sysroot/usr \
              -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=/usr/lib64 \
              -DGETTEXT_MSGFMT_EXECUTABLE=/bin/msgfmt \
              -DGETTEXT_MSGMERGE_EXECUTABLE=/bin/msgmerge \
              -DCMAKE_MAKE_PROGRAM=${SYSDIR}/cross-tools/bin/ninja \
              -DPERL_EXECUTABLE=${SYSDIR}/cross-tools/bin/perl \
              -DRuby_EXECUTABLE=${SYSDIR}/cross-tools/bin/ruby \
              -DUNIFDEF_EXECUTABLE=${CROSSTOOLS_DIR}/bin/unifdef \
              -DGPERF_EXECUTABLE=/bin/gperf \
              -DCMAKE_SKIP_RPATH=ON \
              -DPORT=GTK \
              -DLIB_INSTALL_DIR=/usr/lib64 \
              -DUSE_LIBHYPHEN=OFF \
              -DUSE_GSTREAMER_TRANSCODER=OFF \
              -DENABLE_GAMEPAD=OFF \
              -DENABLE_MINIBROWSER=ON \
              -DUSE_WOFF2=OFF \
              -DUSE_SOUP2=OFF \
              -DUSE_WPE_RENDERER=ON \
              -DENABLE_BUBBLEWRAP_SANDBOX=OFF \
              -DENABLE_INTROSPECTION=OFF \
              -Wno-dev -G Ninja ..
        sed -i "s@${SYSDIR}/sysroot/usr/bin/wayland-scanner@${SYSDIR}/cross-tools/bin/wayland-scanner@g" build.ninja
        sed -i "s@glib-compile-resources@${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-glib-compile-resources@g" build.ninja
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
    mkdir cross-build
    pushd cross-build
        WK_USE_CCACHE=NO CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
              -DPKG_CONFIG_EXECUTABLE=${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-pkg-config \
              -DCMAKE_SYSROOT=${SYSDIR}/sysroot \
              -DCMAKE_FIND_ROOT_PATH=${SYSDIR}/sysroot/usr \
              -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=/usr/lib64 \
              -DGETTEXT_MSGFMT_EXECUTABLE=/bin/msgfmt \
              -DGETTEXT_MSGMERGE_EXECUTABLE=/bin/msgmerge \
              -DCMAKE_MAKE_PROGRAM=${SYSDIR}/cross-tools/bin/ninja \
              -DPERL_EXECUTABLE=${SYSDIR}/cross-tools/bin/perl \
              -DRuby_EXECUTABLE=${SYSDIR}/cross-tools/bin/ruby \
              -DUNIFDEF_EXECUTABLE=${CROSSTOOLS_DIR}/bin/unifdef \
              -DGPERF_EXECUTABLE=/bin/gperf \
              -DCMAKE_SKIP_RPATH=ON \
              -DPORT=GTK \
              -DLIB_INSTALL_DIR=/usr/lib64 \
              -DUSE_LIBHYPHEN=OFF \
              -DUSE_GSTREAMER_TRANSCODER=OFF \
              -DENABLE_GAMEPAD=OFF \
              -DENABLE_MINIBROWSER=ON \
              -DUSE_WOFF2=OFF \
              -DUSE_SOUP2=OFF \
              -DUSE_WPE_RENDERER=ON \
              -DENABLE_BUBBLEWRAP_SANDBOX=OFF \
              -DENABLE_INTROSPECTION=ON \
              -Wno-dev -G Ninja ..
        sed -i "s@ /usr\(.*\)\(g-ir-compiler\|g-ir-scanner\)@ ${SYSDIR}/cross-tools\1${CROSS_TARGET}-\2@g" build.ninja
        sed -i "s@${SYSDIR}/sysroot/usr/bin/wayland-scanner@${SYSDIR}/cross-tools/bin/wayland-scanner@g" build.ninja
        sed -i "s@${SYSDIR}/sysroot/usr/bin/gi-docgen generate@& --add-include-path=${SYSDIR}/sysroot/usr/share/gir-1.0@g" build.ninja
        sed -i "s@glib-compile-resources@${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-glib-compile-resources@g" build.ninja
        ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
```

#### Libassuan
https://www.gnupg.org/ftp/gcrypt/libassuan/libassuan-2.5.5.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/libassuan-2.5.5.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/libassuan-2.5.5
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### CDParanoia
https://ftp.osuosl.org/pub/xiph/releases/cdparanoia/cdparanoia-III-10.2.src.tgz
https://www.linuxfromscratch.org/patches/blfs/svn/cdparanoia-III-10.2-gcc_fixes-1.patch

```sh
tar xvf ${DOWNLOADDIR}/cdparanoia-III-10.2.src.tgz -C ${BUILDDIR}
pushd ${BUILDDIR}/cdparanoia-III-10.2
    patch -Np1 -i ${DOWNLOADDIR}/cdparanoia-III-10.2-gcc_fixes-1.patch
    ./configure $COMMON_CONFIG --mandir=/usr/share/man
    make -j1
    make prefix=${SYSDIR}/sysroot/usr LIBDIR=${SYSDIR}/sysroot/usr/lib64 MANDIR=${SYSDIR}/sysroot/usr/share/man install
popd
```

#### FAAC
https://github.com/knik0/faac/archive/1_30/faac-1_30.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/faac-1_30.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/faac-1_30
    ./bootstrap
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### AccountsService
https://www.freedesktop.org/software/accountsservice/accountsservice-23.11.69.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/accountsservice-23.11.69.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/accountsservice-23.11.69
    mkdir cross-build
    pushd cross-build
        meson --prefix=/usr --libdir=/usr/lib64 \
              --buildtype=release \
              --cross-file=${BUILDDIR}/meson-cross.txt ..
        sed -i -e "s@\(${SYSDIR}/\)sysroot/usr\(.*\)\(g-ir-compiler\|g-ir-scanner\)@\1cross-tools\2${CROSS_TARGET}-\3@g" build.ninja
        CC=${CROSS_TARGET}-gcc ninja
        DESTDIR=${SYSDIR}/sysroot ninja install
    popd
popd
cp -av ${DOWNLOADDIR}/default-user.icon ${SYSDIR}/sysroot/var/opt/default-user
```

#### Libpcap
https://www.tcpdump.org/release/libpcap-1.10.3.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/libpcap-1.10.3.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libpcap-1.10.3
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### NTFS-3g
https://github.com/tuxera/ntfs-3g/releases
https://tuxera.com/opensource/ntfs-3g_ntfsprogs-2022.10.3.tgz

```sh
tar xvf ${DOWNLOADDIR}/ntfs-3g_ntfsprogs-2022.10.3.tgz -C ${BUILDDIR}
pushd ${BUILDDIR}/ntfs-3g_ntfsprogs-2022.10.3
    ./configure $COMMON_CONFIG --with-fuse=internal
    make ${JOBS}
    make LDCONFIG="" DESTDIR=${SYSDIR}/sysroot install
    ln -sv ../bin/ntfs-3g ${SYSDIR}/sysroot/usr/sbin/mount.ntfs
    ln -sv ntfs-3g.8 ${SYSDIR}/sysroot/usr/share/man/man8/mount.ntfs.8
popd
mkdir -pv ${SYSDIR}/sysroot/mnt/usb
chmod -v 777 ${SYSDIR}/sysroot/mnt/usb
```

Squashfs-Tools
https://sourceforge.net/projects/squashfs/files/squashfs/squashfs4.6.1/squashfs-tools-4.6.1.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/squashfs-tools-4.6.1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/squashfs-tools-4.6.1/squashfs-tools
    for i in mksquashfs unsquashfs sqfstar sqfscat
    do
        sed -i.orig "s@^\$1@qemu-loongarch64 \$1@g" ../generate-manpages/$i-manpage.sh
    done
    make CC="${CROSS_TARGET}-gcc" ${JOBS}
    make CC="${CROSS_TARGET}-gcc" INSTALL_PREFIX=${SYSDIR}/sysroot/usr \
         INSTALL_MANPAGES_DIR=${SYSDIR}/sysroot/usr/share/man/man1 install
popd
```

#### Plymouth
https://www.freedesktop.org/software/plymouth/releases/plymouth-22.02.122.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/plymouth-22.02.122.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/plymouth-22.02.122
    cp ${SYSDIR}/cross-tools/share/automake-1.16/config.* build-tools/
    sed -i "/linux\/fs.h/d" src/libply/ply-utils.c
    ./configure $COMMON_CONFIG
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Dracut
https:/www.kernel.org/pub/linux/utils/boot/dracut/dracut-056.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/dracut-056.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/dracut-056
    CC=${CROSS_TARGET}-gcc \
    ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --libdir=/usr/lib64
    make CC=${CROSS_TARGET}-gcc ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### V4l2
https://www.linuxtv.org/downloads/v4l-utils/v4l-utils-1.24.1.tar.bz2

```sh
tar xvf ${DOWNLOADDIR}/v4l-utils-1.24.1.tar.bz2 -C ${BUILDDIR}
pushd ${BUILDDIR}/v4l-utils-1.24.1
    ./configure ${COMMON_CONFIG}
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### Jack2
https://github.com/jackaudio/jack2/archive/v1.9.22/jack2-1.9.22.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/jack2-1.9.22.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/jack2-1.9.22
    CXX=${CROSS_TARGET}-g++ CC=${CROSS_TARGET}-gcc JOBS=8 \
    PREFIX=/usr \
    python3 ./waf configure --libdir=/usr/lib64 \
           --doxygen --dbus --classic --alsa --clients 256 --ports-per-application=2048
    CXX=${CROSS_TARGET}-g++ CC=${CROSS_TARGET}-gcc JOBS=8 python3 ./waf build
    CXX=${CROSS_TARGET}-g++ CC=${CROSS_TARGET}-gcc JOBS=8 python3 ./waf --destdir=${SYSDIR}/sysroot install
popd
```


#### CCache
https://github.com/ccache/ccache/releases/download/v4.8/ccache-4.8.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/ccache-4.8.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/ccache-4.8
    mkdir cross-build
    pushd cross-build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
              -DPKG_CONFIG_EXECUTABLE=${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-pkg-config \
              -DCMAKE_SYSROOT=${SYSDIR}/sysroot \
              -DCMAKE_FIND_ROOT_PATH=${SYSDIR}/sysroot/usr \
              -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=/usr/lib64\
              -DGETTEXT_MSGFMT_EXECUTABLE=/bin/msgfmt \
              -DGETTEXT_MSGMERGE_EXECUTABLE=/bin/msgmerge \
              -DDOXYGEN_EXECUTABLE=/bin/doxygen \
              ..
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
popd
```

#### Nodejs
https://github.com/nodejs/node/archive/v19.8.1/node-19.8.1.tar.gz

```sh
tar xvf ${DOWNLOADDIR}/node-v19.8.1.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/node-19.8.1
    sed -i "s@registry.npmjs.org@registry.loongnix.cn:5873@g" deps/npm/lib/utils/config/definitions.js
    mkdir -pv out/Release
    for i in bytecode_builtins_list_generator gen-regexp-special-case torque mksnapshot
    do
        sed -i "/EXECUTABLE_SUFFIX/s@$i<@$i.host<@g" tools/v8_gypfiles/v8.gyp
        echo -e '#!/bin/bash -e \n' "qemu-loongarch64 ${PWD}/out/Release/$i \"\$@\"" > ${PWD}/out/Release/$i.host
        chmod +x ${PWD}/out/Release/$i.host
    done
    PKG_CONFIG=${CROSS_TARGET}-pkg-config \
    CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
    ./configure --prefix /usr --dest-cpu=loong64 --shared-openssl \
                --with-intl=system-icu --shared
    make -C out bytecode_builtins_list_generator gen-regexp-special-case torque ${JOBS}
    make -C out mksnapshot ${JOBS}
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
    cp -av out/Release/node ${SYSDIR}/sysroot/usr/bin/
    mv -v ${SYSDIR}/sysroot/usr/lib/libnode.so* ${SYSDIR}/sysroot/usr/lib64/
    ln -sv libnode.so.108 ${SYSDIR}/sysroot/usr/lib64/libnode.so
popd
```


#### FireFox 111
https://archive.mozilla.org/pub/firefox/releases/111.0.1/source/firefox-111.0.1.source.tar.xz
https://hg.mozilla.org/l10n-central/zh-CN/archive/tip.zip

下载中文语言包：

```sh
wget https://hg.mozilla.org/l10n-central/zh-CN/archive/tip.zip
mv -iv tip.zip ${DOWNLOADDIR}/firefox-110-l10.zip
```

编译步骤：

```sh
tar xvf ${DOWNLOADDIR}/firefox-110.0.1.source.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/firefox-110.0.1
    mkdir -pv mozbuild/l10n-central
    pushd mozbuild/l10n-central
        unzip ${DOWNLOADDIR}/firefox-110-l10.zip
        mv zh-CN* zh-CN
    popd
    find third_party/rust/ -name .cargo-checksum.json \
         -exec sed -i.uncheck -e 's/"files":{[^}]*}/"files":{ }/' '{}' '+'
    patch -Np1 -i ${DOWNLOADDIR}/firefox-100-add-loongarch.patch
    patch -Np1 -i ${DOWNLOADDIR}/firefox-110-fix-rust.patch
    patch -Np1 -i ${DOWNLOADDIR}/firefox-100-xpcom-add-loongarch.patch
    patch -Np1 -i ${DOWNLOADDIR}/firefox-100-for-clfs.patch
    patch -Np1 -i ${DOWNLOADDIR}/firefox-105-fix-for-gcc13.patch
    patch -Np1 -i ${DOWNLOADDIR}/firefox-105-fix-jit-for-loongarch64.patch
    cat > mozconfig << "EOF"
ac_add_options --disable-necko-wifi
ac_add_options --with-system-icu
ac_add_options --with-system-libevent
ac_add_options --with-system-libvpx
ac_add_options --with-system-nspr
ac_add_options --with-system-nss
ac_add_options --with-system-webp
ac_add_options --enable-jit
ac_add_options --disable-strip
ac_add_options --disable-jemalloc
ac_add_options --disable-install-strip
ac_add_options --enable-official-branding
ac_add_options --disable-debug-symbols
ac_add_options --prefix=/usr
ac_add_options --libdir=/usr/lib64
ac_add_options --target=loongarch64-unknown-linux-gnu
ac_add_options --enable-application=browser
ac_add_options --disable-crashreporter
ac_add_options --disable-updater
ac_add_options --disable-tests
ac_add_options --enable-optimize
ac_add_options --enable-system-ffi
ac_add_options --enable-system-pixman
ac_add_options --with-system-jpeg
ac_add_options --with-system-png
ac_add_options --with-system-zlib
ac_add_options --without-wasm-sandboxed-libraries
ac_add_options --enable-fmp4
ac_add_options --with-sysroot=${SYSDIR}/sysroot

unset MOZ_TELEMETRY_REPORTING
mk_add_options MOZ_OBJDIR=@TOPSRCDIR@/firefox-build-dir
EOF
    CC=${CROSS_TARGET}-gcc CXX=${CROSS_TARGET}-g++ \
    CXXFLAGS="-fpermissive -Wnonnull" \
    MACH_BUILD_PYTHON_NATIVE_PACKAGE_SOURCE=system MOZBUILD_STATE_PATH=${PWD}/mozbuild \
    ./mach configure
    CC=${CROSS_TARGET}-gcc CXX=${CROSS_TARGET}-g++ \
    CXXFLAGS="-fpermissive -Wnonnull" \
    MACH_BUILD_PYTHON_NATIVE_PACKAGE_SOURCE=system MOZBUILD_STATE_PATH=${PWD}/mozbuild \
    ./mach build ${JOBS}
    CC=${CROSS_TARGET}-gcc CXX=${CROSS_TARGET}-g++ \
    CXXFLAGS="-fpermissive -Wnonnull" \
    MACH_BUILD_PYTHON_NATIVE_PACKAGE_SOURCE=system MOZBUILD_STATE_PATH=${PWD}/mozbuild \
    ./mach package
    CC=${CROSS_TARGET}-gcc CXX=${CROSS_TARGET}-g++ \
    CXXFLAGS="-fpermissive -Wnonnull" \
    MACH_BUILD_PYTHON_NATIVE_PACKAGE_SOURCE=system MOZBUILD_STATE_PATH=${PWD}/mozbuild \
    ./mach build installers-zh-CN
    tar xvf firefox-build-dir/dist/firefox-*.zh-CN.linux-loongarch64.tar.bz2 \
        -C ${SYSDIR}/sysroot/usr/lib64/
    ln -sfv /usr/lib64/firefox/firefox ${SYSDIR}/sysroot/usr/bin/firefox
popd
cat > ${SYSDIR}/sysroot/usr/share/applications/firefox.desktop << "EOF"
[Desktop Entry]
Encoding=UTF-8
Name=Firefox
Name[zh_CN]=火狐浏览器
Comment=Browse the World Wide Web
Comment[zh_CN]=互联网浏览器
GenericName=互联网浏览器
Exec=firefox %u
Terminal=false
Type=Application
Icon=/usr/share/pixmaps/firefox.png
Categories=GNOME;GTK;Network;WebBrowser;
MimeType=text/xml;text/mml;application/xhtml+xml;application/xhtml+xml;application/vnd.mozilla.xul+xml;x-scheme-handler/http;x-scheme-handler/https
StartupNotify=true
EOF
ln -sfv ${SYSDIR}/sysroot/usr/lib64/firefox/browser/chrome/icons/default/default128.png \
        ${SYSDIR}/sysroot/usr/share/pixmaps/firefox.png
```

#### OpenJDK-18

* 代码准备  
　　OpenJDK支持LoongArch的版本需要专门的获取代码方式，以下是获取方式：

```sh
git clone https://github.com/openjdk/jdk.git --depth 1
pushd jdk
    git archive --format=tar --output ../jdk18-git.tar "master"
popd
mkdir jdk18-git
pushd jdk18-git
    tar xvf ../jdk18-git.tar
popd
tar -czf ${DOWNLOADDIR}/jdk18-git.tar.gz jdk18-git
```

* 下载BootJDK  
编译OpenJDK必须系统中有一个OpenJDK，这个时候需要下载一个与当前架构兼容的OpenJDK，若当前是X86_64，下载地址：  
  https://www.oracle.com/java/technologies/downloads/archive/
  https://www.oracle.com/java/technologies/javase/jdk18-archive-downloads.html
  https://download.oracle.com/java/18/archive/jdk-18.0.1.1_linux-x64_bin.tar.gz
  https://download.oracle.com/java/17/archive/jdk-17.0.4.1_linux-x64_bin.tar.gz
  
同样将下载的Openjdk放在```${DOWNLOADDIR}```目录中。

* 安装BootJDK

```sh
tar xvf ${DOWNLOADDIR}/jdk-18.0.1.1_linux-x64_bin.tar.gz -C ${SYSDIR}/cross-tools/
```
解压后会在```${SYSDIR}/cross-tools```目录中创建一个名为"jdk-18"的目录，接下来的制作会用到。
* 制作步骤  
　　按以下步骤制作OpenJDK-18并进行安装。

```sh
tar xvf ${DOWNLOADDIR}/jdk18-git.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/jdk18-git
    sed -i "s@(defined LOONGARCH)@(defined LOONGARCH64)@g" src/hotspot/os/linux/os_linux.cpp
    LDFLAGS="" CC="${CROSS_TARGET}-gcc" \
    sh ./configure --prefix=/usr --host=${CROSS_TARGET} \
                --with-zlib=system --with-libpng=system --enable-unlimited-crypto \
                --with-extra-cxxflags="-fno-lifetime-dse -fcommon" \
                --with-extra-cflags="-Wno-error -fno-lifetime-dse -fcommon" \
                --with-extra-ldflags="-Wl,-rpath-link=/opt/mylaos/sysroot/usr/lib64" \
                --with-stdc++lib=dynamic \
                --with-boot-jdk=${SYSDIR}/cross-tools/jdk-18.0.1.1 \
                --enable-jvm-feature-zero --with-jvm-variants=zero \
                --disable-warnings-as-errors
    make LP64=1 BUILD_CC="gcc" images
    pushd build/linux-loongarch64-zero-release/images/jdk
        find -type f -exec ${CROSS_TARGET}-strip --strip-unneeded '{}' ';'
    popd
    cp -a build/linux-loongarch64-zero-release/images/jdk ${SYSDIR}/sysroot/opt/openjdk-18
popd
```

#### Golang
https://go.dev/dl/go1.20.2.src.tar.gz

* 下载Bootstrap Golang
编译Golang必须系统中有一个Golang，这个时候需要下载一个与当前架构兼容的Golang，若当前使用的是X86_64，下载地址：  
https://go.dev/dl/go1.20.2.linux-amd64.tar.gz 
同样将下载的Golang放在```${DOWNLOADDIR}```目录中。

*安装 Bootstrap Golang

```sh
tar xvf ${DOWNLOADDIR}/go1.20.2.linux-amd64.tar.gz -C ${SYSDIR}/cross-tools/
```
解压后会在```${SYSDIR}/cross-tools```目录中创建一个名为"go"的目录，接下来的制作会用到。

* 制作步骤
　　按以下步骤制作Golang并进行安装。

```sh
tar xvf ${DOWNLOADDIR}/go1.20.2.src.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/go
    pushd src
        GOROOT_BOOTSTRAP=${SYSDIR}/cross-tools/go \
        GOOS=linux GOARCH=loong64 GO_LDFLAGS="-linkmode internal" \
        ./make.bash -v
    popd
    rm -v bin/go{,fmt}
    mv -v bin/linux_loong64/go* bin/
    rmdir -v bin/linux_loong64

    find bin pkg -type f -exec ${CROSS_TARGET}-strip --strip-unneeded '{}' ';'

    TAR_EXCLUDE=""
    for i in $(find -name "linux_*" -type d | grep -v "linux_loong64")
    do
        TAR_EXCLUDE="${TAR_EXCLUDE} --exclude=$i"
    done
    tar -czf /tmp/golang-1.20.2-loongarch64.tar.gz ${TAR_EXCLUDE} --exclude=.git* ./
    unset TAR_EXCLUDE
    
    mkdir -pv ${SYSDIR}/sysroot/opt/golang-1.20.2
    tar xf /tmp/golang-1.20.2-loongarch64.tar.gz -C ${SYSDIR}/sysroot/opt/golang-1.20.2
popd
```

#### FPC

* 代码准备  
　　FPC支持LoongArch的版本需要专门的获取代码方式，以下是获取方式：

```sh
git clone https://gitlab.com/freepascal.org/fpc/source.git --depth 1
pushd source
    git archive --format=tar --output ../fpc-git.tar "main"
popd
mkdir fpc-git
pushd fpc-git
    tar xvf ../fpc-git.tar
popd
tar -czf ${DOWNLOADDIR}/fpc-git.tar.gz fpc-git
```

* 制作步骤  
　　按以下步骤制作FPC并进行安装。

```sh
tar xvf ${DOWNLOADDIR}/fpc-git.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/fpc-git
    make FPC=/usr/bin/fpc CPU_TARGET=loongarch64 OS_TARGET=linux BINUTILSPREFIX=${CROSS_TARGET}- ${JBOS} all
    make FPC=/usr/bin/fpc CPU_TARGET=loongarch64 OS_TARGET=linux BINUTILSPREFIX=${CROSS_TARGET}- PREFIX=${SYSDIR}/sysroot install
    mv -v ${SYSDIR}/sysroot/lib/fpc/*/ppc* ${SYSDIR}/sysroot/bin/
popd
```

## 5 启动相关软件包

#### Linux
* 代码准备  
　　目前Linux内核官方的代码还不能启动LoongArch的及其，目前需要获取专门的内核代码，以下是获取方式：

```sh
git clone https://github.com/loongson/linux.git -b loongarch-next --depth 1
pushd linux
    git archive --format=tar --output ../linux-6.git.tar "loongarch-next"
popd
mkdir linux-6.git
pushd linux-6.git
    tar xvf ../linux-6.git.tar
popd
tar -czf ${DOWNLOADDIR}/linux-6.git.tar.gz linux-6.git
```

* 制作步骤

```sh
tar xvf ${DOWNLOADDIR}/linux-6.git.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/linux-6.git
	make mrproper
	make ARCH=loongarch CROSS_COMPILE=${CROSS_TARGET}- defconfig
	make ARCH=loongarch CROSS_COMPILE=${CROSS_TARGET}- menuconfig
	PKG_CONFIG_SYSROOT_DIR="" \
	     make ARCH=loongarch CROSS_COMPILE=${CROSS_TARGET}- ${JOBS}
	PKG_CONFIG_SYSROOT_DIR="" \
	     make ARCH=loongarch CROSS_COMPILE=${CROSS_TARGET}- INSTALL_MOD_PATH=dest modules_install
	mkdir -pv ${SYSDIR}/sysroot/lib/modules/
	cp -av dest/lib/modules/* ${SYSDIR}/sysroot/lib/modules/
	cp -av arch/loongarch/boot/vmlinux.efi ${SYSDIR}/sysroot/boot/vmlinux.efi
	pushd tools/perf
	    JOBS=78 make ARCH=loongarch CROSS_COMPILE=${CROSS_TARGET}-
	    JOBS=78 make ARCH=loongarch CROSS_COMPILE=${CROSS_TARGET}- \
	                 DESTDIR=${SYSDIR}/sysroot prefix=/usr install 
	popd
popd

```

　　因为是交叉编译的原因，Linux内核需要指定“ARCH”变量才能知道目标机器的架构，通过设置“CROSS_COMPILE”变量来指定命令前缀的方式来使用交叉编译工具的命令。

　　下面解释一下多个make命令步骤含义：  
　　* ```defconfig```，自动获取指定架构目录中的默认配置文件作为当前编译使用的配置文件。  
　　* ```menuconfig```，进入到交互式选择内核功能的界面，这需要主系统安装了Ncurses的开发库，该步骤可用来调整Linux内核选择，如果使用默认的就足够了，那么该步骤可以跳过。    
　　如果后续参考本文制作LiveUSB的话需要内核将USB存储设备支持编译进内核，将“USB Mass Storage support”前面的“M”改成“*”，如下：

```sh
　　Device Drivers  ---> 
　　    USB support  ---> 
　　        <*>   USB Mass Storage support
```
　　* ```modules_install```，安装模块文件，模块安装的根目录由“INSTALL_MOD_PATH”变量指定，这里指定了“dest”，代表安装到当前目录中的dest目录里，若没有该目录将自动创建。

　　如果要支持Xorg的键鼠，需要确认一下选项：

```sh
Device Drivers  --->
  Input device support --->
    <*> Generic input layer (needed for keyboard, mouse, ...) 
    <*>   Event interface                  
```

　　当Linux内核编译完成后，我们可以将内核文件“vmlinux.efi”和对应的模块复制到目标系统存放的目录中。

#### Linux-Firmware
```sh
tar xvf ${DOWNLOADDIR}/linux-firmware-20230310.tar.xz   -C ${BUILDDIR}
pushd ${BUILDDIR}/linux-firmware-20230310
	make DESTDIR=${SYSDIR}/sysroot install
popd
```
若觉得Linux-Firmware安装的固件文件太多，可以通过以下步骤进行精简（注：以下精简过程仅做参考，具体精简需根据实际情况）：

```sh
mv ${SYSDIR}/sysroot/usr/lib/firmware{,.orig}
mkdir -pv ${SYSDIR}/sysroot/usr/lib/firmware
cp -a ${SYSDIR}/sysroot/usr/lib/firmware.orig/{amd*,radeon,iwlwifi-*,rt*} \
      ${SYSDIR}/sysroot/usr/lib/firmware/
rm -rf ${SYSDIR}/sysroot/usr/lib/firmware.orig
```

　　安装Linux-Firmware软件包主要是因为LoongArch机器搭配了某些独显后需要相应的固件支持才能正常显示。

#### Grub2
```sh
tar -xvf ${DOWNLOADDIR}/grub-2.11.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/grub-2.11
    autoreconf -ifv
	mkdir cross-build
	pushd cross-build
		../configure --prefix=/usr  --libdir=/usr/lib64  --build=${CROSS_HOST} \
		             --host=${CROSS_TARGET} -with-platform=efi \
		             --with-utils=host --disable-werror
		make ${JOBS}
		make DESTDIR=${SYSDIR}/sysroot install
	popd
popd
```
　　为目标系统安装Grub2的命令及模块，这样在启动目标架构机器上启动目标系统后也可以制作对应的EFI文件和设置启动相关的文件了。

#### 安装Systemd服务
https://www.linuxfromscratch.org/blfs/downloads/systemd/blfs-systemd-units-20220720.tar.xz

```sh
tar -xvf ${DOWNLOADDIR}/blfs-systemd-units-20220720.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/blfs-systemd-units-20220720
    make DESTDIR=${SYSDIR}/sysroot install-sshd
popd
```

## 6 设置目标系统
　　目标系统的软件包制作过程已经完成，接下来就是对目标系统进行必要的设置，以便目标系统可以正常的启动和使用。

### 创建用户文件

　　创建基本的用户名，这些用户名大多数在启动过程中会用到，步骤如下：

```sh
cat > ${SYSDIR}/sysroot/etc/passwd << "EOF"
root::0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/bin/false
daemon:x:6:6:Daemon User:/dev/null:/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/var/run/dbus:/bin/false
lp:x:9:9:Print Service User:/var/spool/cups:/bin/false
polkitd:x:27:27:PolicyKit Daemon Owner:/etc/polkit-1:/bin/false
rsyncd:x:46:46:rsyncd Daemon:/home/rsync:/bin/false
sshd:x:50:50:sshd PrivSep:/var/lib/sshd:/bin/false
lightdm:x:65:65:Lightdm Daemon:/var/lib/lightdm:/bin/false
sddm:x:66:66:Simple Desktop Display Manager:/var/lib/sddm:/sbin/nologin
colord:x:71:71:Color Daemon Owner:/var/lib/colord:/bin/false
systemd-bus-proxy:x:72:72:systemd Bus Proxy:/:/bin/false
systemd-journal-gateway:x:73:73:systemd Journal Gateway:/:/bin/false
systemd-journal-remote:x:74:74:systemd Journal Remote:/:/bin/false
systemd-journal-upload:x:75:75:systemd Journal Upload:/:/bin/false
systemd-network:x:76:76:systemd Network Management:/:/bin/false
systemd-resolve:x:77:77:systemd Resolver:/:/bin/false
systemd-timesync:x:78:78:systemd Time Synchronization:/:/bin/false
systemd-coredump:x:79:79:systemd Core Dumper:/:/bin/false
systemd-oom:x:80:80:systemd Userspace OOM Killer:/:/bin/false
nobody:x:99:99:Unprivileged User:/dev/null:/bin/false
EOF
```


### 创建组文件

　　创建基本用户组，大多数都是系统必须的，步骤如下：

```sh
cat > ${SYSDIR}/sysroot/etc/group << "EOF"
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
lpadmin:x:19:
systemd-journal:x:23:
input:x:24:
polkitd:x:27:
mail:x:34:
rsyncd:x:46:
sshd:x:50:
kvm:x:61:
lightdm:x:65:
sddm:x:66:
colord:x:71:
systemd-bus-proxy:x:72:
systemd-journal-gateway:x:73:
systemd-journal-remote:x:74:
systemd-journal-upload:x:75:
systemd-network:x:76:
systemd-resolve:x:77:
systemd-timesync:x:78:
systemd-coredump:x:79:
systemd-oom:x:80:
saslauth:x:81:
wheel:x:97:
nogroup:x:99:
users:x:1000:
EOF
```

### 创建用户环境设置文件

```sh
echo '# /etc/bashrc

pathmunge () {
    case ":${PATH}:" in
        *:"$1":*)
            ;;
        *)
            if [ "$2" = "after" ] ; then
                PATH=$PATH:$1
            else
                PATH=$1:$PATH
            fi
    esac
}

pathmunge /usr/sbin

for i in /etc/profile.d/*.sh /etc/profile.d/sh.local ; do
    if [ -r "$i" ]; then
        if [ "${-#*i}" != "$-" ]; then
            . "$i"
        else
            . "$i" >/dev/null
        fi
    fi
done

unset i
unset -f pathmunge
' > ${SYSDIR}/sysroot/etc/bashrc
```

```sh
echo '# /etc/profile
. /etc/bashrc
' > ${SYSDIR}/sysroot/etc/profile
```

```sh
echo "PS1='[\u@\h \W]\\\$ '
export PS1
export LC_ALL=zh_CN.UTF-8
export GTK_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
export QT_IM_MODULE=ibus
export XDG_DATA_DIRS=/usr/share
export XDG_CONFIG_DIRS=/etc/xdg
export XDG_RUNTIME_DIR=/run/user/\$(id -ru)
export QT_PLUGIN_PATH=/usr/lib64/plugins:/usr/lib64/plugins/kcms
" > ${SYSDIR}/sysroot/etc/profile.d/default-event.sh
```

```sh
echo '
if [[ $(find /opt -maxdepth 1 -type d) ]]; then
    for i in $(find /opt -maxdepth 1 -type d | sort); do
        if [ -d $i/bin ]; then
            pathmunge $i/bin after
        fi
    done
fi
' > ${SYSDIR}/sysroot/etc/profile.d/add-opt-path.sh
```


```sh
mkdir -pv ${SYSDIR}/sysroot/etc/skel
echo '
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi
' > ${SYSDIR}/sysroot/etc/skel/.bash_profile
cp -v ${SYSDIR}/sysroot/etc/skel/.bash{_profile,rc}
```

### 创建动态库搜索配置

```sh
cat > ${SYSDIR}/sysroot/etc/ld.so.conf << "EOF"
include /etc/ld.so.conf.d/*.conf

EOF
mkdir -pv ${SYSDIR}/sysroot/etc/ld.so.conf.d
```


### 创建nsswitch文件

```sh
cat > ${SYSDIR}/sysroot/etc/nsswitch.conf << "EOF"
passwd: files
group: files
shadow: files

hosts: files dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

EOF
```

### 网络设置

```sh
cat > ${SYSDIR}/sysroot/etc/systemd/network/10-eth-dhcp.network << "EOF"
[Network]
DHCP=ipv4

[DHCP]
UseDomains=true
EOF
```

### 创建域名服务文件

```sh
ln -sfv /run/systemd/resolve/resolv.conf ${SYSDIR}/sysroot/etc/resolv.conf
```

### 创建主机名

```sh
echo "Sunhaiyong" > ${SYSDIR}/sysroot/etc/hostname
```
这里根据需要可以更换其他名字。


### 创建主机列表文件

```sh
cat > ${SYSDIR}/sysroot/etc/hosts << "EOF"
127.0.0.1 localhost.localdomain localhost
::1       localhost ip6-localhost ip6-loopback
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters
EOF

```

### 设置默认语言环境

```sh
cat > ${SYSDIR}/sysroot/etc/locale.conf << "EOF"
LANG=zh_CN.UTF-8
LC_ALL=zh_CN.UTF-8
LC_CTYPE=zh_CN.UTF-8
LC_NUMERIC=zh_CN.UTF-8
EOF
```

### 创建输入配置文件

```sh
cat > ${SYSDIR}/sysroot/etc/inputrc << "EOF"
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
　　通过创建输入配置文件，可以使终端输入时更加符合常见系统中的习惯，不创建该文件也不会对系统造成影响。

### 设置时间文件
```sh
cat > ${SYSDIR}/sysroot/etc/adjtime << "EOF"
0.0 0 0.0
0
LOCAL
EOF
mkdir -pv ${SYSDIR}/sysroot/var/lib/hwclock
ln -sv /etc/adjtime ${SYSDIR}/sysroot/var/lib/hwclock/adjtime
```
　　这里设置为使用BIOS提供的时间，如果使用UTC时间，可以将文件中的“LOCAL”改成“UTC”。

### Shell
```sh
cat > ${SYSDIR}/sysroot/etc/shells << "EOF"
/bin/bash
EOF
```

### 分区挂载文件
```sh
cat > ${SYSDIR}/sysroot/etc/fstab << "EOF"
# file system        mount-point    type     options     dump  fsck_order

# /dev/<root_dev>      /            xfs      defaults     0       0
# /dev/<boot_dev>      /boot        ext2     defaults     0       0
# /dev/<efi_dev>       /boot/efi    vfat     defaults     0       0
# /dev/<swap_dev>      swap         swap     pri=1        0       0

EOF
```

### 创建首次运行脚本

```sh
echo '#!/bin/bash
if [[ $(find /etc/first-run.d/ -maxdepth 1 -name "*.sh") ]]; then
    for i in $(ls /etc/first-run.d/*.sh | sort -n ) ; do
        if [ -f "$i" ]; then
            chmod +x $i
            $i
            if [ "$?" == "0" ]; then
                if [ -f "$i" ]; then
                    rm $i
                fi
            fi
        fi
    done
fi

if [ -x /usr/bin/run-startx.sh ]; then
    /usr/bin/run-startx.sh &
fi
' > ${SYSDIR}/sysroot/etc/rc.local
chmod +x ${SYSDIR}/sysroot/etc/rc.local

mkdir -pv ${SYSDIR}/sysroot/etc/first-run.d/

cat > ${SYSDIR}/sysroot/etc/first-run.d/000-os-first.sh << EOF
#!/bin/bash -e
pwconv
grpconv
ssh-keygen -A
update-mime-database /usr/share/mime
glib-compile-schemas /usr/share/glib-2.0/schemas
systemctl enable NetworkManager
systemctl start NetworkManager
systemctl disable sshd.socket
systemctl enable sshd.service
chown -v root:messagebus /usr/libexec/dbus-daemon-launch-helper
chmod -v 4750 /usr/libexec/dbus-daemon-launch-helper
gtk-update-icon-cache -qtf /usr/share/icons/hicolor
update-desktop-database -q
gtk-query-immodules-2.0 --update-cache
gtk-query-immodules-3.0 --update-cache
gdk-pixbuf-query-loaders --update-cache
dconf update
echo 1 > /var/run/first-run
EOF

cat > ${SYSDIR}/sysroot/etc/first-run.d/999-create-user.sh << EOF
useradd -m loongson -c "默认用户"
echo loongson:loongson | chpasswd
usermod -a -G video loongson
usermod -a -G input loongson
usermod -a -G wheel loongson
echo "[User]
Email=
Session=
PasswordHint=
Icon=/var/lib/AccountsService/icons/loongson
SystemAccount=false" > /var/lib/AccountsService/users/loongson
cp /var/opt/default-user /var/lib/AccountsService/icons/loongson
EOF
```

```sh
mkdir -pv ${SYSDIR}/sysroot/var/unit/{dm,wm}
```

```sh
echo '#!/bin/bash
if [ -d /var/unit/dm ]; then
    if [[ ! $(find /var/unit/dm/ -maxdepth 1 -type f) ]]; then
        if [ -d /var/unit/alone-app ]; then
            if [[ $(find /var/unit/alone-app/ -maxdepth 1 -type f) ]]; then
                HOME=/root startx
                poweroff
            fi
        fi
    fi
fi
' > ${SYSDIR}/sysroot/usr/bin/run-startx.sh
chmod u+x ${SYSDIR}/sysroot/usr/bin/run-startx.sh
```

```sh
ln -sv ../xinit/xinitrc.d ${SYSDIR}/sysroot/etc/X11/app-defaults/
```

```sh
echo '
if [ -d /var/unit/alone-app ]; then
    if [[ $(find /var/unit/alone-app -maxdepth 1 -type f) ]]; then
        for i in $(ls /var/unit/alone-app/* | sort | head -n1 ) ; do
            twm &
            exec $(cat $i)
        done
    else
        . /etc/X11/app-defaults/xinitrc
    fi
else
    . /etc/X11/app-defaults/xinitrc
fi
' > ${SYSDIR}/sysroot/root/.xinitrc
```

### 创建系统信息文件
```sh
cat > ${SYSDIR}/sysroot/etc/lsb-release << "EOF"
DISTRIB_ID="My GNU/Linux System for LoongArch64"
DISTRIB_RELEASE="8.1"
DISTRIB_CODENAME="Sun Haiyong"
DISTRIB_DESCRIPTION="My GNU/Linux System"
EOF
```

```sh
cat > ${SYSDIR}/sysroot/etc/os-release << "EOF"
NAME="My GNU/Linux System for LoongArch64"
VERSION="8.1"
ID=CLFS4LA64
PRETTY_NAME="My GNU/Linux System for LoongArch64 8.1"
VERSION_CODENAME="Sun Haiyong"
EOF
```

### 启动设置

#### 生成EFI文件
　　生成UEFI的启动文件，用于启动grub，命令如下：

```sh
mkdir -pv ${SYSDIR}/sysroot/boot/efi/EFI/BOOT
${CROSS_TARGET}-grub-mkimage \
          --directory "${SYSDIR}/sysroot/usr/lib64/grub/loongarch64-efi" \
          --prefix '(,gpt2)/boot/grub' \
          --output "${SYSDIR}/sysroot/boot/efi/EFI/BOOT/BOOTLOONGARCH64.EFI" \
          --format 'loongarch64-efi' \
          --compression 'auto' \
          'ext2' 'part_gpt'
cp -a ${SYSDIR}/sysroot/boot/efi/EFI/BOOT/BOOTLOONGARCH{64,}.EFI
```
　　因为运行的是存放在交叉编译工具目录中的Grub命令，所以根据当时安装的命名规则运行的命令是以`${CROSS_TARGET}-`开头的。

　　解释一下上述命令的参数：    
　　* ```--directory```，该参数指定生成EFI文件所使用模块存放的目录，这里指定的是目标系统存放目录中Grub安装的模块目录。  
　　* ```--prefix```，该参数指定EFI文件读取文件的基础目录，也就是说EFI如果需要读取什么文件的话都以该参数设置的目录作为最基础的目录，这里有一个很重要的参数设置```(,gpt2)```，这指定的是存储设备的分区，括号中有两个参数，并使用“,”分隔，逗号前的参数是磁盘编号，逗号后的参数是分区编号，我们看到这里没有指定磁盘编号，那么EFI启动后会自动使用启动EFI文件的磁盘编号来代替，而分区编号指定为`gpt2`,其中“gpt”代表分区类型，这里通常为“gpt”或者“msdos”，“gpt”代表了GPT分区，“msdos”代表了DOS分区，目前GPT分区逐渐成为主流，且UEFI的BIOS也建议分区采用GPT，“gpt”后面的数字代表分区的编号，第一个分区为“1”，第二个分区为“2”，所以这里`gpt2`代表的是GPT的第二个分区。  
　　之所以这样设置是为了方便安装了目标系统的存储设备可以正常的启动，因为通常存放EFI文件的分区和存放与其匹配的Grub启动相关文件的分区都在同一个存储设备上。  
　　* ```--output```，该参数指定生成的EFI文件存放的路径和文件名，这里设置的是目标系统存放目录中的“/boot/efi/EFI/BOOT”，这是按照一个系统被正常挂载后的目录结构，“/boot/efi”目录通常挂载的是第一个分区，也就是EFI分区，在该分区中通常要创建“EFI/BOOT”，因为UEFI的BIOS通常从这个分区的这个目录中载入EFI文件用于启动。“BOOTLOONGARCH64.EFI”是LoongArch机器使用的默认查找的启动EFI文件名。  
　　* ```--format```，该参数指定生成文件的格式名，不同架构以及不同启动方式的名字会不同，这里针对LoongArch64的EFI启动方式采用的名称为“loongarch64-efi”。  
　　* ```--compression 'auto'```，该参数指定生成的EFI文件采用的压缩方式，这里设置为`auto`就可以了，其它的取值还有`xz`代表用XZ的压缩方式和`none`代表不进行压缩。  
　　* `'ext2' 'part_gpt'`,这两个是指定加入到EFI文件中的模块，加入到EFI文件中的模块会自动作为EFI文件启动后能直接使用的功能，而如果没有加入到EFI中则需要通过加载模块的方式才能使用，这里只加入了`ext2`和`part_gpt`是因为模块都存放在存储设备中，如果要读取模块就需要能识别存储设备的分区和文件系统，这里`part_gpt`用来识别存储设备的GPT分区，而`ext2`则是该分区所使用的文件系统，当这两者与实际的分区和文件系统相匹配的情况下，后续再有什么功能上的需求都可以用加载模块的方式来使用了，这样可以最小化EFI文件的大小，可加快BIOS对EFI文件的加载速度。模块的存放位置由`--prefix`参数指定的基础目录决定，在这个基础目录中的loongarch64-efi目录就是存放各个模块的目录。

#### 安装Grub模块文件
　　生成好EFI文件后，就可以按照生成EFI所设置的目录存放Grub的模块文件了，安装过程如下：

```sh
mkdir -pv ${SYSDIR}/sysroot/boot/grub
cp -av ${SYSDIR}/sysroot/usr/lib64/grub/loongarch64-efi ${SYSDIR}/sysroot/boot/grub
```

## 7 处理目标系统

### 清理符号（symbol）信息
　　目前安装到目标系统中的二进制文件大多带有各种符号信息，这些信息不影响执行，但是占用了大量的存储空间，如果没有调试相关的需求，可以将这些信息清理掉以减少存储空间。

　　清理符号信息可以使用strip命令，但strip必须能够处理目标平台二进制，所以我们可以使用交叉编译工具链中的strip命令来操作，操作步骤如下：

```sh
pushd ${SYSDIR}/sysroot
	find usr/lib{,64} -type f -name \*.a -exec ${CROSS_TARGET}-strip --strip-debug {} ';'
	find usr/lib{,64} -type f -name \*.so* -exec ${CROSS_TARGET}-strip --strip-unneeded {} ';'
	find usr/{bin,sbin,libexec} -type f -exec ${CROSS_TARGET}-strip --strip-all {} ';'
	find opt -type f -exec ${CROSS_TARGET}-strip --strip-unneeded {} ';'
	find usr/lib/{cups,polkit-1} -type f -exec ${CROSS_TARGET}-strip --strip-unneeded {} ';'
	find usr/lib64/dracut -type f -exec ${CROSS_TARGET}-strip --strip-unneeded {} ';'
popd
```

　　这里我们发现strip使用的参数有多种，这里简单的说明一下：  
　　* `--strip-debug`，仅去掉调试相关的符号信息，该参数适合用于静态库文件，对于链接过程需要的信息是不会去掉的。  
　　* `--strip-unneeded`，删除所有与重定位无关的所有符号信息，该参数不能用于静态库文件，否则会导致静态链接时无法使用处理过的静态库。  
　　* `--strip-all`，该参数代表所有能去掉的符号信息都尽量去掉，该参数不建议用于库文件，特别是静态库文件。

### 清除.la文件
```sh
find ${SYSDIR}/sysroot/usr/lib64/ -type f -name "*.la" -exec rm '{}' ';'
```

### 清理交叉编译路径

```sh
pushd ${SYSDIR}/sysroot
    rm usr/lib64/perl5/5.3x/site_perl/auto/XML/Parser/.packlist
    rm usr/lib64/perl5/5.3x/site_perl/auto/URI/.packlist
    rm usr/lib64/rustlib/install.log

    sed -i "s@${SYSDIR}/cross-tools/bin/perl@/usr/bin/perl@g" \
           $(file usr/bin/* | grep "Perl script text" | awk -F':' '{ print $1 }')
    sed -i "s@${SYSDIR}/cross-tools/bin/perl@/usr/bin/perl@g" \
           $(file usr/libexec/xscreensaver/* | grep "Perl script text" | awk -F':' '{ print $1 }')

    sed -i -e "s@${SYSDIR}/sysroot/lib@/usr/lib@g" \
           -e "s@${SYSDIR}/sysroot/usr@/usr@g" \
           -e "s@${SYSDIR}/sysroot@@g" \
           $(file usr/bin/*-config | grep ASCII | awk -F':' '{ print $1 }') \
           $(find usr/lib64/ -type f -name "*.sh") \
           $(find usr/lib64/pkgconfig/ -type f) \
           $(find usr/lib64/ -type f -name "*.cmake") \
           $(find usr/lib64/ -type f -name "Makefile*")
       
    sed -i -e "s@${SYSDIR}/sysroot@@g" \
           $(find usr/lib64/ -type f -name "*.py") \
           $(file usr/lib64/rustlib/* | grep ASCII | awk -F':' '{ print $1 }') \
           $(find usr/lib64/ -type f -name "*.prl") \
           $(find usr/lib64/ -type f -name "*.pri")

    sed -i -e "s@${SYSDIR}/cross-tools/bin/loongarch64-unknown-linux-gnu-@/usr/bin/@g" \
           $(file usr/bin/*-config | grep ASCII | awk -F':' '{ print $1 }')

    sed -i -e "s@${SYSDIR}/cross-tools/bin@/usr/bin@g" \
           $(grep -rl "cross-tools" $(file ${SYSDIR}/sysroot/usr/bin/* | grep ASCII | awk -F':' '{ print $1 }')) \
           $(grep -rl "cross-tools" $(file ${SYSDIR}/sysroot/usr/bin/* | grep text | awk -F':' '{ print $1 }')) \
           $(find usr/share/ -type f -name "*.pl")
popd

```

### 打包系统
　　制作完成后就可以退出制作用户环境了，使用命令:

```sh
exit
```


### 打包系统

　　接着可以使用root权限对目标系统进行打包，打包步骤如下：

```sh
pushd ${SYSDIR}/sysroot
	sudo tar --xattrs-include='*' --owner=root --group=root -cjpf \
			${SYSDIR}/loongarch64-clfs-system-8.1.tar.bz2 *
popd
```

## 8 创建启动U盘
　　制作好了目标系统后，我们可以尝试启动这个目标系统，借助U盘，我们来制作一个可以启动的简易LiveUSB。
　　
### 设置U盘分区
　　找到一个容量不少于4G的U盘，如果没有进行符号清理，那么建议容量不少于8G，请确保U盘中没有重要和要保留的数据，因为接下来的操作将破坏U盘内原有的数据。

　　接着给U盘进行分区，建议划分为3个分区，分别是：  
　　第一分区：EFI 分区，文件系统为fat，容量100M即可；  
　　第二分区：boot分区，文件系统为ext2，容量500M即可；  
　　第三分区：根分区，文件系统建议为xfs，剩余容量可以都分给该分区。

　　假设U盘设备名为```sdb```,以下为实际制作步骤如下：

```sh
sudo cfdisk -z /dev/sdb
```

　　该命令将出现交互式操作模式，`-z`参数将强制进入分区类型选择（这会导致U盘上原有数据全部丢失，请再次确认没有要保留的数据后再继续），这里选择“gpt”，然后在分区的界面中对U盘按照上述的分区进行，保存退出，此时系统中将有“/dev/sdb1”、“/dev/sdb2”和"/dev/sdb3"这三个分区名，接下来就开始处理这三个分区。

　　首先，创建一个目录用于制作LiveUSB，命令如下：  

```sh
mkdir /tmp/liveusb
```

　　挂载U盘的第三个分区既根分区到该目录上，命令如下：

```sh
sudo mount /dev/sdb3 /tmp/liveusb
```

　　然后，创建一个boot分区，用于挂载第二分区既boot分区，命令如下：

```sh
sudo mkdir /tmp/liveusb/boot
sudo mount /dev/sdb2 /tmp/liveusb/boot
```

　　接着创建efi分区，用于挂载第一分区既EFI分区，命令如下：

```sh
sudo mkdir /tmp/liveusb/boot/efi
sudo mount /dev/sdb1 /tmp/liveusb/boot/efi
```

　　此时USB的分区挂载准备好了，接下来就是将目标系统解压到该目录即可，命令如下：

```sh
pushd /tmp/liveusb
    sudo tar -xvpf ${SYSDIR}/loongarch64-clfs-system-8.1.tar.bz2
popd
```

　　解压完目标系统后先不要着急卸载和拔下U盘，因为还需要一些工作。

### 制作Grub的启动菜单文件
　　用Grub启动机器后通常会自动加载grub.cfg文件，用来显示启动菜单，以下就是制作一个简单的启动菜单制作步骤：

```sh
pushd /tmp/liveusb
cat > boot/grub/grub.cfg << "EOF"
menuentry 'My GNU/Linux System for LoongArch64' {
echo 'Loading Linux Kernel ...'
linux /vmlinux.efi root=<PARTUUID> rootdelay=5 rw quiet
boot
}
EOF
popd
```
　　grub.cfg存放的目录是由生成EFI文件时```--prefix```参数设置决定的，按照参数设置的目录并命名为grub.cfg即可。
下面简单介绍一下菜单文件的设置内容：  
　　* ```menuentry```，该设置项设置启动菜单显示的条目，一个条目对应一个`menuentry`。  
　　* `echo`，输入内容，就是在屏幕上打印该行的内容。  
　　* `linux`，加载Linux内核，因当前加载的grub.cfg与Linux内核vmlinux.efi文件在同一个分区，则可以直接使用路径，若不在同一个分区中则需要设置磁盘和分区来指定内核文件路径。后面的`root=<PARTUUID> rootdelay=5 rw`都是提供给Linux内核启动时的参数：`root`指定启动根分区名，这里设置了待转换的```<PARTUUID>```，接下来会用到，也可以时用确定的设备名，假定U盘的设备名是sdb，根分区是sdb3，则在可以写成root=/dev/sdb3，当然这里需要根据U盘插入到目标机器上时的设备名进行修改；`rootdelay`设置等待时间，这通常在用U盘作为启动盘时使用，因为U盘会需要一小段的初始化，如果没有等待会导致找不到设备而启动失败；`rw`设置根分区按照可读写的方式挂载。  
　　* `initrd`，用于加在initrd或者initramfs文件提供给内核使用。

当设置根分区为待转换的```<PARTUUID>```时，就需要根据根分区的实际PARTUUID进行替换，替换步骤如下：

```sh
pushd /tmp/liveusb
	ROOTPARTUUID=$(sudo blkid /dev/sdb3 | awk -F'PARTUUID=' '{ print $2 }')
	sed -i "s@<PARTUUID>@PARTUUID=${ROOTPARTUUID}@g" boot/grub/grub.cfg
	unset ROOTPARTUUID
popd
```
　　我们可以看到替换步骤就是通过blkid命令获取到实际分区的“PARTUUID”，“PARTUUID”通常是由5段字母和数字组成的32个字符的字符串，每段字符使用“-”进行链接，例如：b2c2bd57-82e4-1c25-b87a-0e9caf919053。  
　　内核启动时可以通过给root参数传递“PARTUUID”的参数来查找根分区，这样可以使U盘具备更好的通用性。

　　做到这里，我们基本完成了LiveUSB的制作过程，接下来先卸载U盘：

```sh
sudo umount -R /tmp/liveusb
```
	
　　umount命令使用‵-R‵参数可以一次行把指定目录中多个挂载都卸载掉。

　　接下来就可以拔出U盘，然后到龙芯3A5000的机器上去启动一下试试吧。


## 9 进入系统
　　进入系统后还需要做一些工作以配合自己的使用需求，使用root用户执行以下命令：

```sh
passwd root
passwd loongson
```
设置root用户和默认用户loongson用户的密码，以防止他人进入系统。

## 10 附录

### 参考资料
《用“芯”探索 教你构建龙芯平台的Linux系统》 孙海勇 著

LFS： https://www.linuxfromscratch.org/lfs/  

BLFS: https://www.linuxfromscratch.org/blfs/
