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

```
export DISTRO_URL=https://mirrors.bfsu.edu.cn/fedora/releases/34/Everything/x86_64/os/
sudo dnf install @core @c-development rpm-build git python3-devel texinfo \
                 zlib-devel xz-lzma-compat gettext-devel perl-FindBin \
                 perl-Pod-Html rpm-devel tcl ncurses-devel openssl-devel bc \
                 wget meson ninja-build gperf \
                 --installroot ${HOME}/la-clfs --disablerepo="*" \
                 --repofrompath base,${DISTRO_URL} \
                 --releasever 34 --nogpgcheck
```
　　以上步骤将在当前用户的目录中创建"la-clfs"的目录，在这个目录中将安装一个基本的制作环境，这里安装的是Fedora 34的系统，读者也可以安装其它的系统作为制作环境。
　　接下来的制作过程都将在这个目录中进行。

　　复制当前系统的域名解析配置文件到新建立的系统中，以便该系统可以访问网络资源。

    cp -a /etc/resolv.conf ${HOME}/la-clfs

　　接下来切换到该目录中:

    sudo chroot ${HOME}/la-clfs

　　挂载必要的文件系统：

    mount -t proc proc proc
    mount -t sysfs sys sys
    mount -t devtmpfs dev dev 
    mount -t devpts devpts dev/pts 
    mount -t tmpfs shm dev/shm

### 2.2 制作环境的设置

#### 创建必要的目录
　　使用如下命令创建几个目录，后续的制作过程都将在这些目录中进行。

    export SYSDIR=/opt/mylaos
    mkdir -pv ${SYSDIR}
    mkdir -pv ${SYSDIR}/downloads
    mkdir -pv ${SYSDIR}/build
    install -dv ${SYSDIR}/cross-tools
    install -dv ${SYSDIR}/sysroot

　　简单说明一下这几个目录的用处：

* 通过设置“SYSDIR"变量方便对“基础目录”的使用，该变量设置了一个具体的目录作为“基础目录”，与本次制作相关的工作都在该目录中进行。

* “downloads”目录用来存放各种软件的源码包以及补丁文件；

* “build”目录用来编译各个软件包；

* “cross-tools”目录用来存放交叉工具链及相关的软件；

* “sysroot”用来存放目标平台系统。

#### 创建制作用户

　　为了防止制作过程中意外的对系统本身造成破坏，创建一个普通用户的账号，后续的制作过程除非需要特殊权限操作，否则对于目标系统的一切操作都使用该用户进行。

    groupadd lauser
    useradd -s /bin/bash -g lauser -m -k /dev/null lauser

　　设置目录为新创建用户所属：

    chown -Rv lauser ${SYSDIR}
    chmod -v a+wt ${SYSDIR}/{sysroot,cross-tools,downloads,build}


##### 切换到制作用户

　　使用命令切换到新创建的用户：  

    su - lauser

　　使用“su”命令进行切换时加上“-”参数可以防止切换前的用户环境变量带到新用户环境中。

##### 设置制作用户环境

　　为制作用户设置最精简和必要的环境变量，以帮助后续制作过程的开展，以下为用户的环境变量进行长期设置。

    cat > ~/.bash_profile << "EOF"
    exec env -i HOME=${HOME} TERM=${TERM} PS1='\u:\w\$ ' /bin/bash
    EOF

    cat > ~/.bashrc << "EOF"
    set +h
    umask 022
    export SYSDIR="/opt/mylaos"
    export BUILDDIR="${SYSDIR}/build"
    export DOWNLOADDIR="${SYSDIR}/downloads"
    export LC_ALL=POSIX
    export CROSS_HOST="$(echo $MACHTYPE | sed "s/$(echo $MACHTYPE | cut -d- -f2)/cross/")"
    export CROSS_TARGET="loongarch64-unknown-linux-gnu"
    export MABI="lp64"
    export BUILD_ARCH="-march=loongarch"
    export BUILD_MABI="-mabi=${MABI}"
    export BUILD64="-mabi=lp64"
    export PATH=${SYSDIR}/cross-tools/bin:/bin:/usr/bin
    unset CFLAGS
    unset CXXFLAGS
    EOF


　　这里设置了几个环境变量，下面简单介绍这些变量的含义：

* SYSDIR：方便引用“基础目录”，可以通过修改该变量所设置的路径来改变所使用的“基础目录”。
* BUILDIR：该变量指定的目录用来进行软件包编译过程使用的目录。
* DOWNLOADDIR：该变量指定的目录存放制作系统的过程中所需要的软件包及一些必要的补丁文件。
* CROSS_HOST:设置“主系统”所使用的架构系统描述词
* CROSS_TARGET：设置“目标系统”所使用的架构系统描述词。
* MABI:指定“目标系统”默认使用的ABI名称。
* BUILD_ARCH:设置编译“目标系统”中的软件包时使用的默认架构参数。
* BUILD_MABI:设置编译“目标系统”中的软件包时使用的默认ABI参数。
* BUILD64：设置编译“目标系统”中的软件包为64位ABI时使用的ABI参数。

　　设置好用户环境配置文件后通过source命令使环境设置生效，使用命令：

    source ~/.bash_profile



#### 创建目标系统的目录结构

　　我们要制作的目标系统是常规的Linux/GNU系统，我们按照常规的Linux/GNU系统所使用的目录结构创建目标系统的目录，命令如下:

```
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
popd
```
　　目标系统将存放在${SYSDIR}/sysroot目录中，所以以该目录为基础创建各种目录和链接文件。

### 2.3 下载软件包


　　为了使用最新的软件包构建目标系统，这可能需要从网络中下载软件包源代码及补丁文件，下载的文件建议存放在“downloads”目录中。

	pushd ${SYSDIR}/downloads

　　然后可以使用wget工具下载相应版本的软件包，例如下载coreutils-8.32这个软件包，可使用命令：

		wget https://ftp.gnu.org/gnu/coreutils/coreutils-8.32.tar.xz

　　下载后软件包存放在“downloads”目录中。

　　以下是本次制作所用到的软件包源码的地址：

　　**Acl:** https://download.savannah.gnu.org/releases/acl/acl-2.3.1.tar.xz  
　　**Attr:** https://download.savannah.gnu.org/releases/attr/attr-2.5.1.tar.gz  
　　**Autoconf:** https://ftp.gnu.org/gnu/autoconf/autoconf-2.71.tar.xz  
　　**Automake:** https://ftp.gnu.org/gnu/automake/automake-1.16.3.tar.xz  
　　**Bash:** https://ftp.gnu.org/gnu/bash/bash-5.1.tar.gz  
　　**BC:** https://github.com/gavinhoward/bc/releases/download/4.0.2/bc-4.0.2.tar.xz  
　　**Binutils:** *暂无下载*  
　　**Bison:** https://ftp.gnu.org/gnu/bison/bison-3.7.6.tar.xz  
　　**Bzip2:** https://www.sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz  
　　**Coreutils:** https://ftp.gnu.org/gnu/coreutils/coreutils-8.32.tar.xz  
　　**D-Bus**: https://dbus.freedesktop.org/releases/dbus/dbus-1.12.20.tar.gz  
　　**Diffutils:** https://ftp.gnu.org/gnu/diffutils/diffutils-3.7.tar.xz  
　　**E2fsprogs:** https://downloads.sourceforge.net/project/e2fsprogs/e2fsprogs/v1.46.2/e2fsprogs-1.46.2.tar.gz  
　　**Expat:** https://prdownloads.sourceforge.net/expat/expat-2.4.1.tar.xz  
　　**File:** https://astron.com/pub/file/file-5.40.tar.gz  
　　**Findutils:** https://ftp.gnu.org/gnu/findutils/findutils-4.8.0.tar.xz  
　　**Flex:** https://github.com/westes/flex/releases/download/v2.6.4/flex-2.6.4.tar.gz  
　　**Gawk:** https://ftp.gnu.org/gnu/gawk/gawk-5.1.0.tar.xz  
　　**GCC:** *暂无下载*  
　　**GDBM:** https://ftp.gnu.org/gnu/gdbm/gdbm-1.19.tar.gz  
　　**Gettext:** https://ftp.gnu.org/gnu/gettext/gettext-0.21.tar.xz  
　　**Glibc:** *暂无下载*  
　　**GMP:** https://ftp.gnu.org/gnu/gmp/gmp-6.2.1.tar.xz  
　　**GPerf:** https://ftp.gnu.org/gnu/gperf/gperf-3.1.tar.gz  
　　**Grep:** https://ftp.gnu.org/gnu/grep/grep-3.6.tar.xz  
　　**Groff:** https://ftp.gnu.org/gnu/groff/groff-1.22.4.tar.gz  
　　**Grub2:** ```https://github.com/loongarch64/grub  分支名“dev-la64”```  
　　**Gzip:** https://ftp.gnu.org/gnu/gzip/gzip-1.10.tar.xz  
　　**Iana-Etc:** https://github.com/Mic92/iana-etc/releases/download/20210526/iana-etc-20210526.tar.gz  
　　**IPRoute2:** https://www.kernel.org/pub/linux/utils/net/iproute2/iproute2-5.12.0.tar.xz  
　　**KBD:** https://www.kernel.org/pub/linux/utils/kbd/kbd-2.4.0.tar.xz  
　　**Kmod:** https://www.kernel.org/pub/linux/utils/kernel/kmod/kmod-29.tar.xz  
　　**Less:** https://www.greenwoodsoftware.com/less/less-581.tar.gz  
　　**Libcap:** https://www.kernel.org/pub/linux/libs/security/linux-privs/libcap2/libcap-2.50.tar.xz  
　　**Libelf:** https://sourceware.org/ftp/elfutils/0.185/elfutils-0.185.tar.bz2  
　　**Libffi:** https://sourceware.org/pub/libffi/libffi-3.3.tar.gz  
　　**Libpipeline:** https://download.savannah.gnu.org/releases/libpipeline/libpipeline-1.5.3.tar.gz  
　　**Libtool:** https://ftp.gnu.org/gnu/libtool/libtool-2.4.6.tar.xz  
　　**Linux:** *暂无下载*  
　　**Linux-Firmware:** https://mirrors.edge.kernel.org/pub/linux/kernel/firmware/linux-firmware-20210511.tar.xz  
　　**M4:** https://ftp.gnu.org/gnu/m4/m4-1.4.18.tar.xz  
　　**Make:** https://ftp.gnu.org/gnu/make/make-4.3.tar.gz  
　　**Man-DB:** https://download.savannah.gnu.org/releases/man-db/man-db-2.9.4.tar.xz  
　　**Man-Pages:** https://www.kernel.org/pub/linux/docs/man-pages/man-pages-5.11.tar.xz  
　　**MPC:** https://ftp.gnu.org/gnu/mpc/mpc-1.2.1.tar.gz  
　　**MPFR:** https://www.mpfr.org/mpfr-4.1.0/mpfr-4.1.0.tar.xz  
　　**Ncurses:** https://ftp.gnu.org/gnu/ncurses/ncurses-6.2.tar.gz  
　　**Ninja:** https://github.com/ninja-build/ninja/archive/v1.10.2/ninja-1.10.2.tar.gz  
　　**OpenSSL:** https://www.openssl.org/source/openssl-1.1.1k.tar.gz  
　　**Patch:** https://ftp.gnu.org/gnu/patch/patch-2.7.6.tar.xz  
　　**Pkg-Config:** https://pkg-config.freedesktop.org/releases/pkg-config-0.29.2.tar.gz  
　　**Procps-NG:** https://sourceforge.net/projects/procps-ng/files/Production/procps-ng-3.3.17.tar.xz  
　　**PSmisc:** https://sourceforge.net/projects/psmisc/files/psmisc/psmisc-23.4.tar.xz  
　　**Readline:** https://ftp.gnu.org/gnu/readline/readline-8.1.tar.gz  
　　**Sed:** https://ftp.gnu.org/gnu/sed/sed-4.8.tar.xz  
　　**Shadow:** https://github.com/shadow-maint/shadow/releases/download/4.8.1/shadow-4.8.1.tar.xz  
　　**Systemd:** https://github.com/systemd/systemd/archive/v246/systemd-246.tar.gz  
　　**Tar:** https://ftp.gnu.org/gnu/tar/tar-1.34.tar.xz  
　　**Texinfo:** https://ftp.gnu.org/gnu/texinfo/texinfo-6.7.tar.xz  
　　**Util-Linux:** https://www.kernel.org/pub/linux/utils/util-linux/v2.36/util-linux-2.36.2.tar.xz  
　　**VIM:** https://github.com/vim/vim/archive/refs/tags/v8.2.2879.tar.gz  
　　**XZ:** https://tukaani.org/xz/xz-5.2.5.tar.xz  
　　**Zlib:** https://zlib.net/zlib-1.2.11.tar.xz  
　　**Zstd:** https://github.com/facebook/zstd/releases/download/v1.5.0/zstd-1.5.0.tar.gz  

　　以下是本次制作所需补丁文件的下载地址：

　　https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/automake-1.16.3-add-loongarch.patch  
　　https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/gcc-8-loongarch-fix-libdir.patch  
　　https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/glibc-2.28-fix-loongarch_pr_uid_and_pr_gid.patch  
　　https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/kbd-2.4.0-backspace-1.patch  
　　https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/libffi-3.3-add-loongarch.patch  
　　https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/patches/systemd-248-add-loongarch64.patch  

　　都下载完成后，离开"downloads"目录:

	popd


## 3 制作交叉工具链及相关工具
　　接下来就正式进入交叉工具链和相关工具的制作环节。
### 3.1 Linux内核头文件

* 代码准备  
　　Linux内核需要进行扩充式移植的软件包，在没有软件官方支持的情况下需要专门的获取代码的方式进行，以下是获取方式：

```
略
```

* 制作步骤  
　　按以下步骤制作Linux内核头文件并安装到目标系统目录中。

```
tar xvf ${DOWNLOADDIR}/linux-4.19.167.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/linux-4.19.167
	make mrproper
	make ARCH=loongarch INSTALL_HDR_PATH=dest headers_install
	find dest/include -name '.*' -delete
	mkdir -pv ${SYSDIR}/sysroot/usr/include
	cp -rv dest/include/* ${SYSDIR}/sysroot/usr/include
popd
```


### 3.2 交叉编译器之Binutils
* 代码准备  
　　Binutils需要进行扩充式移植的软件包，在没有软件官方支持的情况下需要专门的获取代码的方式进行，以下是获取方式：

```
略
```

* 制作步骤  
　　按以下步骤制作交叉编译工具链中的Binutils并安装到存放交叉工具链的目录中。

```
tar xvf ${DOWNLOADDIR}/binutils-2.31.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/binutils-2.31
	rm -rf gdb libdecnumber readline sim
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
　　制作交叉工具链中所使用的GMP软件包。

	tar xvf ${DOWNLOADDIR}/gmp-6.2.1.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/gmp-6.2.1
		./configure --prefix=${SYSDIR}/cross-tools --enable-cxx --disable-static
		make
		make install
	popd

### 3.4 MPFR
　　制作交叉工具链中所使用的MPFR软件包。  

	tar xvf ${DOWNLOADDIR}/mpfr-4.1.0.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/mpfr-4.1.0
		./configure --prefix=${SYSDIR}/cross-tools --disable-static --with-gmp=${SYSDIR}/cross-tools
		make
		make install
	popd

### 3.5 MPC
　　制作交叉工具链中所使用的MPC软件包。

	tar xvf ${DOWNLOADDIR}/mpc-1.2.1.tar.gz -C ${BUILDDIR}
	pushd ${BUILDDIR}/mpc-1.2.1 
		./configure --prefix=${SYSDIR}/cross-tools --disable-static --with-gmp=${SYSDIR}/cross-tools
		make
		make install
		popd


### 3.6 交叉编译器之GCC（精简版）
* 代码准备  
　　GCC需要进行扩充式移植的软件包，在没有软件官方支持的情况下需要专门的获取代码的方式进行，以下是获取方式：

```
略
```

* 制作步骤  
　　制作交叉编译器中的GCC，第一次编译交叉工具链的GCC需要采用精简方式进行编译和安装，否则会因为缺少目标系统的C库而导致部分内容编译链接失败，制作过程如下：

```
tar xvf ${DOWNLOADDIR}/gcc-8.3.0.tar.gz -C ${BUILDDIR} 
pushd ${BUILDDIR}/gcc-8.3.0
	patch -Np1 -i ${DOWNLOADDIR}/gcc-8-loongarch-fix-libdir.patch
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
		             --with-abi=${MABI} --with-fix-loongson3-llsc --with-arch=loongarch \
		             --enable-languages=c --enable-tls
		make all-gcc all-target-libgcc
		make install-gcc install-target-libgcc
	popd
popd
```

对于目标是LoongArch架构来说，目前有几个参数是需要特别注意的：  
* ```--with-newlib```，因为当前没有目标系统Glibc的支持，所以使用newlib来临时支援GCC的运行。    
* ```--disable-shared```，使用newlib需要配合该参数。
* ```--with-abi=${MABI}```，转换过来就是--with-abi=lp64，loongarch64使用的ABI名字为lp64。  
* ```--with-arch=loongarch```，指定目标架构为LoongArch。  
* ```--enable-tls```，该参数必须指定，否则可能在后续编译目标系统的Glibc上出现错误。  
* ```--enable-languages=c```，这次仅编译C语言的支持就可以了，因为当前没有目标系统的Glibc，只能制作精简版。


### 3.7 目标系统的Glibc
* 代码准备  
　　Glibc需要进行扩充式移植的软件包，在没有软件官方支持的情况下需要专门的获取代码的方式进行，以下是获取方式：

```
略
```

* 制作步骤  
　　在制作并安装好交叉工具链的Binutils、精简版的GCC以及Linux内核的头文件后就可以编译目标系统的Glibc了，制作和安装步骤如下：

```
	tar xvf ${DOWNLOADDIR}/glibc-2.28.tar.gz -C ${BUILDDIR}
	pushd ${BUILDDIR}/glibc-2.28
	patch -Np1 -i ${DOWNLOADDIR}/glibc-2.28-fix-loongarch_pr_uid_and_pr_gid.patch
	mkdir -v build-64
	pushd build-64
		BUILD_CC="gcc" CC="${CROSS_TARGET}-gcc ${BUILD64}" \
		CXX="${CROSS_TARGET}-gcc ${BUILD64}" \
		AR="${CROSS_TARGET}-ar" RANLIB="${CROSS_TARGET}-ranlib" \
		../configure --prefix=/usr --host=${CROSS_TARGET} --build=${CROSS_HOST} \
		             --libdir=/usr/lib64 --libexecdir=/usr/lib64/glibc --enable-add-ons \
		             --with-tls --with-binutils=${SYSDIR}/cross-tools/bin \
		             --with-headers=${SYSDIR}/sysroot/usr/include \
		             --enable-obsolete-rpc --disable-werror
			make
			make DESTDIR=${SYSDIR}/sysroot install
		popd
	popd
```
　　Glibc是目标系统的一部分，因此指定prefix等路径参数时是按照常规系统的路径进行设置的，所以必须在安装时指定DESTDIR来指定安装到存放目标系统的目录中。

### 3.8 交叉编译器之GCC（完整版）
　　完成目标系统的Glibc之后就可以着手制作交叉工具链中完整版的GCC了，制作步骤如下：

```
tar xvf ${DOWNLOADDIR}/gcc-8.3.0.tar.gz -C ${BUILDDIR} 
pushd ${BUILDDIR}/gcc-8.3.0
	patch -Np1 -i ${DOWNLOADDIR}/gcc-8-loongarch-fix-libdir.patch
	mkdir build-all
	pushd build-all
		AR=ar LDFLAGS="-Wl,-rpath,${SYSDIR}/cross-tools/lib" \
		../configure --prefix=${SYSDIR}/cross-tools --build=${CROSS_HOST} \
		             --host=${CROSS_HOST} --target=${CROSS_TARGET} \
		             --with-sysroot=${SYSDIR}/sysroot --with-mpfr=${SYSDIR}/cross-tools \
		             --with-gmp=${SYSDIR}/cross-tools --with-mpc=${SYSDIR}/cross-tools \
		             --enable-__cxa_atexit --enable-threads=posix --with-system-zlib \
		             --enable-libstdcxx-time --enable-checking=release \
		             --with-abi=${MABI} --with-arch=loongarch --enable-tls \
		             --enable-languages=c,c++,fortran,objc,obj-c++,lto
		make
		make install
	popd
popd
```

在完成目标系统的Glibc之后就可以增加和修改一些编译参数了，主要是如下：  
* 去掉了```--with-newlib```和```--disable-shared```，因为有Glibc，所以不再需要newlib了。  
* ```--enable-threads=posix```,可以设置线程支持了。
* ```--enable-languages=c,c++,fortran,objc,obj-c++,lto```，可以支持更多的开发语言了。

### 3.9 File
　　File软件包的官方最新版已经集成了LoongArch的支持，可以识别出LoongArch架构的二进制文件，因此制作时使用5.40以上的版本。

	tar xvf ${DOWNLOADDIR}/file-5.40.tar.gz -C ${BUILDDIR}
	pushd ${BUILDDIR}/file-5.40
		./configure --prefix=${SYSDIR}/cross-tools
		make
		make install
	popd

### 3.10 Automake
　　Automake软件包中提供了许多软件包集成用来生成Makefile文件的脚本，但该脚本目标尚未增加对LoongArch架构的支持，因此需要对软件包打补丁文件来增加支持，制作步骤如下：

	tar xvf ${DOWNLOADDIR}/automake-1.16.3.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/automake-1.16.3
		patch -Np1 -i ${DOWNLOADDIR}/automake-1.16.3-add-loongarch.patch
		./configure --prefix=${SYSDIR}/cross-tools
		make
		make install
	popd
　　打上补丁并安装到交叉工具链的目录中，这样当后续有软件包需要更新脚本文件时就可以通过本次安装的Automake中的脚本文件来进行替换。

### 3.11 Pkg-Config
　　为了能在交叉编译目标系统的过程中使用目标系统中已经安装的“pc”文件，我们在交叉工具链的目录中安装一个专门用来从目标系统目录中的查询“pc”文件的pkg-config命令，制作过程如下：

	tar xvf ${DOWNLOADDIR}/pkg-config-0.29.2.tar.gz -C ${BUILDDIR}/
	pushd ${BUILDDIR}/pkg-config-0.29.2
		./configure --prefix=${SYSDIR}/cross-tools \
		            --with-pc_path=${SYSDIR}/sysroot/usr/lib64/pkgconfig:${SYSDIR}/sysroot/usr/share/pkgconfig \
		            --program-prefix=${CROSS_TARGET}- --with-internal-glib --disable-host-tool
		make
		make install
	popd

### 3.12 Ninja

	tar xvf ${DOWNLOADDIR}/ninja-1.10.2.tar.gz -C ${BUILDDIR}
	pushd ${BUILDDIR}/ninja-1.10.2
		python3 configure.py --bootstrap
		install -vm755 ninja ${SYSDIR}/cross-tools/bin/
	popd

### 3.13 Groff
	编译目标系统的过程中会对Groff版本有一定要求，因此在交叉工具链的目录中安装一个版本较新的Groff。

	tar xvf ${DOWNLOADDIR}/groff-1.22.4.tar.gz -C ${BUILDDIR}
	pushd ${BUILDDIR}/groff-1.22.4
		PAGE=A4 ./configure --prefix=${SYSDIR}/cross-tools
		make
		make install
	popd

### 3.14 Grub2
　　为了在交叉编译的环境下可以制作生成LoongArch机器上使用的EFI启动文件，我们在交叉工具链目录中存放一个可以生成目标机器EFI的Grub软件包。

* 代码准备  
　　Glibc需要进行扩充式移植的软件包，在没有软件官方支持的情况下需要专门的获取代码的方式进行，以下是获取方式：

```
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

* 制作步骤  

```
tar -xvf ${DOWNLOADDIR}/grub-2.06.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/grub-2.06
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
　　本次制作的Grub命令可以运行在X86的Linux系统环境中但可以生成LoongArch机器上使用的EFI文件。


## 4 制作目标系统
　　交叉工具链及其相关的工具制作并安装完成后就可以继续制作目标系统了。
　　
### 4.1 软件包制作说明

#### 架构测试脚本替换
　　在制作目标系统的过程中会经常遇到configure阶段提示不识别loongarch64架构的字样，这通常是软件包自带的架构探测脚本没有增加对loongarch64架构的识别，因此需要去对该问题进行处理，处理的方式通常有两种：  
　　1. 删除配置脚本，然后通过automake命令自动将新的探测脚本加入到软件包中，具体的操作方式为：  

    rm config.guess config.sub
    automake --add-missing

　　这里假定config.guess和config.sub两个脚本文件在软件包的第一级目录下，也可能是在build-aux之类的目录，找到文件并删除，然后使用automake命令的“--add-missing”参数来运行，该参数会自动确认是否缺少探测架构的脚本，如果缺少会从Automake软件包安装的目录中复制过来，因automake运行的是我们在交叉工具链目录中的，所以已经增加了LoongArch架构的判断，这样软件包就可以正常运行了。

　　2.直接替换文件，具体的操作方式为：

    cp ${SYSDIR}/sysroot/usr/share/automake-1.16/config.* config/

　　如果使用automake命令无法解决，可以直接复制Automake软件包安装的脚本文件，以我们安装的Automake-1.16版本为例，从${SYSDIR}/sysroot/usr/share/automake-1.16/中复制config开头的文件覆盖当前要编译的软件包中的同名文件即可，这里假定需要覆盖的文件在config目录中，也可能是在其它目录，可根据需要进行覆盖。

　　也可能一个软件包中有多个探测脚本，那么就需要全部进行覆盖。
　　
#### 安装目标系统中的软件包
　　目标系统中的软件包安装的时候都是按照根目录（“/”）来存放的，所以如果直接安装那么就会安装到主系统的目录中，这必然是不对的，所以我们在安装的时候增加“DESTDIR”参数指定一个目录，那么安装的文件将以该指定目录作为安装的根目录进行安装，当我们设置为目标系统存放的目录时，就可以避开与主系统的冲突也可以让安装的软件包以正常的目录结构进行安装。

　　在后续的制作过程中会看到大多数软件包都支持“DESTDIR”参数设置，但也有个别软件包不支持，这种情况下通常采用软件包支持的类似功能参数来解决。

#### 交叉编译软件包
　　通常在带有configure配置脚本的软件包可以使用“build”、“host”参数来指定编译方式，当“build”和“host”相同时是本地编译，不同时就是交叉编译。
　　
　　“build”参数可以理解为当前主系统所使用的架构系统信息，而“host”则是目标系统运行的架构系统信息，在本文中采用在x86的Linux系统中交叉编译LoongArch64架构的Linux系统，所以根据之前定义的环境变量，“build”指定为```${CROSS_HOST}```则代表了当前主系统，“host”指定为```${CROSS_TARGET}```则代表了要编译生成的目标架构系统。

　　由于是交叉编译，所以在软件包的配置阶段有可能探测的参数错误，这可能导致编译出来的软件包不匹配目标架构系统，这时可以采用指定部分探测参数的方式来解决，通常可以采用创建config.cache文件，然后将一些需要探测的参数和取值写入到该文件中，例如：

```
cat > config.cache << "EOF"
    ac_cv_func_mmap_fixed_mapped=yes
    ......
EOF
```

　　然后在configure的参数中指定```--cache-file=config.cache```，这样就可以在探测这些参数时使用文件中设置的值而不是尝试去探测，这可以避免探测到错误的取值。

#### 编译目录
　　多数软件包可以在软件包自己的“根目录”中进行配置和编译，但也有一些软件包会建议创建一个新的目录来配置和编译，对这些需要创建目录进行编译的软件包，我们通常采用在该软件目录下创建一个“build”开头的目录，并在该目录中进行编译，这样便于使用完软件包后的清理工作。

### 4.2 软件包的制作

#### Man-Pages
	tar xvf ${DOWNLOADDIR}/man-pages-5.11.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/man-pages-5.11
		make DESTDIR=${SYSDIR}/sysroot install
	popd
　　Man-Pages软件包没有配置阶段，直接安装到目标系统的目录中即可。

##### Iana-Etc
	tar xvf ${DOWNLOADDIR}/iana-etc-20210407.tar.gz -C ${BUILDDIR}
	pushd ${BUILDDIR}/iana-etc-20210407
		cp services protocols ${SYSDIR}/sysroot/etc
	popd
　　Iana-Etc软件包无需配置编译，只要将包含的文件复制到目标系统的目录中即可。

#### GMP
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
　　GMP软件包自带的探测架构脚本不支持LoongArch，因此删除探测脚本并用automake命令重新安装探测脚本。

#### MPFR
	tar xvf ${DOWNLOADDIR}/mpfr-4.1.0.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/mpfr-4.1.0
		./configure --build=${CROSS_HOST} --host=${CROSS_TARGET} --prefix=/usr --libdir=/usr/lib64
		make
		make DESTDIR=${SYSDIR}/sysroot install
		rm -v ${SYSDIR}/sysroot/usr/lib64/libmpfr.la
	popd

#### MPC
	tar xvf ${DOWNLOADDIR}/mpc-1.2.1.tar.gz -C ${BUILDDIR}
	pushd ${BUILDDIR}/mpc-1.2.1
		rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
		automake --add-missing
		./configure --build=${CROSS_HOST} --host=${CROSS_TARGET} --prefix=/usr --libdir=/usr/lib64
		make
		make DESTDIR=${SYSDIR}/sysroot install
		rm -v ${SYSDIR}/sysroot/usr/lib64/libmpc.la
	popd

#### Zlib
	tar xvf ${DOWNLOADDIR}/zlib-1.2.11.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/zlib-1.2.11
		CC="${CROSS_TARGET}-gcc" ./configure --prefix=/usr --libdir=/usr/lib64
		make
		make DESTDIR=${SYSDIR}/sysroot install
	popd

#### Binutils
　　这次编译的Binutils是目标系统中使用的，在交叉编译阶段不会使用到它。

	tar xvf ${DOWNLOADDIR}/binutils-2.31.tar.gz -C ${BUILDDIR}
	pushd ${BUILDDIR}/binutils-2.31
		rm -rf gdb libdecnumber readline sim
		mkdir build
		pushd build
			../configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
			             --host=${CROSS_TARGET} --enable-shared --disable-werror \
			             --with-system-zlib --enable-64-bit-bfd
			make tooldir=/usr
			make DESTDIR=${SYSDIR}/sysroot tooldir=/usr install
		popd
	popd

#### GCC
　　与上面编译的Binutils一样，这次编译的GCC也是在目标系统中使用的编译器，在交叉编译阶段不会使用到它，但是其提供的libgcc、libstdc++等库可以为后续软件包的编译提供链接用的库。

	tar xvf ${DOWNLOADDIR}/gcc-8.3.0.tar.gz -C ${BUILDDIR} 
	pushd ${BUILDDIR}/gcc-8.3.0
		patch -Np1 -i ${DOWNLOADDIR}/gcc-8-loongarch-fix-libdir.patch
		mkdir build
		pushd build
			../configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
			             --host=${CROSS_TARGET} --target=${CROSS_TARGET} \
			             --enable-__cxa_atexit --enable-threads=posix \
			             --with-system-zlib --enable-libstdcxx-time \
			             --enable-checking=release --enable-tls \
			             --with-abi=lp64 --with-arch=loongarch \
			             --enable-languages=c,c++,fortran,objc,obj-c++,lto
			make
			make DESTDIR=${SYSDIR}/sysroot install
			ln -sv /usr/bin/cpp ${SYSDIR}/sysroot/lib
			ln -sv gcc ${SYSDIR}/sysroot/usr/bin/cc
		popd
	popd

　　因在目标系统中使用，所以编译的完整一些，将C、C++以及Fortran等语言的支持加上。

#### Bzip2
	tar xvf ${DOWNLOADDIR}/bzip2-1.0.8.tar.gz -C ${BUILDDIR}
	pushd ${BUILDDIR}/bzip2-1.0.8
		sed -i.orig -e "/^all:/s/ test//" Makefile
		make CC=${CROSS_TARGET}-gcc -f Makefile-libbz2_so
		make clean
		make CC=${CROSS_TARGET}-gcc
		make PREFIX=${SYSDIR}/sysroot/usr install
		cp -v bzip2-shared ${SYSDIR}/sysroot/bin/bzip2
		cp -av libbz2.so* ${SYSDIR}/sysroot/lib64
		ln -sfv ../../lib64/libbz2.so.1.0 ${SYSDIR}/sysroot/usr/lib64/libbz2.so
		rm -v ${SYSDIR}/sysroot/usr/bin/{bunzip2,bzcat,bzip2}
		ln -sfv bzip2 ${SYSDIR}/sysroot/bin/bunzip2
		ln -sfv bzip2 ${SYSDIR}/sysroot/bin/bzcat
		rm -fv ${SYSDIR}/sysroot/usr/lib/libbz2.a
	popd

　　由于Bzip2软件包没有configure的配置脚本，因此在编译的时候直接给make命令指定CC参数，该参数用来设置编译程序时使用的编译器命令名，这里设置了交叉编译器的命令名，使得接下来的编译采用交叉编译器进行。
　　安装Bzip2软件包时因没有DESTDIR参数用来设置安装根目录，所以在PREFIX参数中加入目标系统存放目录的路径。

#### XZ
	tar xvf ${DOWNLOADDIR}/xz-5.2.5.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/xz-5.2.5
		./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} --host=${CROSS_TARGET}
		make
		make DESTDIR=${SYSDIR}/sysroot install
	popd

#### Zstd
	tar xvf ${DOWNLOADDIR}/zstd-1.5.0.tar.gz -C ${BUILDDIR}
	pushd ${BUILDDIR}/zstd-1.5.0
		make CC="${CROSS_TARGET}-gcc" PREFIX=/usr LIBDIR=/usr/lib64
		make CC="${CROSS_TARGET}-gcc" PREFIX=/usr LIBDIR=/usr/lib64 DESTDIR=${SYSDIR}/sysroot install
	popd

#### File
	tar xvf ${DOWNLOADDIR}/file-5.40.tar.gz -C ${BUILDDIR}
	pushd ${BUILDDIR}/file-5.40
		rm config.{sub,guess}
		automake --add-missing
		./configure --prefix=/usr  --libdir=/usr/lib64 --build=${CROSS_HOST} --host=${CROSS_TARGET}
		make
		make DESTDIR=${SYSDIR}/sysroot install
	popd

#### Ncurses
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

	cp  ${SYSDIR}/sysroot/usr/bin/ncursesw6-config ${SYSDIR}/cross-tools/bin/
	sed -i "s@-L\$libdir@@g" ${SYSDIR}/cross-tools/bin/ncursesw6-config

　　在安装完目标系统的Ncurses后，复制了一个ncursesw6-config脚本命令到交叉编译目录中，这是因为后续编译一些软件包时会调用该命令来获取安装到目标系统中的Nucrses库链接信息，而如果主系统中的库与目标系统中的库链接不一致可能导致链接失败，因此提供一个可以正确链接信息的脚本是有效的解决方案。

#### Readline
	tar xvf ${DOWNLOADDIR}/readline-8.1.tar.gz -C ${BUILDDIR}
	pushd ${BUILDDIR}/readline-8.1
		sed -i '/MV.*old/d' Makefile.in
		sed -i '/{OLDSUFF}/c:' support/shlib-install
		rm support/config.{sub,guess}
		automake --add-missing
		./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} --host=${CROSS_TARGET} \
					--disable-static --with-curses
		make SHLIB_LIBS="-lncursesw"
		make SHLIB_LIBS="-lncursesw" DESTDIR=${SYSDIR}/sysroot install
	popd

　　因交叉编译的原因，Redaline的配置脚本无法正确的探测目标系统中安装的Ncurses软件包，因此在配置中加入```--with-curses```参数保证加入Ncurses的支持以及在编译阶段加入```SHLIB_LIBS="-lncursesw"```以保证正确链接库文件。

#### M4
	tar xvf ${DOWNLOADDIR}/m4-1.4.18.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/m4-1.4.18
		sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c
		echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h
		./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
		make
		make DESTDIR=${SYSDIR}/sysroot install
	popd

#### BC
	tar xvf ${DOWNLOADDIR}/bc-4.0.2.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/bc-4.0.2
		CC="${CROSS_TARGET}-gcc" HOSTCC="gcc" ./configure --prefix=/usr
		make
		make DESTDIR=${SYSDIR}/sysroot install
	popd

#### Flex
	tar xvf ${DOWNLOADDIR}/flex-2.6.4.tar.gz -C ${BUILDDIR}
	pushd ${BUILDDIR}/flex-2.6.4
		./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
		            --host=${CROSS_TARGET} --disable-static
		make
		make DESTDIR=${SYSDIR}/sysroot install
		ln -sv flex ${SYSDIR}/sysroot/usr/bin/lex
	popd

#### Attr
	tar xvf ${DOWNLOADDIR}/attr-2.5.1.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/attr-2.5.1
		./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
		            --host=${CROSS_TARGET} --disable-static --sysconfdir=/etc
		make
		make DESTDIR=${SYSDIR}/sysroot install
		rm ${SYSDIR}/sysroot/usr/lib64/libattr.la
	popd

#### Acl
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

#### Libcap
	tar xvf ${DOWNLOADDIR}/libcap-2.49.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/libcap-2.49
		make CROSS_COMPILE="${CROSS_TARGET}-" BUILD_CC="gcc" GOLANG=no prefix=/usr lib=lib64
		make CROSS_COMPILE="${CROSS_TARGET}-" BUILD_CC="gcc" GOLANG=no prefix=/usr lib=lib64 \
			 DESTDIR=${SYSDIR}/sysroot install
	popd

　　因为该软件包没有配置脚本，所以直接在make命令上增加指定编译器的参数```CROSS_COMPILE="${CROSS_TARGET}-"```，这里要注意CROSS_COMPILE指定的是交叉编译工具的前缀而不是具体命令名，这样在编译过程中各种编译、汇编和链接相关的命令都会自动加上这个指定的前缀。

　　另外在编译过程中会编译在主系统中运行的程序，这个时候不能使用交叉编译器编译，所以还需要指定```BUILD_CC="gcc"```这个参数来保证编译这些要运行的程序使用的是本地编译器。

#### Shadow
	tar xvf ${DOWNLOADDIR}/shadow-4.8.1.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/shadow-4.8.1
		sed -i 's/groups$(EXEEXT) //' src/Makefile.in
		find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \;
		find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
		find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;
		sed -e 's:#ENCRYPT_METHOD DES:ENCRYPT_METHOD SHA512:' \
		    -e 's:/var/spool/mail:/var/mail:'                 \
		    -e '/PATH=/{s@/sbin:@@;s@/bin:@@}'                \
		    -i etc/login.defs
		sed -i 's/1000/999/' etc/useradd
		./configure --sysconfdir=/etc --build=${CROSS_HOST} --host=${CROSS_TARGET} \
					--with-group-name-max-length=32
		make
		make DESTDIR=${SYSDIR}/sysroot install
		sed -i 's/yes/no/' ${SYSDIR}/sysroot/etc/default/useradd
	popd

　　该软件包修改了一些默认的设置，下面介绍以下主要修改的内容：  
　　1、将用户密码的加密模式从DES改为SHA512，后者相对前者更难破解。  
　　2、修改useradd创建用户默认的起始组编号，这个修改可改可不改，但无论改不改这个组编号对应的组都必须在目标系统中存在。  
　　3、修改useradd命令创建用户时默认创建mail目录的设置，该目录目前已很少使用，所以修改为默认不创建。

#### Sed
	tar xvf ${DOWNLOADDIR}/sed-4.8.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/sed-4.8
		rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
		automake --add-missing
		./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
		make
		make DESTDIR=${SYSDIR}/sysroot install
	popd

#### PSmisc
	tar xvf ${DOWNLOADDIR}/psmisc-23.4.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/psmisc-23.4
		sed -i.orig "/rpl_malloc/d" configure
		sed -i.orig "/rpl_realloc/d" configure
		./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
		make
		make DESTDIR=${SYSDIR}/sysroot install
	popd

#### Gettext
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
	popd

　　Gettext软件包的源码中有多处探测架构的脚本，这些脚本在当前的版本中均不支持LoongArch架构，所以找到全部探测脚本并进行替换。

#### Bison
	tar xvf ${DOWNLOADDIR}/bison-3.7.6.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/bison-3.7.6
		rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
		automake --add-missing
		./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
		make
		make DESTDIR=${SYSDIR}/sysroot install
	popd

#### Grep
	tar xvf ${DOWNLOADDIR}/grep-3.6.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/grep-3.6
		rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
		automake --add-missing
		./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
		make
		make DESTDIR=${SYSDIR}/sysroot install
	popd

#### Bash
	tar xvf ${DOWNLOADDIR}/bash-5.1.tar.gz -C ${BUILDDIR}
	pushd ${BUILDDIR}/bash-5.1
		rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
		automake --add-missing
		
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
		
		sed -i  '/^bashline.o:.*shmbchar.h/a bashline.o: ${DEFDIR}/builtext.h' Makefile.in
		
		./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
		            --host=${CROSS_TARGET} --without-bash-malloc \
		            --with-installed-readline --cache-file=config.cache
		make
		make DESTDIR=${SYSDIR}/sysroot install
	popd

　　Bash软件在交叉编译时的配置阶段会有大量的参数探测错误，需要我们手工指定这些参数的真实取值，创建一个文本文件，将这些参数的取值写进去，并在configure配置中增加```--cache-file=config.cache```参数（其中config.cache就是保存参数的文本文件名）。

#### Libtool
	tar xvf ${DOWNLOADDIR}/libtool-2.4.6.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/libtool-2.4.6
		./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} --host=${CROSS_TARGET}
		make
		make DESTDIR=${SYSDIR}/sysroot install
	popd

#### GDBM
	tar xvf ${DOWNLOADDIR}/gdbm-1.19.tar.gz -C ${BUILDDIR}
	pushd ${BUILDDIR}/gdbm-1.19
		./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
		            --host=${CROSS_TARGET} --disable-static --enable-libgdbm-compat
		make
		make DESTDIR=${SYSDIR}/sysroot install
	popd

#### GPerf
	tar xvf ${DOWNLOADDIR}/gperf-3.1.tar.gz -C ${BUILDDIR}
	pushd ${BUILDDIR}/gperf-3.1
		./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
		make
		make DESTDIR=${SYSDIR}/sysroot install
	popd

#### Expat
	tar xvf ${DOWNLOADDIR}/expat-2.3.0.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/expat-2.3.0
		./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} --host=${CROSS_TARGET} \
					--disable-static
		make
		make DESTDIR=${SYSDIR}/sysroot install
	popd

#### Autoconf
	tar xvf ${DOWNLOADDIR}/autoconf-2.71.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/autoconf-2.71
		./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
		make
		make DESTDIR=${SYSDIR}/sysroot install
	popd

#### Automake
	tar xvf ${DOWNLOADDIR}/automake-1.16.3.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/automake-1.16.3
		patch -Np1 -i ${DOWNLOADDIR}/automake-1.16.3-add-loongarch.patch
		./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
		make
		make DESTDIR=${SYSDIR}/sysroot install
	popd

　　在交叉编译目录中我们安装了一个Automake软件包，该软件包提供了增加LoongArch支持的探测脚本，有很多软件都会需要用这些脚本来覆盖自己源代码中的脚本。

　　在制作的目标系统中当然也需要改其中的Automake软件包，也使其支持LoongArch，这样将来在目标系统中配置编译一些软件包时就可以使用上。

#### Kmod
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


#### Libelf
	tar xvf ${DOWNLOADDIR}/elfutils-0.183.tar.bz2 -C ${BUILDDIR}
	pushd ${BUILDDIR}/elfutils-0.183
		LIBS="-lpthread -llzma -lz -lbz2 -lzstd" \
		./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
					--host=${CROSS_TARGET} --disable-libdebuginfod --disable-debuginfod \
					 ac_cv_search_lzma_auto_decoder=-llzma ac_cv_search_ZSTD_decompress=-lzstd
		make
		make -C libelf DESTDIR=${SYSDIR}/sysroot install
		make -C libelf DESTDIR=${SYSDIR}/sysroot install-data
	popd

　　该软件包使用交叉编译会有个别功能探测错误，使用指定参数和取值的方式来解决，该制作步骤上采用了另一种设置参数取值的方式，若要指定的参数数值不多的情况下可以直接在configure的参数中进行设置,如```ac_cv_search_lzma_auto_decoder=-llzma```和```ac_cv_search_ZSTD_decompress=-lzstd```这就是这种设置方式，也可以通过将这两个参数写到“config.cache”，然后通过“--cache-file=config.cache”来使用。

#### Libffi
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

　　Libffi也是一个要增加架构支持的软件包，这里通过打补丁的方式加入LoongArch架构的支持。

#### OpenSSL
	tar xvf ${DOWNLOADDIR}/openssl-1.1.1k.tar.gz -C ${BUILDDIR}
	pushd ${BUILDDIR}/openssl-1.1.1k
		CC="${CROSS_TARGET}-gcc" \
		./Configure --prefix=/usr --openssldir=/etc/ssl \
					--libdir=lib64 shared zlib linux-generic64
		make
		sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
		make DESTDIR=${SYSDIR}/sysroot install
	popd

　　OpenSSL是一个十分重要的安全算法库，通常对不同的架构可以使用汇编对算法进行优化，但其也提供了通用的C实现，因此可以采用```linux-generic64```来指定用通用实现进行编译，当然通用实现的性能是相对较低的，在今后如果有了针对LoongArch64的优化支持则可以修改该参数来达到优化编译的目的。

#### Coreutils
	tar xvf ${DOWNLOADDIR}/coreutils-8.32.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/coreutils-8.32
		sed -i "s@SYS_getdents@SYS_getdents64@g" src/ls.c
		rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
		automake --add-missing
		FORCE_UNSAFE_CONFIGURE=1 \
		./configure --prefix=/usr  --build=${CROSS_HOST} --host=${CROSS_TARGET} \
					--enable-no-install-program=kill,uptime
		make
		make DESTDIR=${SYSDIR}/sysroot install
		mv -v ${SYSDIR}/sysroot/usr/bin/chroot ${SYSDIR}/sysroot/usr/sbin
	popd

#### Diffutils
	tar xvf ${DOWNLOADDIR}/diffutils-3.7.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/diffutils-3.7
		rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
		automake --add-missing
		./configure --prefix=/usr  --build=${CROSS_HOST} --host=${CROSS_TARGET}
		make
		make DESTDIR=${SYSDIR}/sysroot install
	popd

#### Gawk
	tar xvf ${DOWNLOADDIR}/gawk-5.1.0.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/gawk-5.1.0
		sed -i 's/extras//' Makefile.in
		for i in $(dirname $(find -name "config.sub"))
		do
			rm ./$i/config.{sub,guess}
			pushd $(dirname ./$i)
				automake --add-missing
			popd
		done
		./configure --prefix=/usr  --libdir=/usr/lib64 --build=${CROSS_HOST} --host=${CROSS_TARGET}
		make
		make DESTDIR=${SYSDIR}/sysroot install
	popd

#### Findutils
	tar xvf ${DOWNLOADDIR}/findutils-4.8.0.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/findutils-4.8.0
		./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
		            --host=${CROSS_TARGET} --localstatedir=/var/lib/locate
		make
		make DESTDIR=${SYSDIR}/sysroot install
	popd

#### Groff
	tar xvf ${DOWNLOADDIR}/groff-1.22.4.tar.gz -C ${BUILDDIR}
	pushd ${BUILDDIR}/groff-1.22.4
		rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
		automake --add-missing
		PAGE=A4 ./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
		make TROFFBIN=troff GROFFBIN=groff GROFF_BIN_PATH=
		make DESTDIR=${SYSDIR}/sysroot install
	popd

#### Less
	tar xvf ${DOWNLOADDIR}/less-581.2.tar.gz -C ${BUILDDIR}
	pushd ${BUILDDIR}/less-581.2
		./configure --prefix=/usr --sysconfdir=/etc --build=${CROSS_HOST} --host=${CROSS_TARGET}
		make
		make DESTDIR=${SYSDIR}/sysroot install
	popd

#### Gzip
	tar xvf ${DOWNLOADDIR}/gzip-1.10.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/gzip-1.10
		rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
		automake --add-missing
		./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
		make
		make DESTDIR=${SYSDIR}/sysroot install
	popd

#### IPRoute2
	tar xvf ${DOWNLOADDIR}/iproute2-5.12.0.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/iproute2-5.12.0
		sed -i /ARPD/d Makefile
		rm -fv man/man8/arpd.8
		sed -i 's/.m_ipt.o//' tc/Makefile
		make CC="${CROSS_TARGET}-gcc" HOSTCC="gcc" KERNEL_INCLUDE=${SYSDIR}/sysroot/usr/include
		make CC="${CROSS_TARGET}-gcc" HOSTCC="gcc" KERNEL_INCLUDE=${SYSDIR}/sysroot/usr/include \
				DESTDIR=${SYSDIR}/sysroot install
	popd

　　IPRoute2软件包没有配置阶段，直接在make命令中使用“CC”变量指定交叉编译器，而对于在编译过程中会临时编译一些在本地运行的程序时就需要使用“HOSTCC”变量来指定本地编译器，否则“HOSTCC”会使用“CC”变量的指定编译器，那么编译出来的程序就无法在交叉编译的主系统中运行了。

### KBD
	tar xvf ${DOWNLOADDIR}/kbd-2.4.0.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/kbd-2.4.0
		patch -Np1 -i ${DOWNLOADDIR}/kbd-2.4.0-backspace-1.patch
		sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
		sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
		rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
		automake --add-missing
		LIBS="-lrt -lpthread" \
		./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET} --disable-vlock
		make
		make DESTDIR=${SYSDIR}/sysroot install
	popd

　　交叉编译KBD时可能会缺少链接库而导致制作失败，此时可以通过LIBS变量指定缺少链接的库而完成KBD软件包的制作。

#### Libpipeline
	tar xvf ${DOWNLOADDIR}/libpipeline-1.5.3.tar.gz -C ${BUILDDIR}
	pushd ${BUILDDIR}/libpipeline-1.5.3
		rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
		automake --add-missing
		./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} --host=${CROSS_TARGET}
		make
		make DESTDIR=${SYSDIR}/sysroot install
	popd

#### Make
	tar xvf ${DOWNLOADDIR}/make-4.3.tar.gz -C ${BUILDDIR}
	pushd ${BUILDDIR}/make-4.3
		rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
		automake --add-missing
		./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} --host=${CROSS_TARGET}
		make
		make DESTDIR=${SYSDIR}/sysroot install
	popd

#### Patch
	tar xvf ${DOWNLOADDIR}/patch-2.7.6.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/patch-2.7.6
		./configure --prefix=/usr -build=${CROSS_HOST} --host=${CROSS_TARGET}
		make
		make DESTDIR=${SYSDIR}/sysroot install
	popd

#### Man-DB
	tar xvf ${DOWNLOADDIR}/man-db-2.9.4.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/man-db-2.9.4
		rm $(dirname $(find -name "config.sub"))/config.{sub,guess}
		automake --add-missing
		LIBS="-lpipeline" \
		./configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
		            --host=${CROSS_TARGET} --sysconfdir=/etc --disable-setuid \
		            --enable-cache-owner=bin 	--with-browser=/usr/bin/lynx \
		            --with-vgrind=/usr/bin/vgrind --with-grap=/usr/bin/grap
		make
		make DESTDIR=${SYSDIR}/sysroot install
	popd

#### Tar
	tar xvf ${DOWNLOADDIR}/tar-1.34.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/tar-1.34
		FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}
		make
		make DESTDIR=${SYSDIR}/sysroot install
	popd

#### Texinfo
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

#### VIM
```
tar xvf ${DOWNLOADDIR}/v8.2.2879.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/vim-8.2.2879
	echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
	cat > src/auto/config.cache << EOF
	vim_cv_getcwd_broken=no
	vim_cv_toupper_broken=no
	vim_cv_terminfo=yes
	vim_cv_tgetent=zero
	vim_cv_stat_ignores_slash=no
	vim_cv_memmove_handles_overlap=yes
	EOF
	./configure --prefix=/usr --build=${CROSS_HOST} --host=${CROSS_TARGET}  --with-tlib=ncurses
	make
	make DESTDIR=${SYSDIR}/sysroot STRIP=${CROSS_TARGET}-strip install
	ln -sv vim ${SYSDIR}/sysroot/usr/bin/vi
popd
```

　　VIM制作过程中也需要设置一些参数避免自动探测错误，但VIM的参数设置文件是有默认文件路径的即“src/auto/config.cache”，在文件中写入参数和取值即可，configure配置脚本会自动从该文件中读取。

　　在安装完VIM后，我们可以配置VIM的默认设置文件，设置步骤如下：

```
cat > ${SYSDIR}/sysroot/etc/vimrc << "EOF"
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
　　改设置内容主要是设置了一些基本的界面和操作特性，如Tab转换成几个空格显示，不同的终端下背景颜色等等。

#### Util-Linux
	tar xvf ${DOWNLOADDIR}/util-linux-2.36.2.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/util-linux-2.36.2
		cp ${SYSDIR}/sysroot/usr/share/automake-1.16/config.* config/
		LDFLAGS="-lpthread" \
		./configure  --build=${CROSS_HOST} --host=${CROSS_TARGET} \
            ADJTIME_PATH=/var/lib/hwclock/adjtime \
            --libdir=/usr/lib64 \
            --disable-chfn-chsh --disable-login --disable-nologin \
            --disable-su --disable-setpriv --disable-runuser \
            --disable-pylibmount --disable-static --without-python \
            --without-systemd --disable-makeinstall-chown \
            runstatedir=/run
		make
		make DESTDIR=${SYSDIR}/sysroot install
	popd

　　Util-Linux带有大量的命令和库，由于部分命令已经在其它软件包中提供了，所以使用选项参数来关闭这些命令的编译和安装。

#### Systemd
　　Systemd采用的是meson命令进行配置阶段的操作，该命令与其他常见的configure脚本有明显的不同，所以在当前需要进行交叉编译的情况下也会采用完全不同的操作步骤，以下将展开进行说明。

```
tar xvf ${DOWNLOADDIR}/systemd-248.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/systemd-248
	patch -Np1 -i ${DOWNLOADDIR}/systemd-248-add-loongarch64.patch
	pushd src/basic
        python3 missing_syscalls.py missing_syscall_def.h $(ls syscalls-*.txt)
	popd
	sed -i 's/GROUP="render"/GROUP="video"/' rules.d/50-udev-default.rules.in
```

　　以上步骤是为了解压Systemd源代码和打上支持LoongArch64的补丁，并且对代码进行必要的修正。

　　接下来的步骤是制作一个为meson命令用来交叉编译配置的文本文件，步骤如下：

```
echo "[binaries]" > meson-cross.txt
echo "c = '${CROSS_TARGET}-gcc'" >> meson-cross.txt
echo "cpp = '${CROSS_TARGET}-g++'" >> meson-cross.txt
echo "ar = '${CROSS_TARGET}-ar'" >> meson-cross.txt
echo "strip = '${CROSS_TARGET}-strip'" >> meson-cross.txt
echo "pkgconfig = '${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-pkg-config'" >> meson-cross.txt
echo "[properties]" >> meson-cross.txt
echo -n "c_args = ['" >> meson-cross.txt
echo -n "${BUILD_ARCH} ${BUILD_MABI}" | sed "s@ ?*@','@g" >> meson-cross.txt
echo "']" >> meson-cross.txt
echo -n "cpp_args = ['" >> meson-cross.txt
echo -n "${BUILD_ARCH} ${BUILD_MABI}" | sed "s@ ?*@','@g" >> meson-cross.txt
echo "']" >> meson-cross.txt
echo "c_link_args = ['-Wl,-rpath-link,/opt/mylaos/sysroot/usr/lib64']" >> meson-cross.txt
echo "cpp_link_args = ['-Wl,-rpath-link,/opt/mylaos/sysroot/usr/lib64']" >> meson-cross.txt
echo "sys_root = '${SYSDIR}/sysroot'" >> meson-cross.txt
cat >> meson-cross.txt << "EOF"
[host_machine]
system = 'linux'
cpu_family = 'loongarch64'
cpu = 'loongarch64'
endian = 'little'
EOF
```
　　以上步骤完成后将在当前目录中生成一个meson-cross.txt文件，该文件包含了编译Systemd时目标架构的名字、系统、使用的工具链命令以及编译参数等等，这样在接下来的配置阶段中引用该文件就可以了。

　　以下是配置和编译的步骤：

```
	mkdir -p build
	pushd build
		LANG=en_US.UTF-8 \
		meson --prefix=/usr --libdir=/usr/lib64 --sysconfdir=/etc --localstatedir=/var \
		      -Dblkid=true -Dbuildtype=release -Ddefault-dnssec=no -Dfirstboot=false \
		      -Dinstall-tests=false -Dldconfig=false -Dsysusers=false -Db_lto=false \
		      -Drpmmacrosdir=no -Dhomed=false -Duserdb=false -Dman=false -Dmode=release \
		      --cross-file ../meson-cross.txt \
		      ..
		ninja
		DESTDIR=${SYSDIR}/sysroot ninja install
	popd
popd
```

　　较新版本的Systemd不再使用make命令进行编译了，配合meson使用ninja命令进行编译，在编译后同样用ninja命令安装软件包。

　　安装命令支持“DESTDIR”变量设置，但与make命令不同的是“DESTDIR”变量需要写在ninja命令的前面，安装的参数是“install”，该命令执行后同样将软件包安装到目标系统存放的目录中。


#### D-Bus
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

#### Procps-ng
	tar xvf ${DOWNLOADDIR}/procps-ng-3.3.17.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/procps-3.3.17
		./configure --prefix=/usr --libdir=/usr/lib64  --build=${CROSS_HOST} \
		            --host=${CROSS_TARGET} --disable-static --disable-kill \
		            --with-systemd NCURSES_LIBS="-lncursesw" \
		            ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes
		make 
		make DESTDIR=${SYSDIR}/sysroot install
	popd

　　Procps-ng软件包也是在交叉编译方式上会出现参数判断错误的情况，需要在配置阶段指定参数和取值。

#### E2fsprogs
	tar xvf ${DOWNLOADDIR}/e2fsprogs-1.46.2.tar.gz -C ${BUILDDIR}
	pushd ${BUILDDIR}/e2fsprogs-1.46.2
		cp ${SYSDIR}/sysroot/usr/share/automake-1.16/config.* config/
		mkdir -v build
		pushd build
			LDFLAGS="-Wl,-rpath-link,/opt/mylaos/sysroot/usr/lib64" \
			../configure --prefix=/usr --libdir=/usr/lib64 --build=${CROSS_HOST} \
			             --host=${CROSS_TARGET} --sysconfdir=/etc \
			             --enable-elf-shlibs--disable-libblkid \
			             --disable-libuuid --disable-uuidd --disable-fsck
			make 
			make DESTDIR=${SYSDIR}/sysroot install
			rm -fv ${SYSDIR}/sysroot/usr/lib64/{libcom_err,libe2p,libext2fs,libss}.a
		popd
	popd

#### Linux
	tar xvf ${DOWNLOADDIR}/linux-4.19.167.tar.gz -C ${BUILDDIR}
	pushd ${BUILDDIR}/linux-4.19.167
		make mrproper
		make ARCH=loongarch CROSS_COMPILE=${CROSS_TARGET}- defconfig
		make ARCH=loongarch CROSS_COMPILE=${CROSS_TARGET}- menuconfig
		make ARCH=loongarch CROSS_COMPILE=${CROSS_TARGET}-
		make ARCH=loongarch CROSS_COMPILE=${CROSS_TARGET}- INSTALL_MOD_PATH=dest modules_install
		mkdir -pv ${SYSDIR}/sysroot/lib/modules/
		cp -a dest/lib/modules/* ${SYSDIR}/sysroot/lib/modules/
		cp -a vmlinuz ${SYSDIR}/sysroot/boot/vmlinuz
	popd

　　因为是交叉编译的原因，Linux内核需要指定“ARCH”变量才能知道目标机器的架构，通过设置“CROSS_COMPILE”变量来指定命令前缀的方式来使用交叉编译工具的命令。

　　下面解释一下多个make命令步骤含义：  
　　* ```defconfig```，自动获取指定架构目录中的默认配置文件作为当前编译使用的配置文件。  
　　* ```menuconfig```，进入到交互式选择内核功能的界面，这需要主系统安装了Ncurses的开发库，该步骤可用来调整Linux内核选择，如果使用默认的就足够了，那么该步骤可以跳过。  
　　* ```modules_install```，安装模块文件，模块安装的根目录由“INSTALL_MOD_PATH”变量指定，这里指定了“dest”，代表安装到当前目录中的dest目录里，若没有该目录将自动创建。

　　当Linux内核编译完成后，我们可以将内核文件“vmlinuz”和对应的模块复制到目标系统存放的目录中。


#### Linux-Firmware
	tar xvf ${DOWNLOADDIR}/linux-firmware-20210511.tar.xz -C ${BUILDDIR}
	pushd ${BUILDDIR}/linux-firmware-20210511
		make DESTDIR=${SYSDIR}/sysroot install
	popd

　　安装Linux-Firmware软件包主要是因为当目标机器搭配了某些独显后需要相应的固件支持才能正常显示。

#### Grub2
	tar -xvf ${DOWNLOADDIR}/grub-2.06.tar.gz -C ${BUILDDIR}
	pushd ${BUILDDIR}/grub-2.06
		mkdir build
		pushd build
			../configure --prefix=/usr  --libdir=/usr/lib64  --build=${CROSS_HOST} \
			             --host=${CROSS_TARGET} -with-platform=efi \
			             --with-utils=host --disable-werror
			make 
			make DESTDIR=${SYSDIR}/sysroot install
		popd
	popd

　　为目标系统安装Grub2的命令及模块，这样在启动目标架构机器上启动目标系统后也可以制作对应的EFI文件和设置启动相关的文件了。


## 5 设置目标系统
　　目标系统的软件包制作过程已经完成，接下来就是对目标系统进行必要的设置，以便目标系统可以正常的启动和使用。

### 创建用户文件

　　创建基本的用户名，这些用户名大多数在启动过程中会用到，步骤如下：

```
cat > ${SYSDIR}/sysroot/etc/passwd << "EOF"
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


### 创建组文件

　　创建基本用户组，大多数都是系统必须的，步骤如下：

```
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

### 创建输入配置文件

```
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

	cat > ${SYSDIR}/sysroot/etc/adjtime << "EOF"
	0.0 0 0.0
	0
	LOCAL
	EOF

　　这里设置为使用BIOS提供的时间，如果使用UTC时间，可以将文件中的“LOCAL”改成“UTC”。

### 创建系统信息文件
```
cat > ${SYSDIR}/sysroot/etc/lsb-release << "EOF"
DISTRIB_ID="My GNU/Linux System for LoongArch64"
DISTRIB_RELEASE="1.0"
DISTRIB_CODENAME="Sun Haiyong"
DISTRIB_DESCRIPTION="My GNU/Linux System"
EOF
```
```
cat > ${SYSDIR}/sysroot/etc/os-release << "EOF"
NAME="My GNU/Linux System for LoongArch64"
VERSION="1.0"
ID=CLFS4LA64
PRETTY_NAME="My GNU/Linux System for LoongArch64 1.0"
VERSION_CODENAME="Sun Haiyong"
EOF
```

### 启动设置

#### 生成EFI文件
　　生成UEFI的启动文件，用于启动grub，命令如下：

```
${CROSS_TARGET}-grub-mkimage \
          --directory "${SYSDIR}/sysroot/usr/lib64/grub/loongarch64-efi" \
          --prefix '(,gpt2)/boot/grub' \
          --output "${SYSDIR}/sysroot/boot/efi/EFI/BOOT/BOOTLOONGARCH.EFI" \
          --format 'loongarch64-efi' \
          --compression 'auto' \
          'ext2' 'part_gpt'
```
　　因为运行的是存放在交叉编译工具目录中的Grub命令，所以根据当时安装的命名规则运行的命令是以`${CROSS_TARGET}-`开头的。

　　解释一下上述命令的参数：    
　　* ```--directory```，该参数指定生成EFI文件所使用模块存放的目录，这里指定的是目标系统存放目录中Grub安装的模块目录。  
　　* ```--prefix```，该参数指定EFI文件读取文件的基础目录，也就是说EFI如果需要读取什么文件的话都以该参数设置的目录作为最基础的目录，这里有一个很重要的参数设置```(,gpt2)```，这指定的是存储设备的分区，括号中有两个参数，并使用“,”分隔，逗号前的参数是磁盘编号，逗号后的参数是分区编号，我们看到这里没有指定磁盘编号，那么EFI启动后会自动使用启动EFI文件的磁盘编号来代替，而分区编号指定为`gpt2`,其中“gpt”代表分区类型，这里通常为“gpt”或者“msdos”，“gpt”代表了GPT分区，“msdos”代表了DOS分区，目前GPT分区逐渐成为主流，且UEFI的BIOS也建议分区采用GPT，“gpt”后面的数字代表分区的编号，第一个分区为“1”，第二个分区为“2”，所以这里`gpt2`代表的是GPT的第二个分区。  
　　之所以这样设置是为了方便安装了目标系统的存储设备可以正常的启动，因为通常存放EFI文件的分区和存放与其匹配的Grub启动相关文件的分区都在同一个存储设备上。  
　　* ```--output```，该参数指定生成的EFI文件存放的路径和文件名，这里设置的是目标系统存放目录中的“/boot/efi/EFI/BOOT”，这是按照一个系统被正常挂载后的目录结构，“/boot/efi”目录通常挂载的是第一个分区，也就是EFI分区，在该分区中通常要创建“EFI/BOOT”，因为UEFI的BIOS通常从这个分区的这个目录中载入EFI文件用于启动。“BOOTLOONGARCH.EFI”是LoongArch机器使用的默认查找的启动EFI文件名。  
　　* ```--format```，该参数指定生成文件的格式名，不同架构以及不同启动方式的名字会不同，这里针对LoongArch64的EFI启动方式采用的名称为“loongarch64-efi”。  
　　* ```--compression 'auto'```，该参数指定生成的EFI文件采用的压缩方式，这里设置为`auto`就可以了，其它的取值还有`xz`代表用XZ的压缩方式和`none`代表不进行压缩。  
　　* `'ext2' 'part_gpt'`,这两个是指定加入到EFI文件中的模块，加入到EFI文件中的模块会自动作为EFI文件启动后能直接使用的功能，而如果没有加入到EFI中则需要通过加载模块的方式才能使用，这里只加入了`ext2`和`part_gpt`是因为模块都存放在存储设备中，如果要读取模块就需要能识别存储设备的分区和文件系统，这里`part_gpt`用来识别存储设备的GPT分区，而`ext2`则是该分区所使用的文件系统，当这两者与实际的分区和文件系统相匹配的情况下，后续再有什么功能上的需求都可以用加载模块的方式来使用了，这样可以最小化EFI文件的大小，可加快BIOS对EFI文件的加载速度。模块的存放位置由`--prefix`参数指定的基础目录决定，在这个基础目录中的loongarch64-efi目录就是存放各个模块的目录。

#### 安装Grub模块文件
　　生成好EFI文件后，就可以按照生成EFI所设置的目录存放Grub的模块文件了，安装过程如下：

```
ln -sfv . ${SYSDIR}/sysroot/boot/boot
mkdir ${SYSDIR}/sysroot/boot/{grub,efi}
mkdir -pv ${SYSDIR}/sysroot/boot/efi/EFI/BOOT
cp -a ${SYSDIR}/sysroot/usr/lib64/grub/loongarch64-efi ${SYSDIR}/sysroot/boot/grub
```

## 6 处理目标系统

### 清理符号（symbol）信息
　　目前安装到目标系统中的二进制文件大多带有各种符号信息，这些信息不影响执行，但是占用了大量的存储空间，如果没有调试相关的需求，可以将这些信息清理掉以减少存储空间。

　　清理符号信息可以使用strip命令，但strip必须能够处理目标平台二进制，所以我们可以使用交叉编译工具链中的strip命令来操作，操作步骤如下：

```
pushd ${SYSDIR}/sysroot
	find usr/lib{,64} -type f -name \*.a -exec ${CROSS_TARGET}-strip --strip-debug {} ';'
	find usr/lib{,64} -type f -name \*.so* -exec ${CROSS_TARGET}-strip --strip-unneeded {} ';'
	find usr/{bin,sbin,libexec} -type f -exec ${CROSS_TARGET}-strip --strip-all {} ';'
popd
```

　　这里我们发现strip使用的参数有多种，这里简单的说明一下：  
　　* `--strip-debug`，仅去掉调试相关的符号信息，该参数适合用于静态库文件，对于链接过程需要的信息是不会去掉的。  
　　* `--strip-unneeded`，删除所有与重定位无关的所有符号信息，该参数不能用于静态库文件，否则会导致静态链接时无法使用处理过的静态库。  
　　* `--strip-all`，该参数代表所有能去掉的符号信息都尽量去掉，该参数不建议用于库文件，特别是静态库文件。

### 打包系统
　　制作完成后就可以退出制作用户环境了，使用命令:

	exit

　　接着可以使用root权限对目标系统进行打包，打包步骤如下：

```
pushd ${SYSDIR}/sysroot
	sudo tar --xattrs-include='*' --owner=root --group=root -cjpf \
			${SYSDIR}/loongarch64-clfs-system-1.0.tar.bz2 *
popd
```

## 7 创建启动U盘
　　制作好了目标系统后，我们可以尝试启动这个目标系统，借助U盘，我们来制作一个可以启动的简易LiveUSB。
　　
### 设置U盘分区
　　找到一个容量不少于4G的U盘，如果没有进行符号清理，那么建议容量不少于8G，请确保U盘中没有重要和要保留的数据，因为接下来的操作将破坏U盘内原有的数据。

　　接着给U盘进行分区，建议划分为3个分区，分别是：  
　　第一分区：EFI 分区，文件系统为fat，容量100M即可；  
　　第二分区：boot分区，文件系统为ext2，容量500M即可；  
　　第三分区：根分区，文件系统建议为xfs，剩余容量可以都分给该分区。

　　假设U盘设备名为sdb,以下为实际制作步骤如下：

    sudo cfdisk -z /dev/sdb
 
　　该命令将出现交互式操作模式，`-z`参数将强制进入分区类型选择（这会导致U盘上原有数据全部丢失，请再次确认没有要保留的数据后再继续），这里选择“gpt”，然后在分区的界面中对U盘按照上述的分区进行，保存退出，此时系统中将有“/dev/sdb1”、“/dev/sdb2”和"/dev/sdb3"这三个分区名，接下来就开始处理这三个分区。

　　首先，创建一个目录用于制作LiveUSB，命令如下：  

    mkdir /tmp/liveusb

　　挂载U盘的第三个分区既根分区到该目录上，命令如下：

    sudo mount /dev/sdb3 /tmp/liveusb

　　然后，创建一个boot分区，用于挂载第二分区既boot分区，命令如下：

	sudo mkdir /tmp/liveusb/boot
	sudo mount /dev/sdb2 /tmp/liveusb/boot

　　接着创建efi分区，用于挂载第一分区既EFI分区，命令如下：

	sudo mkdir /tmp/liveusb/boot/efi
	sudo mount /dev/sdb1 /tmp/liveusb/boot/efi

　　此时USB的分区挂载准备好了，接下来就是将目标系统解压到该目录即可，命令如下：

	pushd /tmp/liveusb
	    sudo tar -xvpf ${SYSDIR}/loongarch64-clfs-system-1.0.tar.bz2
	popd

　　解压完目标系统后先不要着急卸载和拔下U盘，因为还需要一些工作。

### 制作Grub的启动菜单文件
　　用Grub启动机器后通常会自动加载grub.cfg文件，用来显示启动菜单，以下就是制作一个简单的启动菜单制作步骤：

```
pushd /tmp/liveusb
cat > boot/grub/grub.cfg << "EOF"
menuentry 'My GNU/Linux System for LoongArch64' {
echo 'Loading Linux Kernel ...'
linux /vmlinuz root=/dev/sda3 rootdelay=5 rw
boot
}
EOF
popd
```

　　grub.cfg存放的目录是由生成EFI文件时```--prefix```参数设置决定的，按照参数设置的目录并命名为grub.cfg即可。
下面简单介绍一下菜单文件的设置内容：  
　　* ```menuentry```，该设置项设置启动菜单显示的条目，一个条目对应一个`menuentry`。  
　　* `echo`，输入内容，就是在屏幕上打印该行的内容。  
　　* `linux`，加载Linux内核，因当前加载的grub.cfg与Linux内核vmlinuz文件在同一个分区，则可以直接使用路径，若不在同一个分区中则需要设置磁盘和分区来指定内核文件路径。后面的`root=/dev/sda3 rootdelay=5 rw`都是提供给Linux内核启动时的参数：`root`指定启动根分区名，这里假定U盘的设备名会是sda，这里需要根据U盘插入到目标机器上时的设备名进行修改；`rootdelay`设置等待时间，这通常在用U盘作为启动盘时使用，因为U盘会需要一小段的初始化，如果没有等待会导致找不到设备而启动失败；`rw`设置根分区按照可读写的方式挂载。

　　做到这里，我们基本完成了LiveUSB的制作过程，接下来先卸载U盘：

	sudo umount -R /tmp/liveusb
	
　　umount命令使用‵-R‵参数可以一次行把指定目录中多个挂载都卸载掉。

　　接下来就可以拔出U盘，然后到龙芯3A5000的机器上去启动一下试试吧。

## 附录

### 参考资料
《用“芯”探索 教你构建龙芯平台的Linux系统》 孙海勇著

LFS： https://www.linuxfromscratch.org/lfs/